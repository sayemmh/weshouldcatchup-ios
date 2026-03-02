import SwiftUI

// MARK: - LiveWaitingView

struct LiveWaitingView: View {

    @StateObject private var viewModel = LiveViewModel()
    @Environment(\.dismiss) private var dismiss

    @State private var pulseScale: CGFloat = 1.0
    @State private var pulseOpacity: Double = 0.6
    @State private var isCancelling: Bool = false
    @State private var activeCallVM: CallViewModel?

    var body: some View {
        ZStack {
            Constants.Colors.background
                .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                switch viewModel.state {
                case .idle, .goingLive, .searching:
                    searchingContent
                case .waitingPassively:
                    queueExhaustedContent
                case .noMatch:
                    expiredContent
                }

                Spacer()

                // MARK: - Cancel Button
                if viewModel.state != .noMatch {
                    cancelButton
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 32)
        }
        .navigationBarBackButtonHidden(true)
        .task {
            await viewModel.goLive()
        }
        .onAppear {
            LiveViewModel.isActive = true
        }
        .onDisappear {
            LiveViewModel.isActive = false
        }
        // Incoming ping (mutual-live: someone pings while we're searching)
        .fullScreenCover(isPresented: $viewModel.showIncomingPing) {
            IncomingPingView(
                callerName: viewModel.incomingPingFromName ?? "Someone",
                catchupId: viewModel.incomingPingCatchupId ?? "",
                callId: viewModel.incomingPingCallId ?? "",
                onAccept: {
                    Task { await viewModel.acceptPing() }
                },
                onDecline: {
                    viewModel.declinePing()
                }
            )
        }
        // Voice call (triggered when Agora credentials arrive)
        .fullScreenCover(item: $activeCallVM) { callVM in
            VoiceCallView(viewModel: callVM, onCallEnded: { name, duration in
                activeCallVM = nil
                viewModel.connectedCallId = nil
                viewModel.connectedAgoraChannel = nil
                viewModel.connectedAgoraToken = nil
                viewModel.connectedOtherUserName = nil
                viewModel.callEndedName = name
                viewModel.callEndedDuration = duration
                viewModel.showCallEnded = true
            })
        }
        // Call ended summary
        .fullScreenCover(isPresented: $viewModel.showCallEnded) {
            CallEndedView(
                otherPersonName: viewModel.callEndedName,
                durationSeconds: viewModel.callEndedDuration,
                onDismiss: {
                    viewModel.showCallEnded = false
                    dismiss()
                }
            )
        }
        .onChange(of: viewModel.connectedCallId) { newCallId in
            guard let callId = newCallId,
                  let channel = viewModel.connectedAgoraChannel,
                  let token = viewModel.connectedAgoraToken
            else { return }
            let name = viewModel.connectedOtherUserName ?? "Someone"
            activeCallVM = CallViewModel(otherUserName: name, callId: callId, agoraChannel: channel, agoraToken: token)
        }
    }

    // MARK: - Searching Content

    private var searchingContent: some View {
        VStack(spacing: 24) {
            // Pulsing circle animation
            ZStack {
                Circle()
                    .fill(Constants.Colors.primary.opacity(0.1))
                    .frame(width: 160, height: 160)
                    .scaleEffect(pulseScale)
                    .opacity(pulseOpacity)
                    .animation(
                        .easeInOut(duration: 1.5)
                        .repeatForever(autoreverses: true),
                        value: pulseScale
                    )

                Circle()
                    .fill(Constants.Colors.primary.opacity(0.2))
                    .frame(width: 110, height: 110)
                    .scaleEffect(pulseScale * 0.95)
                    .opacity(pulseOpacity + 0.15)
                    .animation(
                        .easeInOut(duration: 1.5)
                        .repeatForever(autoreverses: true)
                        .delay(0.2),
                        value: pulseScale
                    )

                Circle()
                    .fill(Constants.Colors.primary)
                    .frame(width: 70, height: 70)

                Image(systemName: "hand.wave.fill")
                    .font(.fraunces(28, weight: .semiBold))
                    .foregroundColor(.white)
            }
            .onAppear {
                pulseScale = 1.3
                pulseOpacity = 0.2
            }

            Text("Finding someone to catch up with...")
                .font(.fraunces(22, weight: .medium))
                .fontWeight(.semibold)
                .foregroundColor(Constants.Colors.textPrimary)
                .multilineTextAlignment(.center)

            Text("Sit tight. We're checking your queue.")
                .font(.inter(16))
                .foregroundColor(Constants.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Queue Exhausted Content

    private var queueExhaustedContent: some View {
        VStack(spacing: 24) {
            Image(systemName: "moon.zzz.fill")
                .font(.system(size: 56))
                .foregroundColor(Constants.Colors.textSecondary.opacity(0.5))

            Text("No one's free right now.")
                .font(.fraunces(22, weight: .medium))
                .fontWeight(.semibold)
                .foregroundColor(Constants.Colors.textPrimary)
                .multilineTextAlignment(.center)

            Text("We'll keep you live for a few more minutes in case someone pops in.")
                .font(.inter(16))
                .foregroundColor(Constants.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Expired Content

    private var expiredContent: some View {
        VStack(spacing: 24) {
            Image(systemName: "clock.badge.xmark")
                .font(.system(size: 56))
                .foregroundColor(Constants.Colors.textSecondary.opacity(0.5))

            Text("No luck this time.")
                .font(.fraunces(22, weight: .medium))
                .fontWeight(.semibold)
                .foregroundColor(Constants.Colors.textPrimary)

            Text("Try again later!")
                .font(.inter(16))
                .foregroundColor(Constants.Colors.textSecondary)

            Button {
                dismiss()
            } label: {
                Text("Back to Home")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Constants.Colors.primary)
                    .foregroundColor(.white)
                    .cornerRadius(14)
            }
            .padding(.top, 8)
        }
    }

    // MARK: - Cancel Button

    private var cancelButton: some View {
        Button {
            Task {
                isCancelling = true
                await viewModel.cancelLive()
                isCancelling = false
                dismiss()
            }
        } label: {
            HStack(spacing: 8) {
                if isCancelling {
                    ProgressView()
                        .tint(.secondary)
                }
                Text("Never mind")
                    .fontWeight(.medium)
            }
            .foregroundColor(Constants.Colors.textSecondary)
            .padding(.vertical, 12)
        }
        .disabled(isCancelling)
        .padding(.bottom, 16)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        LiveWaitingView()
    }
}
