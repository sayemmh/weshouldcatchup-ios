import UIKit
import FirebaseCore
import FirebaseAuth
import FirebaseMessaging
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()

        #if targetEnvironment(simulator)
        Auth.auth().settings?.isAppVerificationDisabledForTesting = true
        #endif

        Messaging.messaging().delegate = self
        UNUserNotificationCenter.current().delegate = self

        // Register for remote notifications early so the APNs token
        // is available before Firebase Phone Auth needs it.
        application.registerForRemoteNotifications()

        return true
    }

    // MARK: - APNs Token Registration

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        // Pass token to Firebase Auth (needed for phone auth silent push verification)
        Auth.auth().setAPNSToken(deviceToken, type: .unknown)
        // Pass token to FCM for push notifications
        Messaging.messaging().apnsToken = deviceToken
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("Failed to register for remote notifications: \(error.localizedDescription)")
    }

    // MARK: - Silent Push (Firebase Auth phone verification)

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        // Let Firebase Auth handle its silent push verification
        if Auth.auth().canHandleNotification(userInfo) {
            completionHandler(.noData)
            return
        }

        // Route app-level pushes (pings, call_ready) that arrive in background
        if let type = PushNotificationService.shared.handleNotification(userInfo: userInfo) {
            handlePushType(type)
            completionHandler(.newData)
            return
        }
        completionHandler(.noData)
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

            // Suppress banner for types we handle in-app with their own UI.
            switch type {
            case .rotationUpdate, .catchUpPing, .callReady, .queueUpdated, .pingExpired:
                completionHandler([])
                return
            default:
                break
            }
        }

        // Show banner for types without in-app handling (inviteAccepted, etc).
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

    private func handlePushType(_ type: PushNotificationType) {
        switch type {
        case .catchUpPing(let fromUserId, let fromUserName, let catchupId, let callId):
            NotificationCenter.default.post(
                name: .incomingCatchUpPing,
                object: nil,
                userInfo: [
                    "fromUserId": fromUserId,
                    "fromUserName": fromUserName,
                    "catchupId": catchupId,
                    "callId": callId
                ]
            )

        case .callReady(let fromUserId, let fromUserName, let catchupId, let callId):
            NotificationCenter.default.post(
                name: .callReady,
                object: nil,
                userInfo: [
                    "fromUserId": fromUserId,
                    "fromUserName": fromUserName,
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

        case .rotationUpdate(let pingingUserId, let pingingUserName):
            NotificationCenter.default.post(
                name: .rotationUpdate,
                object: nil,
                userInfo: [
                    "pingingUserId": pingingUserId,
                    "pingingUserName": pingingUserName
                ]
            )

        case .pingExpired:
            UNUserNotificationCenter.current().removeAllDeliveredNotifications()

        case .queueUpdated:
            NotificationCenter.default.post(name: .queueUpdated, object: nil)
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let incomingCatchUpPing = Notification.Name("incomingCatchUpPing")
    static let callReady = Notification.Name("callReady")
    static let catchUpInviteAccepted = Notification.Name("catchUpInviteAccepted")
    static let rotationUpdate = Notification.Name("rotationUpdate")
    static let queueUpdated = Notification.Name("queueUpdated")
}
