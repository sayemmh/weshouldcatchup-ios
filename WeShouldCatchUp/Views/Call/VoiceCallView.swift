import SwiftUI

// MARK: - CallViewModel

/// ViewModel managing the active voice call state.
final class CallViewModel: ObservableObject {

    // MARK: - Published State

    @Published var isMuted: Bool = false
    @Published var isSpeakerOn: Bool = false
    @Published var callDurationSeconds: Int = 0
    @Published var isCallActive: Bool = true
    @Published var isEnding: Bool = false
    @Published var errorMessage: String?

    /// The other participant's display name.
    let otherPersonName: String

    /// The call ID from the backend.
    let callId: String

    /// The Agora channel details (would be used by the Agora SDK in production).
    let agoraChannel: String
    let agoraToken: String

    private let api = APIService.shared
    private var timerTask: Task<Void, Never>?

    // MARK: - Init

    init(
        otherPersonName: String,
        callId: String,
        agoraChannel: String,
        agoraToken: String
    ) {
        self.otherPersonName = otherPersonName
        self.callId = callId
        self.agoraChannel = agoraChannel
        self.agoraToken = agoraToken
    }

    // MARK: - Computed Properties

    /// Formats the call duration as mm:ss.
    var formattedDuration: String {
        let minutes = callDurationSeconds / 60
        let seconds = callDurationSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    // MARK: - Timer

    @MainActor
    func startTimer() {
        timerTask?.cancel()
        timerTask = Task {
            while !Task.isCancelled && isCallActive {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if isCallActive {
                    callDurationSeconds += 1
                }
            }
        }
    }

    func stopTimer() {
        timerTask?.cancel()
        timerTask = nil
    }

    // MARK: - Actions

    func toggleMute() {
        isMuted.toggle()
        // TODO: Toggle Agora local audio mute.
    }

    func toggleSpeaker() {
        isSpeakerOn.toggle()
        // TODO: Toggle Agora speaker/earpiece routing.
    }

    @MainActor
    func endCall() async -> Int? {
        isEnding = true
        stopTimer()
        do {
            let response = try await api.endCall(callId: callId)
            isCallActive = false
            isEnding = false
            return response.duration
        } catch {
            errorMessage = error.localizedDescription
            isEnding = false
            return nil
        }
    }
}

// MARK: - Design Constants

private extension Color {
    static let warmCoral = Color(red: 0.90, green: 0.45, blue: 0.35)
}

// MARK: - VoiceCallView

struct VoiceCallView: View {

    @StateObject var viewModel: CallViewModel

    /// Called when the call ends, passing the other person's name and the duration in seconds.
    var onCallEnded: ((_ name: String, _ duration: Int) -> Void)?

    var body: some View {
        ZStack {
            // MARK: - Dark Background
            Color.black
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // MARK: - Caller Info
                callerInfoSection

                Spacer()

                // MARK: - Call Controls
                callControlsSection
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
        }
        .statusBarHidden(false)
        .preferredColorScheme(.dark)
        .task {
            viewModel.startTimer()
        }
    }

    // MARK: - Caller Info

    private var callerInfoSection: some View {
        VStack(spacing: 16) {
            // Avatar
            ZStack {
                Circle()
                    .fill(Color.warmCoral.opacity(0.25))
                    .frame(width: 90, height: 90)

                Text(String(viewModel.otherPersonName.prefix(1)).uppercased())
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.warmCoral)
            }

            // Name
            Text(viewModel.otherPersonName)
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.white)

            // Duration
            Text(viewModel.formattedDuration)
                .font(.title2.monospacedDigit())
                .foregroundColor(.white.opacity(0.7))
        }
    }

    // MARK: - Call Controls

    private var callControlsSection: some View {
        HStack(spacing: 48) {
            // Mute
            callControlButton(
                icon: viewModel.isMuted ? "mic.slash" : "mic",
                label: viewModel.isMuted ? "Unmute" : "Mute",
                isActive: viewModel.isMuted,
                action: { viewModel.toggleMute() }
            )

            // End Call
            endCallButton

            // Speaker
            callControlButton(
                icon: viewModel.isSpeakerOn ? "speaker.wave.2" : "speaker.slash",
                label: viewModel.isSpeakerOn ? "Speaker" : "Earpiece",
                isActive: viewModel.isSpeakerOn,
                action: { viewModel.toggleSpeaker() }
            )
        }
    }

    // MARK: - Control Button Helper

    private func callControlButton(
        icon: String,
        label: String,
        isActive: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(isActive ? Color.white.opacity(0.25) : Color.white.opacity(0.1))
                        .frame(width: 60, height: 60)

                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundColor(.white)
                }

                Text(label)
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.6))
            }
        }
    }

    // MARK: - End Call Button

    private var endCallButton: some View {
        Button {
            Task {
                let duration = await viewModel.endCall()
                onCallEnded?(viewModel.otherPersonName, duration ?? viewModel.callDurationSeconds)
            }
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 68, height: 68)

                    if viewModel.isEnding {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "phone.down.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                }

                Text("End")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .disabled(viewModel.isEnding)
    }
}

// MARK: - Preview

#Preview {
    VoiceCallView(
        viewModel: CallViewModel(
            otherPersonName: "Alex",
            callId: "preview-call-1",
            agoraChannel: "channel-123",
            agoraToken: "token-abc"
        )
    )
}
