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
                    .fill(Constants.Colors.primary.opacity(0.08))
                    .frame(width: 160, height: 160)
                    .scaleEffect(pulseScale)
                    .opacity(pulseOpacity)
                    .animation(
                        .easeInOut(duration: 1.5)
                        .repeatForever(autoreverses: true),
                        value: pulseScale
                    )

                Circle()
                    .fill(Constants.Colors.primary.opacity(0.15))
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

                Image(systemName: "hand.wave")
                    .font(.system(size: 26, weight: .regular))
                    .foregroundColor(.white)
            }
            .onAppear {
                pulseScale = 1.3
                pulseOpacity = 0.2
            }

            Text("Looking for someone...")
                .font(.fraunces(22, weight: .semiBold))
                .foregroundColor(Constants.Colors.textPrimary)
                .multilineTextAlignment(.center)

            Text("Sit tight. We're checking your queue.")
                .font(.inter(15, weight: .regular))
                .foregroundColor(Constants.Colors.textSecondary)
                .multilineTextAlignment(.center)

            // Queue progress list (active only — pending invites can't be called)
            if !activeQueue.isEmpty {
                queueProgressList
            }
        }
    }

    // MARK: - Queue Exhausted Content

    private var queueExhaustedContent: some View {
        VStack(spacing: 24) {
            Image(systemName: "moon.zzz")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(Constants.Colors.textTertiary)

            Text("No one's free right now")
                .font(.fraunces(22, weight: .semiBold))
                .foregroundColor(Constants.Colors.textPrimary)
                .multilineTextAlignment(.center)

            Text("We'll keep you live for a few more minutes in case someone pops in.")
                .font(.inter(15, weight: .regular))
                .foregroundColor(Constants.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Expired Content

    private var expiredContent: some View {
        VStack(spacing: 24) {
            Image(systemName: "clock")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(Constants.Colors.textTertiary)

            Text("No luck this time")
                .font(.fraunces(22, weight: .semiBold))
                .foregroundColor(Constants.Colors.textPrimary)

            Text("Try again later when you're free.")
                .font(.inter(15, weight: .regular))
                .foregroundColor(Constants.Colors.textSecondary)

            Button {
                dismiss()
            } label: {
                Text("Back to Home")
                    .font(.inter(15, weight: .semiBold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Constants.Colors.primary)
                    .foregroundColor(.white)
                    .cornerRadius(28)
            }
            .padding(.top, 8)
        }
    }

    private var activeQueue: [QueueItem] {
        viewModel.queue.filter { !$0.isPending }
    }

    // MARK: - Cancel Button

    // MARK: - Queue Progress List

    private var queueProgressList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Your queue")
                .font(.inter(11, weight: .semiBold))
                .foregroundColor(Constants.Colors.textTertiary)
                .textCase(.uppercase)
                .tracking(0.5)

            ForEach(activeQueue) { item in
                let userId = item.otherUser.userId
                let isCurrent = userId == viewModel.currentlyPingingUserId
                let isPassed = viewModel.passedUserIds.contains(userId)

                HStack(spacing: 8) {
                    if isPassed {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(Constants.Colors.textTertiary)
                            .frame(width: 14)
                    } else if isCurrent {
                        PingingDot()
                            .frame(width: 14)
                    } else {
                        Circle()
                            .fill(Constants.Colors.textTertiary.opacity(0.3))
                            .frame(width: 6, height: 6)
                            .frame(width: 14)
                    }

                    Text(item.otherUser.name)
                        .font(.inter(14, weight: isCurrent ? .semiBold : .regular))
                        .foregroundColor(
                            isCurrent ? Constants.Colors.textPrimary :
                            isPassed ? Constants.Colors.textTertiary :
                            Constants.Colors.textSecondary
                        )
                }
            }
        }
        .padding(.top, 16)
    }

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
                        .tint(Constants.Colors.textSecondary)
                }
                Text("Never mind")
                    .font(.inter(15, weight: .medium))
            }
            .foregroundColor(Constants.Colors.textSecondary)
            .padding(.vertical, 12)
        }
        .disabled(isCancelling)
        .padding(.bottom, 16)
    }
}

// MARK: - Pinging Dot

/// A small dot that pulses to indicate the currently-pinged person.
private struct PingingDot: View {
    @State private var isAnimating = false

    var body: some View {
        Circle()
            .fill(Constants.Colors.primary)
            .frame(width: 8, height: 8)
            .scaleEffect(isAnimating ? 1.3 : 0.8)
            .opacity(isAnimating ? 1.0 : 0.5)
            .animation(
                .easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                value: isAnimating
            )
            .onAppear { isAnimating = true }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        LiveWaitingView()
    }
}
