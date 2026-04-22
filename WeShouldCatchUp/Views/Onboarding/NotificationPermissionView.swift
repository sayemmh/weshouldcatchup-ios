import SwiftUI
import UserNotifications

struct NotificationPermissionView: View {

    var onPermissionGranted: () -> Void

    @State private var permissionDenied: Bool = false

    var body: some View {
        ZStack {
            Constants.Colors.background
                .ignoresSafeArea()

            VStack(spacing: 36) {
                Spacer()

                Image(systemName: "bell")
                    .font(.system(size: 56, weight: .light))
                    .foregroundColor(Constants.Colors.primary)

                VStack(spacing: 14) {
                    Text("Turn on notifications")
                        .font(.fraunces(28, weight: .semiBold))
                        .foregroundColor(Constants.Colors.textPrimary)

                    Text("Get notified when a friend is free to catch up. You can change this anytime in Settings.")
                        .font(.inter(15, weight: .regular))
                        .foregroundColor(Constants.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                VStack(spacing: 14) {
                    Button {
                        requestNotificationPermission()
                    } label: {
                        Text("Enable Notifications")
                            .font(.inter(15, weight: .semiBold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Constants.Colors.primary)
                            .foregroundColor(.white)
                            .cornerRadius(28)
                    }

                    Button {
                        onPermissionGranted()
                    } label: {
                        Text("Not now")
                            .font(.inter(13, weight: .medium))
                            .foregroundColor(Constants.Colors.textSecondary)
                            .padding(.vertical, 8)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 32)
        }
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            DispatchQueue.main.async {
                if granted {
                    UIApplication.shared.registerForRemoteNotifications()
                }
                onPermissionGranted()
            }
        }
    }
}

#Preview {
    NotificationPermissionView {
        print("Continuing")
    }
}
