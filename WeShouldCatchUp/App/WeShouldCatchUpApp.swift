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

    var body: some View {
        Group {
            if !authService.isAuthenticated || !hasCompletedOnboarding {
                OnboardingFlow(onComplete: {
                    hasCompletedOnboarding = true
                })
            } else if let catchupId = deepLinkService.pendingInviteCatchupId {
                AcceptInviteView(catchupId: catchupId, onDone: {
                    deepLinkService.clearPendingInvite()
                })
            } else {
                MainView()
            }
        }
        .preferredColorScheme(.light)
    }
}

/// Container that walks through the onboarding steps.
struct OnboardingFlow: View {
    @StateObject private var viewModel = AuthViewModel()
    let onComplete: () -> Void

    var body: some View {
        Group {
            switch viewModel.currentStep {
            case .phoneEntry, .codeVerification:
                PhoneAuthView(viewModel: viewModel)

            case .notificationPermission:
                NotificationPermissionView(onEnabled: {
                    viewModel.notificationsEnabled()
                })

            case .displayNameEntry:
                DisplayNameView(viewModel: viewModel)

            case .complete:
                Color.clear.onAppear { onComplete() }
            }
        }
        .background(Constants.Colors.background.ignoresSafeArea())
    }
}
