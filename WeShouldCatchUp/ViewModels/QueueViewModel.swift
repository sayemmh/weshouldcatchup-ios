import Foundation
import Combine

/// Manages the main screen queue and invite actions.
@MainActor
class QueueViewModel: ObservableObject {

    // MARK: - Published State

    @Published var queue: [QueueItem] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    // MARK: - Queue Management

    func fetchQueue() async {
        isLoading = true
        errorMessage = nil

        do {
            queue = try await APIService.shared.fetchQueue()
        } catch {
            errorMessage = "Couldn't load your queue."
        }

        isLoading = false
    }

    func removeFromQueue(catchupId: String) async {
        do {
            try await APIService.shared.removeCatchup(catchupId: catchupId)
            queue.removeAll { $0.catchupId == catchupId }
        } catch {
            errorMessage = "Couldn't remove. Please try again."
        }
    }

    // MARK: - Invite

    func createInviteLink() async -> String? {
        do {
            let response = try await APIService.shared.createCatchup()
            return response.inviteLink
        } catch {
            errorMessage = "Couldn't create invite link."
            return nil
        }
    }
}
