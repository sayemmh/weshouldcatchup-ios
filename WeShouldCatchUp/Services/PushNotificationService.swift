import Foundation
import UIKit
import FirebaseMessaging
import FirebaseAuth
import UserNotifications

// MARK: - Push Notification Type

/// Represents the different types of push notifications the app can receive.
enum PushNotificationType {
    /// A catch-up partner has gone live and is pinging the user for a call.
    case catchUpPing(fromUserId: String, fromUserName: String, catchupId: String, callId: String)

    /// Someone accepted the ping — User A should join the call.
    case callReady(fromUserId: String, fromUserName: String, catchupId: String, callId: String)

    /// A catch-up invite has been accepted by the other user.
    case inviteAccepted(catchupId: String)

    /// Silent update telling the live user who is currently being pinged.
    case rotationUpdate(pingingUserId: String, pingingUserName: String)

    /// The ping expired — clear the notification from this device.
    case pingExpired(fromUserId: String)

    /// Queue changed remotely — refresh the queue.
    case queueUpdated
}

// MARK: - Push Notification Service

/// Manages FCM token registration, Firestore persistence, and notification payload parsing.
final class PushNotificationService: NSObject {

    static let shared = PushNotificationService()

    // MARK: - Properties

    /// The current FCM device token, if available.
    var currentFCMToken: String?

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

    /// Saves the FCM token via the backend API.
    /// Call this whenever the FCM token refreshes or after authentication.
    func updateFCMToken(token: String) {
        self.currentFCMToken = token
        persistToken(token)
    }

    /// Attempts to send the current FCM token to the backend.
    /// Called from multiple places to handle race conditions between FCM and Auth.
    func persistTokenIfReady() {
        guard let token = currentFCMToken else { return }
        persistToken(token)
    }

    private func persistToken(_ token: String) {
        guard Auth.auth().currentUser != nil else {
            print("[PushNotificationService] Cannot update token -- user not authenticated.")
            return
        }

        Task {
            do {
                try await APIService.shared.updateFCMToken(token)
                print("[PushNotificationService] FCM token updated successfully via API.")
            } catch {
                print("[PushNotificationService] Failed to update FCM token: \(error.localizedDescription)")
            }
        }
    }

    /// Clears the local FCM token on sign-out.
    func clearFCMToken() {
        currentFCMToken = nil
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
        case "catch_up_ping":
            guard
                let fromUserId = userInfo["fromUserId"] as? String,
                let catchupId = userInfo["catchupId"] as? String,
                let callId = userInfo["callId"] as? String
            else {
                print("[PushNotificationService] catch_up_ping payload missing required fields.")
                return nil
            }
            let fromUserName = userInfo["fromUserName"] as? String ?? "Someone"
            return .catchUpPing(fromUserId: fromUserId, fromUserName: fromUserName, catchupId: catchupId, callId: callId)

        case "call_ready":
            guard
                let fromUserId = userInfo["fromUserId"] as? String,
                let catchupId = userInfo["catchupId"] as? String,
                let callId = userInfo["callId"] as? String
            else {
                print("[PushNotificationService] call_ready payload missing required fields.")
                return nil
            }
            let fromUserName = userInfo["fromUserName"] as? String ?? "Someone"
            return .callReady(fromUserId: fromUserId, fromUserName: fromUserName, catchupId: catchupId, callId: callId)

        case "invite_accepted":
            guard let catchupId = userInfo["catchupId"] as? String else {
                print("[PushNotificationService] invite_accepted payload missing catchupId.")
                return nil
            }
            return .inviteAccepted(catchupId: catchupId)

        case "rotation_update":
            guard
                let pingingUserId = userInfo["pingingUserId"] as? String,
                let pingingUserName = userInfo["pingingUserName"] as? String
            else {
                print("[PushNotificationService] rotation_update payload missing required fields.")
                return nil
            }
            return .rotationUpdate(pingingUserId: pingingUserId, pingingUserName: pingingUserName)

        case "ping_expired":
            guard let fromUserId = userInfo["fromUserId"] as? String else {
                return nil
            }
            return .pingExpired(fromUserId: fromUserId)

        case "queue_updated":
            return .queueUpdated

        default:
            print("[PushNotificationService] Unknown notification type: \(type)")
            return nil
        }
    }
}
