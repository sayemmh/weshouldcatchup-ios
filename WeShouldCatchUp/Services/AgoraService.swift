import Foundation
import AVFoundation
import AgoraRtcKit
import Combine

/// Agora Voice SDK wrapper for 1-on-1 audio calls.
///
/// Uses the communication profile (designed for 1:1 calls). Connection progress
/// is surfaced via `connectionPhase` so the UI never pretends a call is live
/// when the channel join failed.
final class AgoraService: NSObject, ObservableObject {

    // MARK: - Connection Phase

    enum ConnectionPhase: Equatable {
        case idle
        case connecting
        case waitingForRemote   // joined the channel, other person not here yet
        case connected          // both sides in the channel
        case failed(String)     // join failed (reason shown to user)
        case micDenied
    }

    // MARK: - Published Properties

    @Published var connectionPhase: ConnectionPhase = .idle
    @Published var isInCall: Bool = false
    @Published var isMuted: Bool = false
    @Published var isSpeakerOn: Bool = true
    @Published var remoteUserJoined: Bool = false
    /// On-screen debug log so we can diagnose without Console.app
    @Published var debugStatus: String = ""

    // MARK: - Closure

    var onRemoteUserLeft: (() -> Void)?

    // MARK: - Private Properties

    private var agoraKit: AgoraRtcEngineKit?
    private let appId: String = Constants.agoraAppID

    /// The instance that owns the shared Agora engine. `AgoraRtcEngineKit.destroy()`
    /// is global, so a stale instance deiniting must never destroy a newer call's engine.
    private static weak var engineOwner: AgoraService?

    // MARK: - Debug Log

    private func log(_ msg: String) {
        print("[Agora] \(msg)")
        DispatchQueue.main.async {
            var lines = self.debugStatus.components(separatedBy: "\n")
            lines.append(msg)
            if lines.count > 20 { lines = Array(lines.suffix(20)) }
            self.debugStatus = lines.joined(separator: "\n")
        }
    }

    // MARK: - Init / Deinit

    override init() {
        super.init()
    }

    deinit {
        // Only tear down the engine if this instance still owns it.
        if AgoraService.engineOwner === self, agoraKit != nil {
            agoraKit?.leaveChannel(nil)
            agoraKit = nil
            AgoraRtcEngineKit.destroy()
        }
    }

    // MARK: - Channel Management

    func joinChannel(token: String, channelId: String, uid: UInt = 0) {
        log("JOIN channel=\(channelId) tokenLen=\(token.count)")
        setPhase(.connecting)

        let audioSession = AVAudioSession.sharedInstance()
        switch audioSession.recordPermission {
        case .granted:
            log("Mic: granted")
            initializeAndJoin(token: token, channelId: channelId, uid: uid)
        case .undetermined:
            log("Mic: requesting...")
            audioSession.requestRecordPermission { [weak self] granted in
                self?.log("Mic: \(granted ? "granted" : "DENIED")")
                DispatchQueue.main.async {
                    guard granted else {
                        self?.setPhase(.micDenied)
                        return
                    }
                    self?.initializeAndJoin(token: token, channelId: channelId, uid: uid)
                }
            }
        case .denied:
            log("ERROR: Mic DENIED")
            setPhase(.micDenied)
        @unknown default:
            break
        }
    }

    private func initializeAndJoin(token: String, channelId: String, uid: UInt) {
        if agoraKit != nil {
            log("Destroying prev engine")
            agoraKit?.leaveChannel(nil)
            agoraKit = nil
            AgoraRtcEngineKit.destroy()
        }

        let config = AgoraRtcEngineConfig()
        config.appId = appId
        config.audioScenario = .default

        agoraKit = AgoraRtcEngineKit.sharedEngine(with: config, delegate: self)
        AgoraService.engineOwner = self

        guard let engine = agoraKit else {
            log("ERROR: engine nil!")
            setPhase(.failed("Couldn't start the call engine."))
            return
        }
        log("Engine created")

        engine.setChannelProfile(.communication)
        engine.setAudioProfile(.speechStandard)
        engine.enableAudio()
        engine.disableVideo()
        engine.setDefaultAudioRouteToSpeakerphone(true)
        engine.setEnableSpeakerphone(true)
        engine.enableAudioVolumeIndication(500, smooth: 3, reportVad: true)
        log("Configured: communication profile")

        let options = AgoraRtcChannelMediaOptions()
        options.channelProfile = .communication
        options.clientRoleType = .broadcaster
        options.publishMicrophoneTrack = true
        options.autoSubscribeAudio = true

        let joinResult = engine.joinChannel(
            byToken: token,
            channelId: channelId,
            uid: uid,
            mediaOptions: options
        )
        log("joinChannel result=\(joinResult)")
        if joinResult != 0 {
            setPhase(.failed("Couldn't connect (code \(joinResult))."))
        }
    }

    func leaveChannel() {
        guard let engine = agoraKit else { return }
        engine.leaveChannel(nil)
        agoraKit = nil
        if AgoraService.engineOwner === self {
            AgoraRtcEngineKit.destroy()
            AgoraService.engineOwner = nil
        }
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)

        DispatchQueue.main.async {
            self.isInCall = false
            self.isMuted = false
            self.isSpeakerOn = true
            self.remoteUserJoined = false
            self.connectionPhase = .idle
        }
        log("Left + destroyed")
    }

    private func setPhase(_ phase: ConnectionPhase) {
        DispatchQueue.main.async {
            self.connectionPhase = phase
        }
    }

    // MARK: - Audio Controls

    func toggleMute() {
        isMuted.toggle()
        agoraKit?.muteLocalAudioStream(isMuted)
    }

    func toggleSpeaker() {
        isSpeakerOn.toggle()
        agoraKit?.setEnableSpeakerphone(isSpeakerOn)
    }
}

// MARK: - AgoraRtcEngineDelegate

extension AgoraService: AgoraRtcEngineDelegate {

    func rtcEngine(_ engine: AgoraRtcEngineKit, didJoinChannel channel: String, withUid uid: UInt, elapsed: Int) {
        log("JOINED uid=\(uid) elapsed=\(elapsed)ms")
        DispatchQueue.main.async {
            self.isInCall = true
            if self.connectionPhase != .connected {
                self.connectionPhase = self.remoteUserJoined ? .connected : .waitingForRemote
            }
        }

        engine.muteLocalAudioStream(false)
        engine.muteAllRemoteAudioStreams(false)
        engine.adjustRecordingSignalVolume(100)
        engine.adjustPlaybackSignalVolume(100)
    }

    func rtcEngine(_ engine: AgoraRtcEngineKit, didLeaveChannelWith stats: AgoraChannelStats) {
        log("LEFT tx=\(stats.txAudioBytes)B rx=\(stats.rxAudioBytes)B")
        DispatchQueue.main.async { self.isInCall = false }
    }

    func rtcEngine(_ engine: AgoraRtcEngineKit, didJoinedOfUid uid: UInt, elapsed: Int) {
        log("REMOTE JOINED uid=\(uid)")
        DispatchQueue.main.async {
            self.remoteUserJoined = true
            self.connectionPhase = .connected
        }
    }

    func rtcEngine(_ engine: AgoraRtcEngineKit, didOfflineOfUid uid: UInt, reason: AgoraUserOfflineReason) {
        log("REMOTE LEFT uid=\(uid) reason=\(reason.rawValue)")
        DispatchQueue.main.async { [weak self] in
            self?.remoteUserJoined = false
            self?.onRemoteUserLeft?()
        }
    }

    func rtcEngine(_ engine: AgoraRtcEngineKit, didOccurError errorCode: AgoraErrorCode) {
        log("ERROR code=\(errorCode.rawValue)")
        // Token rejected / invalid app ID — surface instead of spinning forever.
        if errorCode == .invalidToken || errorCode == .tokenExpired || errorCode == .invalidAppId {
            setPhase(.failed("Call authorization failed (\(errorCode.rawValue))."))
        }
    }

    func rtcEngine(_ engine: AgoraRtcEngineKit, connectionChangedTo state: AgoraConnectionState, reason: AgoraConnectionChangedReason) {
        log("CONN state=\(state.rawValue) reason=\(reason.rawValue)")
        if state == .failed {
            setPhase(.failed("Connection failed (reason \(reason.rawValue))."))
        }
    }

    func rtcEngine(_ engine: AgoraRtcEngineKit, reportAudioVolumeIndicationOfSpeakers speakers: [AgoraRtcAudioVolumeInfo], totalVolume: Int) {
        for speaker in speakers {
            if speaker.volume > 0 {
                let who = speaker.uid == 0 ? "LOCAL" : "REMOTE(\(speaker.uid))"
                log("AUDIO \(who) vol=\(speaker.volume)")
            }
        }
    }

    func rtcEngine(_ engine: AgoraRtcEngineKit, localAudioStateChanged state: AgoraAudioLocalState, reason: AgoraAudioLocalReason) {
        log("LOCAL_AUDIO state=\(state.rawValue) reason=\(reason.rawValue)")
    }

    func rtcEngine(_ engine: AgoraRtcEngineKit, remoteAudioStateChangedOfUid uid: UInt, state: AgoraAudioRemoteState, reason: AgoraAudioRemoteReason, elapsed: Int) {
        log("REMOTE_AUDIO uid=\(uid) state=\(state.rawValue) reason=\(reason.rawValue)")
    }

    func rtcEngine(_ engine: AgoraRtcEngineKit, tokenPrivilegeWillExpire token: String) {
        log("TOKEN EXPIRING")
    }
}
