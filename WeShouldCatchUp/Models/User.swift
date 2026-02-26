import Foundation
import FirebaseFirestore

struct AppUser: Codable, Identifiable {
    @DocumentID var id: String?
    let phone: String
    var displayName: String
    var fcmToken: String?
    var status: UserStatus
    var liveSince: Timestamp?
    var liveTTL: Timestamp?
    let createdAt: Timestamp
    var updatedAt: Timestamp

    enum UserStatus: String, Codable {
        case idle
        case live
        case inCall = "in_call"
    }
}
