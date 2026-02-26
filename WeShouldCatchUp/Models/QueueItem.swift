import Foundation

/// Represents a person in the user's catch-up queue, as returned by the /my-queue endpoint.
struct QueueItem: Codable, Identifiable {
    let catchupId: String
    let otherUser: OtherUser
    let lastCallAt: String? // ISO 8601 timestamp
    let callCount: Int

    var id: String { catchupId }

    struct OtherUser: Codable {
        let name: String
        let userId: String
    }
}
