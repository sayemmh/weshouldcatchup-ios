import SwiftUI

// MARK: - VoiceCallView

struct VoiceCallView: View {

    @StateObject var viewModel: CallViewModel
    @State private var isEnding: Bool = false

    /// Called when the call ends, passing the other person's name and the duration in seconds.
    var onCallEnded: ((_ name: String, _ duration: Int) -> Void)?

    /// Formats callDurationSeconds into a mm:ss string.
    private var formattedDuration: String {
        let minutes = viewModel.callDurationSeconds / 60
        let seconds = viewModel.callDurationSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

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
            viewModel.startCall()
        }
    }

    // MARK: - Caller Info

    private var callerInfoSection: some View {
        VStack(spacing: 16) {
            // Avatar
            ZStack {
                Circle()
                    .fill(Constants.Colors.primary.opacity(0.25))
                    .frame(width: 90, height: 90)

                Text(String(viewModel.otherUserName.prefix(1)).uppercased())
                    .font(.fraunces(34, weight: .bold))
                    .fontWeight(.bold)
                    .foregroundColor(Constants.Colors.primary)
            }

            // Name
            Text(viewModel.otherUserName)
                .font(.fraunces(28, weight: .semiBold))
                .fontWeight(.bold)
                .foregroundColor(.white)

            // Duration
            Text(formattedDuration)
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
                        .font(.fraunces(22, weight: .medium))
                        .foregroundColor(.white)
                }

                Text(label)
                    .font(.fraunces(11, weight: .regular))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
    }

    // MARK: - End Call Button

    private var endCallButton: some View {
        Button {
            Task {
                isEnding = true
                viewModel.endCall()
                onCallEnded?(viewModel.otherUserName, viewModel.finalDuration)
                isEnding = false
            }
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 68, height: 68)

                    if isEnding {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "phone.down.fill")
                            .font(.fraunces(22, weight: .medium))
                            .foregroundColor(.white)
                    }
                }

                Text("End")
                    .font(.fraunces(11, weight: .regular))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .disabled(isEnding)
    }
}

// MARK: - Preview

#Preview {
    VoiceCallView(
        viewModel: CallViewModel(
            otherUserName: "Alex",
            callId: "preview-call-1",
            agoraChannel: "channel-123",
            agoraToken: "token-abc"
        )
    )
}
