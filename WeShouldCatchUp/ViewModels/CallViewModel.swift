import Foundation
import Combine
import UserNotifications

/// Manages an active voice call session.
@MainActor
class CallViewModel: ObservableObject, Identifiable {

    let id = UUID()

    // MARK: - Published State

    @Published var otherUserName: String
    @Published var callDurationSeconds: Int = 0
    @Published var isMuted: Bool = false
    @Published var isSpeakerOn: Bool = true
    @Published var isCallActive: Bool = false
    @Published var callEnded: Bool = false
    @Published var finalDuration: Int = 0
    @Published var debugLog: String = ""
    @Published var connectionPhase: AgoraService.ConnectionPhase = .idle

    // MARK: - Private

    private let callId: String
    private let agoraChannel: String
    private let agoraToken: String
    private let agoraService = AgoraService()
    private var timerTask: Task<Void, Never>?
    private var connectTimeoutTask: Task<Void, Never>?
    private var remoteJoinTimeoutTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    /// How long to wait for the channel join before declaring failure.
    private static let connectTimeout: Duration = .seconds(20)
    /// How long to wait alone in the channel before giving up on the other person.
    private static let remoteJoinTimeout: Duration = .seconds(60)

    // MARK: - Init

    init(otherUserName: String, callId: String, agoraChannel: String, agoraToken: String) {
        self.otherUserName = otherUserName
        self.callId = callId
        self.agoraChannel = agoraChannel
        self.agoraToken = agoraToken
    }

    // MARK: - Call Lifecycle

    func startCall() {
        print("[CallViewModel] startCall: channel=\(agoraChannel), callId=\(callId), otherUser=\(otherUserName)")

        // Clear stale "X is free to catch up" banners now that we're in a call.
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()

        agoraService.onRemoteUserLeft = { [weak self] in
            Task { @MainActor in
                print("[CallViewModel] Remote user left (Agora) — ending call")
                self?.handleRemoteHangUp()
            }
        }

        // Backup: listen for push-based call_ended in case Agora disconnect is slow
        NotificationCenter.default.publisher(for: .callEndedRemotely)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let self,
                      let info = notification.userInfo,
                      let pushCallId = info["callId"] as? String,
                      pushCallId == self.callId
                else { return }
                print("[CallViewModel] Remote user left (push) — ending call")
                self.handleRemoteHangUp()
            }
            .store(in: &cancellables)

        // Mirror the Agora connection phase and react to transitions.
        agoraService.$connectionPhase
            .receive(on: DispatchQueue.main)
            .sink { [weak self] phase in
                guard let self else { return }
                self.connectionPhase = phase
                switch phase {
                case .connected:
                    self.connectTimeoutTask?.cancel()
                    self.remoteJoinTimeoutTask?.cancel()
                    if self.timerTask == nil { self.startTimer() }
                case .waitingForRemote:
                    self.connectTimeoutTask?.cancel()
                    self.startRemoteJoinTimeout()
                case .failed, .micDenied:
                    self.connectTimeoutTask?.cancel()
                    self.remoteJoinTimeoutTask?.cancel()
                    self.timerTask?.cancel()
                    self.timerTask = nil
                default:
                    break
                }
            }
            .store(in: &cancellables)

        // Forward debug log from Agora service
        agoraService.$debugStatus
            .receive(on: DispatchQueue.main)
            .assign(to: &$debugLog)

        agoraService.joinChannel(token: agoraToken, channelId: agoraChannel, uid: 0)
        isCallActive = true

        // If we never even join the channel, fail visibly instead of spinning.
        connectTimeoutTask = Task { [weak self] in
            try? await Task.sleep(for: Self.connectTimeout)
            guard let self, !Task.isCancelled else { return }
            if case .connecting = self.connectionPhase {
                self.connectionPhase = .failed("Couldn't reach the call server.")
            }
        }
    }

    /// If the other person never joins (missed the notification, lost signal),
    /// don't leave the user sitting in an empty channel forever.
    private func startRemoteJoinTimeout() {
        remoteJoinTimeoutTask?.cancel()
        remoteJoinTimeoutTask = Task { [weak self] in
            try? await Task.sleep(for: Self.remoteJoinTimeout)
            guard let self, !Task.isCancelled else { return }
            if case .waitingForRemote = self.connectionPhase {
                self.connectionPhase = .failed("\(self.otherUserName) couldn't make it this time.")
            }
        }
    }

    func endCall() {
        guard isCallActive else { return }
        isCallActive = false
        timerTask?.cancel()
        connectTimeoutTask?.cancel()

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

    /// Called when the remote user hangs up (detected via Agora delegate).
    /// Sets callEnded so the view auto-dismisses.
    private func handleRemoteHangUp() {
        guard isCallActive else { return }
        isCallActive = false
        timerTask?.cancel()
        connectTimeoutTask?.cancel()

        agoraService.leaveChannel()
        finalDuration = callDurationSeconds

        // Mark ended immediately so the UI reacts without waiting for the API.
        callEnded = true

        Task {
            do {
                let response = try await APIService.shared.endCall(callId: callId)
                finalDuration = response.duration
            } catch {
                // Other side already called end-call, that's fine.
            }
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
