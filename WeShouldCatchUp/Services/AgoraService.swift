import Foundation
import AVFoundation
import AgoraRtcKit
import Combine

/// Agora Voice SDK wrapper configured for audio-only calling.
final class AgoraService: NSObject, ObservableObject {

    // MARK: - Published Properties

    @Published var isInCall: Bool = false
    @Published var isMuted: Bool = false
    @Published var isSpeakerOn: Bool = true

    // MARK: - Closure

    /// Called when the remote user leaves the channel (e.g. hang-up or disconnect).
    var onRemoteUserLeft: (() -> Void)?

    // MARK: - Private Properties

    private var agoraKit: AgoraRtcEngineKit?

    private let appId: String = Constants.agoraAppID

    // MARK: - Init

    override init() {
        super.init()
    }

    deinit {
        agoraKit?.leaveChannel(nil)
        agoraKit = nil
        AgoraRtcEngineKit.destroy()
    }

    // MARK: - Channel Management

    /// Joins an Agora voice channel.
    func joinChannel(token: String, channelId: String, uid: UInt = 0) {
        print("[AgoraService] joinChannel called — channel=\(channelId)")

        // Request mic permission first, then set up engine and join.
        AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
            guard let self else { return }
            print("[AgoraService] Mic permission: \(granted)")

            DispatchQueue.main.async {
                self.setupEngineAndJoin(token: token, channelId: channelId, uid: uid)
            }
        }
    }

    private func setupEngineAndJoin(token: String, channelId: String, uid: UInt) {
        // Create a fresh engine for this call.
        let config = AgoraRtcEngineConfig()
        config.appId = appId
        config.audioScenario = .chatRoom

        agoraKit = AgoraRtcEngineKit.sharedEngine(with: config, delegate: self)

        guard let engine = agoraKit else {
            print("[AgoraService] ERROR: Failed to create Agora engine")
            return
        }

        // Audio configuration
        engine.setChannelProfile(.communication)
        engine.setAudioProfile(.speechStandard)
        engine.enableAudio()
        engine.disableVideo()
        engine.setDefaultAudioRouteToSpeakerphone(true)
        engine.setEnableSpeakerphone(true)

        // Ensure volumes are up
        engine.adjustRecordingSignalVolume(100)
        engine.adjustPlaybackSignalVolume(100)

        // Enable volume indication for debugging
        engine.enableAudioVolumeIndication(200, smooth: 3, reportVad: true)

        // Join the channel
        let option = AgoraRtcChannelMediaOptions()
        option.publishMicrophoneTrack = true
        option.autoSubscribeAudio = true
        option.channelProfile = .communication
        option.clientRoleType = .broadcaster

        let result = engine.joinChannel(
            byToken: token,
            channelId: channelId,
            uid: uid,
            mediaOptions: option
        )

        print("[AgoraService] joinChannel result: \(result) (0 = success)")
    }

    /// Leaves the current Agora voice channel and resets local state.
    func leaveChannel() {
        agoraKit?.leaveChannel(nil)
        DispatchQueue.main.async {
            self.isInCall = false
            self.isMuted = false
            self.isSpeakerOn = true
        }
    }

    // MARK: - Audio Controls

    /// Toggles the local microphone mute state.
    func toggleMute() {
        isMuted.toggle()
        agoraKit?.muteLocalAudioStream(isMuted)
    }

    /// Toggles between speaker and earpiece audio output.
    func toggleSpeaker() {
        isSpeakerOn.toggle()
        agoraKit?.setEnableSpeakerphone(isSpeakerOn)
    }
}

// MARK: - AgoraRtcEngineDelegate

extension AgoraService: AgoraRtcEngineDelegate {

    func rtcEngine(_ engine: AgoraRtcEngineKit, didJoinChannel channel: String, withUid uid: UInt, elapsed: Int) {
        print("[AgoraService] Joined channel: \(channel), uid: \(uid)")
        DispatchQueue.main.async {
            self.isInCall = true
        }
    }

    func rtcEngine(_ engine: AgoraRtcEngineKit, didLeaveChannelWith stats: AgoraChannelStats) {
        print("[AgoraService] Left channel, duration: \(stats.duration)s")
        DispatchQueue.main.async {
            self.isInCall = false
            self.isMuted = false
        }
    }

    func rtcEngine(_ engine: AgoraRtcEngineKit, didJoinedOfUid uid: UInt, elapsed: Int) {
        print("[AgoraService] Remote user joined: uid=\(uid)")
    }

    func rtcEngine(_ engine: AgoraRtcEngineKit, didOfflineOfUid uid: UInt, reason: AgoraUserOfflineReason) {
        print("[AgoraService] Remote user offline: uid=\(uid), reason=\(reason.rawValue)")
        DispatchQueue.main.async { [weak self] in
            self?.onRemoteUserLeft?()
        }
    }

    func rtcEngine(_ engine: AgoraRtcEngineKit, didOccurError errorCode: AgoraErrorCode) {
        print("[AgoraService] ERROR: \(errorCode.rawValue)")
    }

    func rtcEngine(_ engine: AgoraRtcEngineKit, reportAudioVolumeIndicationOfSpeakers speakers: [AgoraRtcAudioVolumeInfo], totalVolume: Int) {
        // Log periodically to verify audio is flowing
        if totalVolume > 0 {
            print("[AgoraService] Audio detected — totalVolume: \(totalVolume)")
        }
    }
}
