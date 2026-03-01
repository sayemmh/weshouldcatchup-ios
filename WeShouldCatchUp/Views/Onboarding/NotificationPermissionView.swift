import SwiftUI
import UserNotifications

// MARK: - NotificationPermissionView

struct NotificationPermissionView: View {

    /// Called when the user grants notification permission (or skips).
    var onPermissionGranted: () -> Void

    @State private var showWhySection: Bool = false
    @State private var permissionDenied: Bool = false

    var body: some View {
        ZStack {
            Constants.Colors.background
                .ignoresSafeArea()

            VStack(spacing: 36) {
                Spacer()

                // MARK: - Illustration
                illustrationSection

                // MARK: - Headline & Description
                textSection

                // MARK: - Why Section
                whySection

                Spacer()

                // MARK: - Enable Button
                enableButton

                // MARK: - Denied State
                if permissionDenied {
                    deniedMessage
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 32)
        }
    }

    // MARK: - Illustration

    private var illustrationSection: some View {
        ZStack {
            Circle()
                .fill(Constants.Colors.primary.opacity(0.12))
                .frame(width: 140, height: 140)

            Image(systemName: "bell.badge")
                .font(.system(size: 60))
                .foregroundColor(Constants.Colors.primary)
        }
    }

    // MARK: - Text

    private var textSection: some View {
        VStack(spacing: 14) {
            Text("Turn on notifications")
                .font(.fraunces(28, weight: .semiBold))
                .fontWeight(.bold)
                .foregroundColor(Constants.Colors.textPrimary)

            Text("This is how you'll know when a friend is free. Without notifications, the app can't work.")
                .font(.inter(16))
                .foregroundColor(Constants.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Why Section

    private var whySection: some View {
        VStack(spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    showWhySection.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Text("Why?")
                        .font(.inter(12))
                        .fontWeight(.medium)
                    Image(systemName: showWhySection ? "chevron.up" : "chevron.down")
                        .font(.inter(11))
                }
                .foregroundColor(Constants.Colors.primary)
            }

            if showWhySection {
                VStack(alignment: .leading, spacing: 10) {
                    whyRow(
                        icon: "person.2.fill",
                        text: "When a friend taps \"I'm Free,\" we need to let you know right away."
                    )
                    whyRow(
                        icon: "clock.fill",
                        text: "Catch-up windows are short. If you miss the notification, you miss the call."
                    )
                    whyRow(
                        icon: "hand.wave.fill",
                        text: "This is the core of the app. No notifications means no catch-ups."
                    )
                }
                .padding()
                .background(Color.white)
                .cornerRadius(14)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private func whyRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(Constants.Colors.primary)
                .frame(width: 20)
            Text(text)
                .font(.inter(12))
                .foregroundColor(Constants.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Enable Button

    private var enableButton: some View {
        Button {
            requestNotificationPermission()
        } label: {
            Text("Enable Notifications")
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Constants.Colors.primary)
                .foregroundColor(.white)
                .cornerRadius(14)
        }
    }

    // MARK: - Denied Message

    private var deniedMessage: some View {
        VStack(spacing: 8) {
            Text("Notifications were denied. Please enable them in Settings for the app to work properly.")
                .font(.inter(12))
                .foregroundColor(Constants.Colors.textSecondary)
                .multilineTextAlignment(.center)

            Button {
                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsURL)
                }
            } label: {
                Text("Open Settings")
                    .font(.inter(12))
                    .fontWeight(.medium)
                    .foregroundColor(Constants.Colors.primary)
            }
        }
        .padding(.bottom, 8)
    }

    // MARK: - Permission Request

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            DispatchQueue.main.async {
                if granted {
                    UIApplication.shared.registerForRemoteNotifications()
                    onPermissionGranted()
                } else {
                    permissionDenied = true
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NotificationPermissionView {
        print("Permission granted")
    }
}
