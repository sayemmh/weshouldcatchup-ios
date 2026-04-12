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
        } catch let error as APIError {
            errorMessage = "Queue error: \(error)"
        } catch {
            errorMessage = "Queue error: \(error.localizedDescription)"
        }

        isLoading = false
    }

    func moveQueueItem(from source: IndexSet, to destination: Int) {
        queue.move(fromOffsets: source, toOffset: destination)
        let catchupIds = queue.map { $0.catchupId }
        Task {
            do {
                try await APIService.shared.reorderQueue(catchupIds: catchupIds)
            } catch {
                errorMessage = "Couldn't save queue order."
            }
        }
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
