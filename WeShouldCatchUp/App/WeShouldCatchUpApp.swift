import SwiftUI
import FirebaseCore

@main
struct WeShouldCatchUpApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var authService = AuthService.shared
    @StateObject private var deepLinkService = DeepLinkService()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(authService)
                .environmentObject(deepLinkService)
                .preferredColorScheme(.light)
                .onOpenURL { url in
                    _ = deepLinkService.handleIncomingURL(url)
                }
        }
    }
}

/// Root view that switches between onboarding and main app based on auth state.
struct RootView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var deepLinkService: DeepLinkService

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    // MARK: - Global Incoming Ping State

    @State private var showGlobalIncomingPing = false
    @State private var globalPingFromName: String = ""
    @State private var globalPingCatchupId: String = ""
    @State private var globalPingCallId: String = ""

    // MARK: - Global Voice Call State

    @State private var globalCallVM: CallViewModel?

    // MARK: - Global Call Ended State

    @State private var showGlobalCallEnded = false
    @State private var globalCallEndedName: String = ""
    @State private var globalCallEndedDuration: Int = 0

    var body: some View {
        Group {
            if !authService.isAuthenticated || !hasCompletedOnboarding {
                OnboardingFlow(isReturningUser: hasCompletedOnboarding, onComplete: {
                    hasCompletedOnboarding = true
                    // Check clipboard for invite link (deferred deep linking from web)
                    deepLinkService.checkClipboardForInvite()
                })
            } else if let catchupId = deepLinkService.pendingInviteCatchupId {
                AcceptInviteView(
                    catchupId: catchupId,
                    inviterName: "Someone",
                    onAccepted: { deepLinkService.clearPendingInvite() },
                    onDeclined: { deepLinkService.clearPendingInvite() }
                )
            } else {
                MainView()
            }
        }
        // Global incoming ping handler — only fires when LiveWaitingView is NOT active
        .onReceive(NotificationCenter.default.publisher(for: .incomingCatchUpPing)) { notification in
            guard !LiveViewModel.isActive else { return }
            guard let info = notification.userInfo,
                  let fromName = info["fromUserName"] as? String,
                  let catchupId = info["catchupId"] as? String,
                  let callId = info["callId"] as? String
            else { return }

            globalPingFromName = fromName
            globalPingCatchupId = catchupId
            globalPingCallId = callId
            showGlobalIncomingPing = true
        }
        .fullScreenCover(isPresented: $showGlobalIncomingPing) {
            IncomingPingView(
                callerName: globalPingFromName,
                catchupId: globalPingCatchupId,
                callId: globalPingCallId,
                onAccept: {
                    showGlobalIncomingPing = false
                    Task {
                        do {
                            let response = try await APIService.shared.acceptPing(
                                catchupId: globalPingCatchupId,
                                callId: globalPingCallId
                            )
                            await MainActor.run {
                                globalCallVM = CallViewModel(
                                    otherUserName: globalPingFromName,
                                    callId: response.callId,
                                    agoraChannel: response.agoraChannel,
                                    agoraToken: response.agoraToken
                                )
                            }
                        } catch {
                            print("[RootView] Failed to accept ping: \(error)")
                        }
                    }
                },
                onDecline: {
                    showGlobalIncomingPing = false
                }
            )
        }
        .fullScreenCover(item: $globalCallVM) { callVM in
            VoiceCallView(viewModel: callVM, onCallEnded: { name, duration in
                globalCallVM = nil
                globalCallEndedName = name
                globalCallEndedDuration = duration
                showGlobalCallEnded = true
            })
        }
        .fullScreenCover(isPresented: $showGlobalCallEnded) {
            CallEndedView(
                otherPersonName: globalCallEndedName,
                durationSeconds: globalCallEndedDuration,
                onDismiss: {
                    showGlobalCallEnded = false
                }
            )
        }
    }
}

/// Container that walks through the onboarding steps.
struct OnboardingFlow: View {
    @StateObject private var viewModel: AuthViewModel
    let onComplete: () -> Void

    init(isReturningUser: Bool = false, onComplete: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: AuthViewModel(isReturningUser: isReturningUser))
        self.onComplete = onComplete
    }

    var body: some View {
        switch viewModel.currentStep {
        case .phoneEntry, .codeVerification:
            PhoneAuthView(viewModel: viewModel)

        case .notificationPermission:
            NotificationPermissionView(onPermissionGranted: {
                viewModel.notificationsEnabled()
            })

        case .termsAgreement:
            TermsAgreementView(onAccepted: {
                viewModel.termsAccepted()
            })

        case .displayNameEntry:
            DisplayNameView(onComplete: {
                viewModel.currentStep = .inviteFriends
            })

        case .inviteFriends:
            InviteFriendsOnboardingView(onComplete: {
                onComplete()
            })

        case .complete:
            Color.clear.onAppear { onComplete() }
        }
    }
}
