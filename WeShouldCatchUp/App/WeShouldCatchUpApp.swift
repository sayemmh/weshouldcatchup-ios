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

    // MARK: - Single Overlay State (avoids multiple fullScreenCover conflicts)

    enum GlobalOverlay: Identifiable {
        case incomingPing(name: String, catchupId: String, callId: String)
        case voiceCall(CallViewModel)
        case callEnded(name: String, duration: Int)

        var id: String {
            switch self {
            case .incomingPing(_, let catchupId, _): return "ping-\(catchupId)"
            case .voiceCall(let vm): return "call-\(vm.id)"
            case .callEnded(let name, _): return "ended-\(name)"
            }
        }
    }

    @State private var globalOverlay: GlobalOverlay?

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

            print("[RootView] Received incomingCatchUpPing: from=\(fromName), catchup=\(catchupId), call=\(callId)")
            globalOverlay = .incomingPing(name: fromName, catchupId: catchupId, callId: callId)
        }
        // Global call_ready handler — User A receives this when User B accepts,
        // even if User A is no longer on LiveWaitingView.
        .onReceive(NotificationCenter.default.publisher(for: .callReady)) { notification in
            guard !LiveViewModel.isActive else { return }
            guard let info = notification.userInfo,
                  let fromUserName = info["fromUserName"] as? String,
                  let callId = info["callId"] as? String
            else { return }

            print("[RootView] Received callReady: from=\(fromUserName), call=\(callId)")
            Task {
                do {
                    let response = try await APIService.shared.joinCall(callId: callId)
                    // Wait for any existing overlay dismiss
                    if globalOverlay != nil {
                        globalOverlay = nil
                        try? await Task.sleep(for: .milliseconds(400))
                    }
                    await MainActor.run {
                        let callVM = CallViewModel(
                            otherUserName: fromUserName,
                            callId: response.callId,
                            agoraChannel: response.agoraChannel,
                            agoraToken: response.agoraToken
                        )
                        print("[RootView] Presenting voice call: channel=\(response.agoraChannel)")
                        globalOverlay = .voiceCall(callVM)
                    }
                } catch {
                    print("[RootView] Failed to join call: \(error)")
                }
            }
        }
        .fullScreenCover(item: $globalOverlay) { overlay in
            switch overlay {
            case .incomingPing(let name, let catchupId, let callId):
                IncomingPingView(
                    callerName: name,
                    catchupId: catchupId,
                    callId: callId,
                    onAccept: {
                        print("[RootView] User tapped Join — accepting ping: catchup=\(catchupId), call=\(callId)")
                        globalOverlay = nil
                        Task {
                            do {
                                let response = try await APIService.shared.acceptPing(
                                    catchupId: catchupId,
                                    callId: callId
                                )
                                print("[RootView] acceptPing succeeded: channel=\(response.agoraChannel), callId=\(response.callId)")
                                // Wait for dismiss animation to complete before presenting next cover
                                try? await Task.sleep(for: .milliseconds(400))
                                await MainActor.run {
                                    let callVM = CallViewModel(
                                        otherUserName: name,
                                        callId: response.callId,
                                        agoraChannel: response.agoraChannel,
                                        agoraToken: response.agoraToken
                                    )
                                    globalOverlay = .voiceCall(callVM)
                                }
                            } catch {
                                print("[RootView] acceptPing FAILED: \(error)")
                            }
                        }
                    },
                    onDecline: {
                        globalOverlay = nil
                    }
                )

            case .voiceCall(let callVM):
                VoiceCallView(viewModel: callVM, onCallEnded: { name, duration in
                    globalOverlay = nil
                    Task {
                        // Wait for dismiss before showing call ended
                        try? await Task.sleep(for: .milliseconds(400))
                        await MainActor.run {
                            globalOverlay = .callEnded(name: name, duration: duration)
                        }
                    }
                })

            case .callEnded(let name, let duration):
                CallEndedView(
                    otherPersonName: name,
                    durationSeconds: duration,
                    onDismiss: {
                        globalOverlay = nil
                    }
                )
            }
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
