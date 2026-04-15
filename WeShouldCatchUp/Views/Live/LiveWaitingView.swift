import SwiftUI

struct LiveWaitingView: View {

    @StateObject private var viewModel = LiveViewModel()
    @Environment(\.dismiss) private var dismiss

    @State private var pulseScale: CGFloat = 1.0
    @State private var pulseOpacity: Double = 0.6
    @State private var isCancelling: Bool = false
    @State private var activeCallVM: CallViewModel?
    @State private var clientPingIndex: Int = 0
    @State private var pingTimer: Timer?

    private var activeQueue: [QueueItem] {
        viewModel.queue.filter { !$0.isPending }
    }

    private var currentPingingName: String? {
        if let serverName = viewModel.currentlyPingingName {
            return serverName
        }
        guard !activeQueue.isEmpty, clientPingIndex < activeQueue.count else { return nil }
        return activeQueue[clientPingIndex].otherUser.name
    }

    private var currentPingingUserId: String? {
        viewModel.currentlyPingingUserId ?? {
            guard !activeQueue.isEmpty, clientPingIndex < activeQueue.count else { return nil }
            return activeQueue[clientPingIndex].otherUser.userId
        }()
    }

    var body: some View {
        ZStack {
            Constants.Colors.background
                .ignoresSafeArea()

            VStack(spacing: 24) {
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
            startClientPingTimer()
        }
        .onAppear {
            LiveViewModel.isActive = true
        }
        .onDisappear {
            LiveViewModel.isActive = false
            pingTimer?.invalidate()
        }
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

    // MARK: - Client-side ping timer

    private func startClientPingTimer() {
        pingTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { _ in
            Task { @MainActor in
                if clientPingIndex < activeQueue.count - 1 {
                    withAnimation { clientPingIndex += 1 }
                }
            }
        }
    }

    // MARK: - Searching Content

    private var searchingContent: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Constants.Colors.primary.opacity(0.08))
                    .frame(width: 140, height: 140)
                    .scaleEffect(pulseScale)
                    .opacity(pulseOpacity)
                    .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: pulseScale)

                Circle()
                    .fill(Constants.Colors.primary.opacity(0.15))
                    .frame(width: 100, height: 100)
                    .scaleEffect(pulseScale * 0.95)
                    .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true).delay(0.2), value: pulseScale)

                Circle()
                    .fill(Constants.Colors.primary)
                    .frame(width: 64, height: 64)

                Image(systemName: "hand.wave")
                    .font(.system(size: 24, weight: .regular))
                    .foregroundColor(.white)
            }
            .onAppear {
                pulseScale = 1.3
                pulseOpacity = 0.2
            }

            if let name = currentPingingName {
                VStack(spacing: 6) {
                    Text("Pinging \(name)...")
                        .font(.fraunces(22, weight: .semiBold))
                        .foregroundColor(Constants.Colors.textPrimary)

                    Text("Waiting for them to pick up")
                        .font(.inter(14, weight: .regular))
                        .foregroundColor(Constants.Colors.textSecondary)
                }
            } else {
                Text("Looking for someone...")
                    .font(.fraunces(22, weight: .semiBold))
                    .foregroundColor(Constants.Colors.textPrimary)
            }

            if !activeQueue.isEmpty {
                queueProgressList
            }
        }
    }

    // MARK: - Queue Progress List

    private var queueProgressList: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(activeQueue.enumerated()), id: \.element.id) { index, item in
                let userId = item.otherUser.userId
                let isCurrent = userId == currentPingingUserId
                let isPassed = {
                    if viewModel.passedUserIds.contains(userId) { return true }
                    if viewModel.currentlyPingingUserId == nil {
                        return index < clientPingIndex
                    }
                    return false
                }()

                HStack(spacing: 10) {
                    if isPassed {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(Constants.Colors.textTertiary)
                    } else if isCurrent {
                        PingingDot()
                    } else {
                        Circle()
                            .fill(Constants.Colors.textTertiary.opacity(0.3))
                            .frame(width: 8, height: 8)
                    }

                    Text(item.otherUser.name)
                        .font(.inter(14, weight: isCurrent ? .semiBold : .regular))
                        .foregroundColor(
                            isCurrent ? Constants.Colors.textPrimary :
                            isPassed ? Constants.Colors.textTertiary :
                            Constants.Colors.textSecondary
                        )

                    Spacer()

                    if isCurrent {
                        Text("15s")
                            .font(.inter(11, weight: .medium))
                            .foregroundColor(Constants.Colors.textTertiary)
                    }
                }
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Constants.Colors.border, lineWidth: 1)
        )
    }

    // MARK: - Queue Exhausted

    private var queueExhaustedContent: some View {
        VStack(spacing: 24) {
            Image(systemName: "moon.zzz")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(Constants.Colors.textTertiary)

            Text("No one's free right now")
                .font(.fraunces(22, weight: .semiBold))
                .foregroundColor(Constants.Colors.textPrimary)

            Text("We'll keep you live for a few more minutes in case someone pops in.")
                .font(.inter(15, weight: .regular))
                .foregroundColor(Constants.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Expired

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

private struct PingingDot: View {
    @State private var isAnimating = false

    var body: some View {
        Circle()
            .fill(Constants.Colors.primary)
            .frame(width: 10, height: 10)
            .scaleEffect(isAnimating ? 1.3 : 0.8)
            .opacity(isAnimating ? 1.0 : 0.5)
            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isAnimating)
            .onAppear { isAnimating = true }
    }
}

#Preview {
    NavigationStack {
        LiveWaitingView()
    }
}
