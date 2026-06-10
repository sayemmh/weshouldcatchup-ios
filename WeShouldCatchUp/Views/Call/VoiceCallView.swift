import SwiftUI

// MARK: - VoiceCallView

struct VoiceCallView: View {

    @StateObject var viewModel: CallViewModel
    @State private var isEnding: Bool = false
    @State private var showDebugLog: Bool = false

    /// Called when the call ends, passing the other person's name and the duration in seconds.
    var onCallEnded: ((_ name: String, _ duration: Int) -> Void)?

    /// Formats callDurationSeconds into a mm:ss string.
    private var formattedDuration: String {
        let minutes = viewModel.callDurationSeconds / 60
        let seconds = viewModel.callDurationSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private var isFailed: Bool {
        if case .failed = viewModel.connectionPhase { return true }
        if case .micDenied = viewModel.connectionPhase { return true }
        return false
    }

    var body: some View {
        ZStack {
            // MARK: - Dark Background
            Color.black
                .ignoresSafeArea()

            VStack(spacing: 0) {
                if showDebugLog {
                    ScrollView {
                        Text(viewModel.debugLog)
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(.green)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                    }
                    .frame(maxHeight: 200)
                    .background(Color.black.opacity(0.8))
                }

                Spacer()

                // MARK: - Caller Info
                callerInfoSection

                Spacer()

                // MARK: - Call Controls
                if isFailed {
                    failedSection
                } else {
                    callControlsSection
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
        }
        .statusBarHidden(false)
        .preferredColorScheme(.dark)
        .task {
            viewModel.startCall()
        }
        .onChange(of: viewModel.callEnded) { ended in
            guard ended, !isEnding else { return }
            // Remote user hung up — dismiss automatically
            onCallEnded?(viewModel.otherUserName, viewModel.finalDuration)
        }
    }

    // MARK: - Connection Status

    @ViewBuilder
    private var connectionStatus: some View {
        switch viewModel.connectionPhase {
        case .idle, .connecting:
            HStack(spacing: 8) {
                ProgressView().tint(.white.opacity(0.7))
                Text("Connecting...")
            }
            .font(.inter(15, weight: .regular))
            .foregroundColor(.white.opacity(0.7))

        case .waitingForRemote:
            Text("Waiting for \(viewModel.otherUserName) to join...")
                .font(.inter(15, weight: .regular))
                .foregroundColor(.white.opacity(0.7))

        case .connected:
            Text(formattedDuration)
                .font(.title2.monospacedDigit())
                .foregroundColor(.white.opacity(0.7))

        case .micDenied:
            VStack(spacing: 8) {
                Text("Microphone access is off")
                    .font(.inter(15, weight: .semiBold))
                    .foregroundColor(.white)
                Text("Enable it in Settings to make calls.")
                    .font(.inter(13, weight: .regular))
                    .foregroundColor(.white.opacity(0.7))
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .font(.inter(14, weight: .semiBold))
                .foregroundColor(Constants.Colors.primaryLight)
            }

        case .failed(let reason):
            VStack(spacing: 6) {
                Text("Couldn't connect")
                    .font(.inter(15, weight: .semiBold))
                    .foregroundColor(.white)
                Text(reason)
                    .font(.inter(13, weight: .regular))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
        }
    }

    // MARK: - Caller Info

    private var callerInfoSection: some View {
        VStack(spacing: 16) {
            // Avatar — long-press toggles the on-screen debug log
            ZStack {
                Circle()
                    .fill(Constants.Colors.primary.opacity(0.25))
                    .frame(width: 90, height: 90)

                Text(String(viewModel.otherUserName.prefix(1)).uppercased())
                    .font(.fraunces(34, weight: .bold))
                    .foregroundColor(Constants.Colors.primary)
            }
            .onLongPressGesture(minimumDuration: 1.0) {
                showDebugLog.toggle()
            }

            // Name
            Text(viewModel.otherUserName)
                .font(.fraunces(28, weight: .semiBold))
                .foregroundColor(.white)

            connectionStatus
        }
    }

    // MARK: - Failed State

    private var failedSection: some View {
        Button {
            isEnding = true
            viewModel.endCall()
            onCallEnded?(viewModel.otherUserName, 0)
        } label: {
            Text("Close")
                .font(.inter(16, weight: .semiBold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.white.opacity(0.15))
                .cornerRadius(28)
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
                        .font(.system(size: 22, weight: .regular))
                        .foregroundColor(.white)
                }

                Text(label)
                    .font(.inter(11, weight: .regular))
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
                            .font(.system(size: 22, weight: .regular))
                            .foregroundColor(.white)
                    }
                }

                Text("End")
                    .font(.inter(11, weight: .regular))
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
