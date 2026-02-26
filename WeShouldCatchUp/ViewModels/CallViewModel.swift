import Foundation
import Combine

/// Manages an active voice call session.
@MainActor
class CallViewModel: ObservableObject {

    // MARK: - Published State

    @Published var otherUserName: String
    @Published var callDurationSeconds: Int = 0
    @Published var isMuted: Bool = false
    @Published var isSpeakerOn: Bool = true
    @Published var isCallActive: Bool = false
    @Published var callEnded: Bool = false
    @Published var finalDuration: Int = 0

    // MARK: - Private

    private let callId: String
    private let agoraChannel: String
    private let agoraToken: String
    private let agoraService = AgoraService()
    private var timerTask: Task<Void, Never>?

    // MARK: - Init

    init(otherUserName: String, callId: String, agoraChannel: String, agoraToken: String) {
        self.otherUserName = otherUserName
        self.callId = callId
        self.agoraChannel = agoraChannel
        self.agoraToken = agoraToken
    }

    // MARK: - Call Lifecycle

    func startCall() {
        agoraService.onRemoteUserLeft = { [weak self] in
            Task { @MainActor in
                self?.endCall()
            }
        }

        agoraService.joinChannel(token: agoraToken, channelId: agoraChannel, uid: 0)
        isCallActive = true
        startTimer()
    }

    func endCall() {
        guard isCallActive else { return }
        isCallActive = false
        timerTask?.cancel()

        agoraService.leaveChannel()
        finalDuration = callDurationSeconds

        Task {
            do {
                let response = try await APIService.shared.endCall(callId: callId)
                finalDuration = response.duration
            } catch {
                // Use local duration as fallback.
            }
            callEnded = true
        }
    }

    // MARK: - Controls

    func toggleMute() {
        agoraService.toggleMute()
        isMuted = agoraService.isMuted
    }

    func toggleSpeaker() {
        agoraService.toggleSpeaker()
        isSpeakerOn = agoraService.isSpeakerOn
    }

    // MARK: - Timer

    private func startTimer() {
        timerTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                if !Task.isCancelled {
                    callDurationSeconds += 1
                }
            }
        }
    }
}
