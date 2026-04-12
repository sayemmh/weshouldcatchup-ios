import Foundation

/// Represents a person in the user's catch-up queue, as returned by the /my-queue endpoint.
struct QueueItem: Codable, Identifiable {
    let catchupId: String
    let otherUser: OtherUser
    let lastCallAt: String?
    let callCount: Int
    let status: String?

    var id: String { catchupId }
    var isPending: Bool { status == "pending" }

    struct OtherUser: Codable {
        let name: String
        let userId: String
    }
}
