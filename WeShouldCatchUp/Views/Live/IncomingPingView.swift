import SwiftUI

// MARK: - IncomingPingView

struct IncomingPingView: View {

    /// The name of the person who is free to catch up.
    let callerName: String

    /// The catchup ID for accepting the ping.
    let catchupId: String

    /// The call ID for accepting the ping.
    let callId: String

    /// Called when the user taps "Join".
    var onAccept: () -> Void

    /// Called when the user taps "Not now" or the countdown expires.
    var onDecline: () -> Void

    // MARK: - State

    @State private var secondsRemaining: Int = 60
    @State private var timerActive: Bool = true
    @State private var waveOffset: CGFloat = 0

    /// Countdown progress from 1.0 (full) to 0.0 (expired).
    private var countdownProgress: Double {
        Double(secondsRemaining) / 60.0
    }

    var body: some View {
        ZStack {
            Constants.Colors.background
                .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // MARK: - Caller Info
                callerSection

                // MARK: - Countdown Ring
                countdownRing

                Spacer()

                // MARK: - Action Buttons
                actionButtons
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 32)
        }
        .task {
            await startCountdown()
        }
    }

    // MARK: - Caller Section

    private var callerSection: some View {
        VStack(spacing: 16) {
            // Avatar
            ZStack {
                Circle()
                    .fill(Constants.Colors.primary.opacity(0.15))
                    .frame(width: 80, height: 80)

                Text(String(callerName.prefix(1)).uppercased())
                    .font(.fraunces(28, weight: .semiBold))
                    .fontWeight(.bold)
                    .foregroundColor(Constants.Colors.primary)
            }

            HStack(spacing: 4) {
                Text(callerName)
                    .font(.fraunces(28, weight: .semiBold))
                    .fontWeight(.bold)
                    .foregroundColor(Constants.Colors.textPrimary)

                Text("is free to catch up")
                    .font(.fraunces(22, weight: .medium))
                    .foregroundColor(Constants.Colors.textPrimary)
            }
            .multilineTextAlignment(.center)

            Text("\u{1F44B}")
                .font(.system(size: 40))
                .offset(x: waveOffset)
                .animation(
                    .easeInOut(duration: 0.4)
                    .repeatCount(6, autoreverses: true),
                    value: waveOffset
                )
                .onAppear {
                    waveOffset = 10
                }
        }
    }

    // MARK: - Countdown Ring

    private var countdownRing: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(Color.gray.opacity(0.15), lineWidth: 6)
                .frame(width: 80, height: 80)

            // Progress ring
            Circle()
                .trim(from: 0, to: countdownProgress)
                .stroke(
                    countdownProgress > 0.3 ? Constants.Colors.primary : Color.red,
                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                )
                .frame(width: 80, height: 80)
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: secondsRemaining)

            // Timer text
            Text("\(secondsRemaining)s")
                .font(.title2.monospacedDigit())
                .fontWeight(.medium)
                .foregroundColor(countdownProgress > 0.3 ? Constants.Colors.textPrimary : .red)
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 14) {
            // Join button
            Button {
                timerActive = false
                onAccept()
            } label: {
                Text("Join")
                    .font(.fraunces(20, weight: .medium))
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Constants.Colors.primary)
                    .foregroundColor(.white)
                    .cornerRadius(16)
                    .shadow(color: Constants.Colors.primary.opacity(0.3), radius: 10, x: 0, y: 4)
            }

            // Not now button
            Button {
                timerActive = false
                onDecline()
            } label: {
                Text("Not now")
                    .font(.inter(16))
                    .foregroundColor(Constants.Colors.textSecondary)
                    .padding(.vertical, 10)
            }
        }
        .padding(.bottom, 16)
    }

    // MARK: - Countdown Timer

    private func startCountdown() async {
        while timerActive && secondsRemaining > 0 {
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            if timerActive {
                secondsRemaining -= 1
            }
        }

        // If countdown reaches zero, auto-decline.
        if secondsRemaining <= 0 && timerActive {
            timerActive = false
            onDecline()
        }
    }
}

// MARK: - Preview

#Preview {
    IncomingPingView(
        callerName: "Jordan",
        catchupId: "preview-catchup-1",
        callId: "preview-call-1",
        onAccept: { print("Accepted") },
        onDecline: { print("Declined") }
    )
}
