import Foundation
import UIKit
import FirebaseMessaging
import FirebaseFirestore
import FirebaseAuth
import UserNotifications

// MARK: - Push Notification Type

/// Represents the different types of push notifications the app can receive.
enum PushNotificationType {
    /// A catch-up partner has gone live and is pinging the user for a call.
    case catchUpPing(fromUserId: String, catchupId: String, callId: String)

    /// A catch-up invite has been accepted by the other user.
    case inviteAccepted(catchupId: String)
}

// MARK: - Push Notification Service

/// Manages FCM token registration, Firestore persistence, and notification payload parsing.
final class PushNotificationService: NSObject {

    static let shared = PushNotificationService()

    // MARK: - Properties

    /// The current FCM device token, if available.
    var currentFCMToken: String?

    private let firestore = Firestore.firestore()

    private override init() {
        super.init()
    }

    // MARK: - Registration

    /// Requests notification permissions from the user and registers for remote notifications.
    func registerForPushNotifications() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("[PushNotificationService] Permission request error: \(error.localizedDescription)")
                return
            }

            guard granted else {
                print("[PushNotificationService] Push notification permission denied.")
                return
            }

            DispatchQueue.main.async {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
    }

    // MARK: - FCM Token Management

    /// Saves the FCM token to the current user's Firestore document.
    /// Call this whenever the FCM token refreshes (e.g. in `messaging(_:didReceiveRegistrationToken:)`).
    /// - Parameter token: The new FCM registration token.
    func updateFCMToken(token: String) {
        self.currentFCMToken = token

        guard let userId = Auth.auth().currentUser?.uid else {
            print("[PushNotificationService] Cannot update token -- user not authenticated.")
            return
        }

        firestore
            .collection("users")
            .document(userId)
            .updateData(["fcmToken": token]) { error in
                if let error = error {
                    print("[PushNotificationService] Failed to update FCM token: \(error.localizedDescription)")
                } else {
                    print("[PushNotificationService] FCM token updated successfully.")
                }
            }
    }

    // MARK: - Notification Parsing

    /// Parses an incoming push notification's data payload into a typed enum.
    /// - Parameter userInfo: The raw notification payload dictionary.
    /// - Returns: A `PushNotificationType` if the payload matches a known type, otherwise `nil`.
    func handleNotification(userInfo: [AnyHashable: Any]) -> PushNotificationType? {
        guard let type = userInfo["type"] as? String else {
            print("[PushNotificationService] Notification missing 'type' key.")
            return nil
        }

        switch type {
        case "catchup_ping":
            guard
                let fromUserId = userInfo["fromUserId"] as? String,
                let catchupId = userInfo["catchupId"] as? String,
                let callId = userInfo["callId"] as? String
            else {
                print("[PushNotificationService] catchup_ping payload missing required fields.")
                return nil
            }
            return .catchUpPing(fromUserId: fromUserId, catchupId: catchupId, callId: callId)

        case "invite_accepted":
            guard let catchupId = userInfo["catchupId"] as? String else {
                print("[PushNotificationService] invite_accepted payload missing catchupId.")
                return nil
            }
            return .inviteAccepted(catchupId: catchupId)

        default:
            print("[PushNotificationService] Unknown notification type: \(type)")
            return nil
        }
    }
}
