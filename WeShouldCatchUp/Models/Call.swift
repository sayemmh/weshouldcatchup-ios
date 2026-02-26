import Foundation
import FirebaseFirestore

struct Call: Codable, Identifiable {
    @DocumentID var id: String?
    let participants: [String]
    let initiatedBy: String
    let agoraChannel: String
    let startedAt: Timestamp
    var endedAt: Timestamp?
    var duration: Int? // seconds

    /// Returns the other participant's ID given the current user's ID.
    func otherUserId(currentUserId: String) -> String? {
        return participants.first { $0 != currentUserId }
    }
}
