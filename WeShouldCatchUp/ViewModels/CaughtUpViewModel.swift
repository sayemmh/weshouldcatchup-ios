import Foundation
import Combine

/// Manages the "Caught Up" list and the re-catch (catch up again) actions.
@MainActor
class CaughtUpViewModel: ObservableObject {

    @Published var items: [CaughtUpItem] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    /// Number of incoming "catch up again" requests, for the badge on the entry point.
    var incomingCount: Int { items.filter { $0.state == .incoming }.count }

    func fetch() async {
        isLoading = true
        errorMessage = nil
        do {
            items = try await APIService.shared.fetchCaughtUp()
        } catch {
            if items.isEmpty { errorMessage = "Couldn't load your Caught Up list." }
        }
        isLoading = false
    }

    /// Ask to catch up again. Optimistically flips the row to "Requested", then refetches.
    func requestAgain(catchupId: String) async {
        updateState(catchupId, to: .requestedByMe)
        do {
            try await APIService.shared.requestRecatch(catchupId: catchupId)
        } catch {
            errorMessage = "Couldn't send your request. Please try again."
        }
        await fetch()
    }

    /// Accept an incoming request. The pair re-activates, so it leaves this list.
    func accept(catchupId: String) async {
        items.removeAll { $0.catchupId == catchupId }
        do {
            try await APIService.shared.acceptRecatch(catchupId: catchupId)
        } catch {
            errorMessage = "Couldn't accept. Please try again."
            await fetch()
        }
    }

    /// Dismiss an incoming request without accepting.
    func decline(catchupId: String) async {
        updateState(catchupId, to: .idle)
        do {
            try await APIService.shared.declineRecatch(catchupId: catchupId)
        } catch {
            await fetch()
        }
    }

    private func updateState(_ catchupId: String, to state: RecatchState) {
        guard let idx = items.firstIndex(where: { $0.catchupId == catchupId }) else { return }
        let old = items[idx]
        items[idx] = CaughtUpItem(
            catchupId: old.catchupId,
            otherUser: old.otherUser,
            lastCallAt: old.lastCallAt,
            callCount: old.callCount,
            state: state
        )
    }
}
