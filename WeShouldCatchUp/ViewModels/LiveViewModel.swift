import Foundation
import Combine

/// Manages the "I'm Free" live state and incoming pings.
@MainActor
class LiveViewModel: ObservableObject {

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

    // MARK: - Incoming Ping

    @Published var incomingPingFromName: String?
    @Published var incomingPingCatchupId: String?
    @Published var incomingPingCallId: String?
    @Published var showIncomingPing: Bool = false

    // MARK: - Connection Result

    @Published var connectedCallId: String?
    @Published var connectedAgoraChannel: String?
    @Published var connectedAgoraToken: String?

    // MARK: - Go Live

    func goLive() async {
        state = .goingLive
        errorMessage = nil

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
