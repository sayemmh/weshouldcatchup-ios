import Foundation
import UIKit
import Combine

/// Handles incoming universal links for catch-up invitations.
///
/// Expected URL format: `https://weshouldcatchup.app/invite/{catchupId}`
final class DeepLinkService: ObservableObject {

    // MARK: - Published Properties

    /// The catch-up ID extracted from a pending invite deep link, if any.
    @Published var pendingInviteCatchupId: String?

    // MARK: - Constants

    /// The host component of valid invite URLs.
    private let expectedHost = "weshouldcatchup.app"

    /// The path prefix for invite links.
    private let invitePathPrefix = "/invite/"

    // MARK: - URL Handling

    /// Parses an incoming universal link and extracts the catch-up invite ID if the URL matches
    /// the expected format (`weshouldcatchup.app/invite/{catchupId}`).
    ///
    /// - Parameter url: The incoming URL to handle.
    /// - Returns: `true` if the URL was recognized as a valid invite link, `false` otherwise.
    @discardableResult
    func handleIncomingURL(_ url: URL) -> Bool {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
            return false
        }

        // Validate host
        guard components.host == expectedHost else {
            return false
        }

        // Validate path format: /invite/{catchupId}
        let path = components.path
        guard path.hasPrefix(invitePathPrefix) else {
            return false
        }

        // Extract the catchupId (everything after /invite/)
        let catchupId = String(path.dropFirst(invitePathPrefix.count))
        guard !catchupId.isEmpty, !catchupId.contains("/") else {
            return false
        }

        DispatchQueue.main.async {
            self.pendingInviteCatchupId = catchupId
        }
        return true
    }

    /// Clears the pending invite after it has been processed.
    func clearPendingInvite() {
        pendingInviteCatchupId = nil
    }

    // MARK: - Deferred Deep Linking (Clipboard)

    /// Checks the clipboard for an invite link. Called after onboarding to handle
    /// the case where a new user tapped an invite link on the web, installed the app,
    /// and the web page copied the invite URL to their clipboard.
    func checkClipboardForInvite() {
        guard pendingInviteCatchupId == nil else { return }

        guard let string = UIPasteboard.general.string,
              let url = URL(string: string) else { return }

        if handleIncomingURL(url) {
            // Clear the clipboard so we don't re-process it
            UIPasteboard.general.string = ""
        }
    }
}
