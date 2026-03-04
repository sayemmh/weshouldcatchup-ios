import Foundation
import Combine

/// Manages the "I'm Free" live state and incoming pings.
@MainActor
class LiveViewModel: ObservableObject {

    // MARK: - Static Flag

    /// True when LiveWaitingView is active, so RootView doesn't double-handle pings.
    static var isActive = false

    // MARK: - Published State

    enum LiveState: Equatable {
        case idle
        case goingLive          // Sending request to backend
        case searching          // Rotation engine is pinging people
        case waitingPassively   // Queue exhausted, staying live until TTL
        case noMatch            // TTL expired, nobody was free
    }

    @Published var state: LiveState = .idle
    @Published var liveTTL: Date?
    @Published var errorMessage: String?

    // MARK: - Rotation Progress

    @Published var queue: [QueueItem] = []
    @Published var currentlyPingingUserId: String?
    @Published var currentlyPingingName: String?
    /// User IDs that have already been pinged (no response).
    @Published var passedUserIds: Set<String> = []

    // MARK: - Incoming Ping

    @Published var incomingPingFromName: String?
    @Published var incomingPingCatchupId: String?
    @Published var incomingPingCallId: String?
    @Published var showIncomingPing: Bool = false

    // MARK: - Connection Result

    @Published var connectedCallId: String?
    @Published var connectedAgoraChannel: String?
    @Published var connectedAgoraToken: String?
    @Published var connectedOtherUserName: String?

    // MARK: - Call Ended

    @Published var showCallEnded: Bool = false
    @Published var callEndedName: String = ""
    @Published var callEndedDuration: Int = 0

    // MARK: - Observers

    private var cancellables = Set<AnyCancellable>()

    init() {
        observeNotifications()
    }

    private func observeNotifications() {
        // Listen for incoming pings (mutual-live scenario: User B is also on LiveWaitingView)
        NotificationCenter.default.publisher(for: .incomingCatchUpPing)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let info = notification.userInfo,
                      let fromName = info["fromUserName"] as? String,
                      let catchupId = info["catchupId"] as? String,
                      let callId = info["callId"] as? String
                else { return }
                self?.handlePing(fromName: fromName, catchupId: catchupId, callId: callId)
            }
            .store(in: &cancellables)

        // Listen for rotation_update (server tells us who's currently being pinged)
        NotificationCenter.default.publisher(for: .rotationUpdate)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let self,
                      let info = notification.userInfo,
                      let userId = info["pingingUserId"] as? String,
                      let name = info["pingingUserName"] as? String
                else { return }
                // Mark previous person as passed
                if let prev = self.currentlyPingingUserId {
                    self.passedUserIds.insert(prev)
                }
                self.currentlyPingingUserId = userId
                self.currentlyPingingName = name
            }
            .store(in: &cancellables)

        // Listen for call_ready (User A receives this when User B accepts)
        NotificationCenter.default.publisher(for: .callReady)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let info = notification.userInfo,
                      let fromUserName = info["fromUserName"] as? String,
                      let callId = info["callId"] as? String
                else { return }
                Task { [weak self] in
                    await self?.handleCallReady(callId: callId, otherUserName: fromUserName)
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Call Ready (User A flow)

    private func handleCallReady(callId: String, otherUserName: String) async {
        do {
            let response = try await APIService.shared.joinCall(callId: callId)
            connectedCallId = response.callId
            connectedAgoraChannel = response.agoraChannel
            connectedAgoraToken = response.agoraToken
            connectedOtherUserName = otherUserName
        } catch {
            errorMessage = "Couldn't join the call. Please try again."
        }
    }

    // MARK: - Go Live

    func goLive() async {
        state = .goingLive
        errorMessage = nil

        // Fetch queue so we can show who's being pinged.
        do {
            queue = try await APIService.shared.fetchQueue()
        } catch {
            // Non-fatal — UI just won't show the queue list.
            queue = []
        }

        do {
            let response = try await APIService.shared.goLive()
            state = .searching

            if let ttlString = response.liveTTL,
               let ttlDate = ISO8601DateFormatter().date(from: ttlString) {
                liveTTL = ttlDate
                scheduleTimeout(at: ttlDate)
            }
        } catch {
            errorMessage = "Couldn't go live. Please try again."
            state = .idle
        }
    }

    func cancelLive() async {
        do {
            try await APIService.shared.cancelLive()
        } catch {
            // Best effort — reset local state either way.
        }
        state = .idle
        liveTTL = nil
    }

    // MARK: - Handle Incoming Ping

    func handlePing(fromName: String, catchupId: String, callId: String) {
        incomingPingFromName = fromName
        incomingPingCatchupId = catchupId
        incomingPingCallId = callId
        showIncomingPing = true
    }

    func acceptPing() async {
        guard let catchupId = incomingPingCatchupId,
              let callId = incomingPingCallId else { return }

        do {
            let response = try await APIService.shared.acceptPing(catchupId: catchupId, callId: callId)
            connectedCallId = response.callId
            connectedAgoraChannel = response.agoraChannel
            connectedAgoraToken = response.agoraToken
            connectedOtherUserName = incomingPingFromName
            showIncomingPing = false
        } catch {
            errorMessage = "Couldn't connect. They may no longer be free."
            showIncomingPing = false
        }
    }

    func declinePing() {
        showIncomingPing = false
        incomingPingFromName = nil
        incomingPingCatchupId = nil
        incomingPingCallId = nil
    }

    // MARK: - Timeout

    private func scheduleTimeout(at date: Date) {
        let delay = date.timeIntervalSinceNow
        guard delay > 0 else {
            state = .noMatch
            return
        }

        Task {
            try? await Task.sleep(for: .seconds(delay))
            if state == .searching || state == .waitingPassively {
                state = .noMatch
            }
        }
    }
}
