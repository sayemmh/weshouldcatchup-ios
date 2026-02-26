import UIKit
import FirebaseCore
import FirebaseMessaging
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()
        Messaging.messaging().delegate = self
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    // MARK: - APNs Token Registration

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Messaging.messaging().apnsToken = deviceToken
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("Failed to register for remote notifications: \(error.localizedDescription)")
    }
}

// MARK: - MessagingDelegate

extension AppDelegate: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let token = fcmToken else { return }
        print("FCM token: \(token)")
        PushNotificationService.shared.currentFCMToken = token

        Task {
            await PushNotificationService.shared.updateFCMToken(token: token)
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension AppDelegate: UNUserNotificationCenterDelegate {

    /// Handle notification when app is in the foreground.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let userInfo = notification.request.content.userInfo

        if let type = PushNotificationService.shared.handleNotification(userInfo: userInfo) {
            handlePushType(type)
        }

        // Show banner even when app is in foreground.
        completionHandler([.banner, .sound])
    }

    /// Handle notification tap when app is in background/closed.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo

        if let type = PushNotificationService.shared.handleNotification(userInfo: userInfo) {
            handlePushType(type)
        }

        completionHandler()
    }

    private func handlePushType(_ type: PushNotificationService.PushNotificationType) {
        switch type {
        case .catchUpPing(let fromUserId, let catchupId, let callId):
            // Post notification so the active view can respond.
            NotificationCenter.default.post(
                name: .incomingCatchUpPing,
                object: nil,
                userInfo: [
                    "fromUserId": fromUserId,
                    "catchupId": catchupId,
                    "callId": callId
                ]
            )

        case .inviteAccepted(let catchupId):
            NotificationCenter.default.post(
                name: .catchUpInviteAccepted,
                object: nil,
                userInfo: ["catchupId": catchupId]
            )
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let incomingCatchUpPing = Notification.Name("incomingCatchUpPing")
    static let catchUpInviteAccepted = Notification.Name("catchUpInviteAccepted")
}
