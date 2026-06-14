import Foundation

/// The re-catch state of a caught-up pair, computed by the backend per viewer.
enum RecatchState: String, Codable {
    case idle                                  // no pending request
    case requestedByMe = "requested_by_me"     // I asked to catch up again, awaiting them
    case incoming                              // they want to catch up again — I can Accept
}

/// Represents a person in the user's catch-up queue, as returned by the /my-queue endpoint.
struct QueueItem: Codable, Identifiable {
    let catchupId: String
    let otherUser: OtherUser
    let lastCallAt: String?
    let callCount: Int
    let status: String?
    /// Whether the pair has caught up (a call happened). Shown under "Caught Up", skipped by rotation.
    let caughtUp: Bool?
    /// Per-viewer re-catch state for the inline action on caught-up rows.
    let recatchState: RecatchState?

    var id: String { catchupId }
    var isPending: Bool { status == "pending" }
    var isCaughtUp: Bool { caughtUp == true }
    var recatch: RecatchState { recatchState ?? .idle }

    struct OtherUser: Codable {
        let name: String
        let userId: String
    }
}
