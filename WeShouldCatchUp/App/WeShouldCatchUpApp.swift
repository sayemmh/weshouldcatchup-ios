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
        if !authService.isAuthenticated || !hasCompletedOnboarding {
            OnboardingFlow(onComplete: {
                hasCompletedOnboarding = true
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
}

/// Container that walks through the onboarding steps.
struct OnboardingFlow: View {
    @StateObject private var viewModel = AuthViewModel()
    let onComplete: () -> Void

    var body: some View {
        switch viewModel.currentStep {
        case .phoneEntry, .codeVerification:
            PhoneAuthView(viewModel: viewModel)

        case .notificationPermission:
            NotificationPermissionView(onPermissionGranted: {
                viewModel.notificationsEnabled()
            })

        case .displayNameEntry:
            DisplayNameView(onComplete: {
                Task { await viewModel.saveDisplayName() }
                onComplete()
            })

        case .complete:
            Color.clear.onAppear { onComplete() }
        }
    }
}
