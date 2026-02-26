import Foundation
import FirebaseFirestore

struct CatchUp: Codable, Identifiable {
    @DocumentID var id: String?
    let userA: String
    let userB: String
    var status: CatchUpStatus
    let createdAt: Timestamp
    var acceptedAt: Timestamp?
    var lastCallAt: Timestamp?
    var callCount: Int
    var removedBy: String?

    enum CatchUpStatus: String, Codable {
        case pending
        case active
        case removed
    }

    /// Returns the other user's ID given the current user's ID.
    func otherUserId(currentUserId: String) -> String {
        return currentUserId == userA ? userB : userA
    }
}
