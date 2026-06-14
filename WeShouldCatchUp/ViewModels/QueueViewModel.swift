import Foundation
import Combine

/// Manages the unified home list (available + caught-up), invites, and re-catch actions.
@MainActor
class QueueViewModel: ObservableObject {

    // MARK: - Published State

    @Published var queue: [QueueItem] = []
    @Published var isLoading: Bool = false
    @Published var loadFailed: Bool = false
    @Published var errorMessage: String?

    var hasLoadedOnce = false

    // MARK: - Derived sections

    /// People you can ping when you go live (active, not yet caught up — includes pending).
    var availableItems: [QueueItem] { queue.filter { !$0.isCaughtUp } }
    /// People you've already caught up with (shown below, skipped by rotation).
    var caughtUpItems: [QueueItem] { queue.filter { $0.isCaughtUp } }
    /// Incoming "catch up again" requests, for the section badge.
    var incomingCount: Int { caughtUpItems.filter { $0.recatch == .incoming }.count }

    // MARK: - Fetch (resilient: keep last-known data on transient failure)

    func fetchQueue() async {
        if !hasLoadedOnce { isLoading = true }
        do {
            queue = try await APIService.shared.fetchQueue()
            loadFailed = false
            errorMessage = nil
            hasLoadedOnce = true
        } catch {
            // Keep whatever we already have; only surface an error if we have nothing.
            loadFailed = true
            if queue.isEmpty { errorMessage = "Couldn't refresh. Pull to try again." }
        }
        isLoading = false
    }

    // MARK: - Reordering

    func moveQueueItem(from source: IndexSet, to destination: Int) {
        queue.move(fromOffsets: source, toOffset: destination)
        persistOrder()
    }

    func moveToTop(catchupId: String) {
        guard let idx = queue.firstIndex(where: { $0.catchupId == catchupId }), idx > 0 else { return }
        let item = queue.remove(at: idx)
        queue.insert(item, at: 0)
        persistOrder()
    }

    private func persistOrder() {
        let catchupIds = queue.map { $0.catchupId }
        Task {
            do { try await APIService.shared.reorderQueue(catchupIds: catchupIds) }
            catch { errorMessage = "Couldn't save queue order." }
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

    // MARK: - Report & Block

    func reportUser(catchupId: String, userId: String) async {
        do {
            try await APIService.shared.reportUser(catchupId: catchupId, reportedUserId: userId)
            queue.removeAll { $0.catchupId == catchupId }
        } catch {
            errorMessage = "Couldn't report. Please try again."
        }
    }

    // MARK: - Re-catch

    func requestRecatch(catchupId: String) async {
        setRecatchState(catchupId, to: .requestedByMe)
        do { try await APIService.shared.requestRecatch(catchupId: catchupId) }
        catch { errorMessage = "Couldn't send your request." ; await fetchQueue() }
    }

    func acceptRecatch(catchupId: String) async {
        // Re-activates the pair — moves it back to the Available section.
        reactivate(catchupId)
        do { try await APIService.shared.acceptRecatch(catchupId: catchupId) }
        catch { errorMessage = "Couldn't accept." ; await fetchQueue() }
    }

    func declineRecatch(catchupId: String) async {
        setRecatchState(catchupId, to: .idle)
        do { try await APIService.shared.declineRecatch(catchupId: catchupId) }
        catch { await fetchQueue() }
    }

    // MARK: - Invite

    func createInviteLink(invitedName: String? = nil) async -> String? {
        do {
            return try await APIService.shared.createCatchup(invitedName: invitedName).inviteLink
        } catch {
            errorMessage = "Couldn't create invite link."
            return nil
        }
    }

    // MARK: - Local optimistic helpers (QueueItem is immutable; rebuild in place)

    private func setRecatchState(_ catchupId: String, to state: RecatchState) {
        replace(catchupId) { old in
            QueueItem(catchupId: old.catchupId, otherUser: old.otherUser, lastCallAt: old.lastCallAt,
                      callCount: old.callCount, status: old.status, caughtUp: old.caughtUp, recatchState: state)
        }
    }

    private func reactivate(_ catchupId: String) {
        replace(catchupId) { old in
            QueueItem(catchupId: old.catchupId, otherUser: old.otherUser, lastCallAt: old.lastCallAt,
                      callCount: old.callCount, status: old.status, caughtUp: false, recatchState: .idle)
        }
    }

    private func replace(_ catchupId: String, _ transform: (QueueItem) -> QueueItem) {
        guard let idx = queue.firstIndex(where: { $0.catchupId == catchupId }) else { return }
        queue[idx] = transform(queue[idx])
    }
}
