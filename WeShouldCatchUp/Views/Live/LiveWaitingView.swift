import SwiftUI

// MARK: - Design Constants

private extension Color {
    static let warmCoral = Color(red: 0.90, green: 0.45, blue: 0.35)
    static let warmCream = Color(red: 0.99, green: 0.97, blue: 0.94)
}

// MARK: - LiveWaitingView

struct LiveWaitingView: View {

    @StateObject private var viewModel = LiveViewModel()
    @Environment(\.dismiss) private var dismiss

    @State private var pulseScale: CGFloat = 1.0
    @State private var pulseOpacity: Double = 0.6
    @State private var isCancelling: Bool = false

    var body: some View {
        ZStack {
            Color.warmCream
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
    }

    // MARK: - Searching Content

    private var searchingContent: some View {
        VStack(spacing: 24) {
            // Pulsing circle animation
            ZStack {
                Circle()
                    .fill(Color.warmCoral.opacity(0.1))
                    .frame(width: 160, height: 160)
                    .scaleEffect(pulseScale)
                    .opacity(pulseOpacity)
                    .animation(
                        .easeInOut(duration: 1.5)
                        .repeatForever(autoreverses: true),
                        value: pulseScale
                    )

                Circle()
                    .fill(Color.warmCoral.opacity(0.2))
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
                    .fill(Color.warmCoral)
                    .frame(width: 70, height: 70)

                Image(systemName: "hand.wave.fill")
                    .font(.title)
                    .foregroundColor(.white)
            }
            .onAppear {
                pulseScale = 1.3
                pulseOpacity = 0.2
            }

            Text("Finding someone to catch up with...")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)

            Text("Sit tight. We're checking your queue.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Queue Exhausted Content

    private var queueExhaustedContent: some View {
        VStack(spacing: 24) {
            Image(systemName: "moon.zzz.fill")
                .font(.system(size: 56))
                .foregroundColor(.secondary.opacity(0.5))

            Text("No one's free right now.")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)

            Text("We'll keep you live for a few more minutes in case someone pops in.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Expired Content

    private var expiredContent: some View {
        VStack(spacing: 24) {
            Image(systemName: "clock.badge.xmark")
                .font(.system(size: 56))
                .foregroundColor(.secondary.opacity(0.5))

            Text("No luck this time.")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.primary)

            Text("Try again later!")
                .font(.body)
                .foregroundColor(.secondary)

            Button {
                dismiss()
            } label: {
                Text("Back to Home")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.warmCoral)
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
            .foregroundColor(.secondary)
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
