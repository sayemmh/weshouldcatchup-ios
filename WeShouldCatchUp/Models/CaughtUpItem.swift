import Foundation

/// The re-catch state of a caught-up pair, computed by the backend per viewer.
enum RecatchState: String, Codable {
    case idle                                  // no pending request
    case requestedByMe = "requested_by_me"     // I tapped "Catch up again", waiting on them
    case incoming                              // they want to catch up again — I can Accept
}

/// A person in the user's "Caught Up" list, as returned by the /caught-up endpoint.
struct CaughtUpItem: Codable, Identifiable {
    let catchupId: String
    let otherUser: OtherUser
    let lastCallAt: String?
    let callCount: Int
    let state: RecatchState

    var id: String { catchupId }

    struct OtherUser: Codable {
        let name: String
        let userId: String
    }
}
