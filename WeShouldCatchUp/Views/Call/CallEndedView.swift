import SwiftUI

// MARK: - CallEndedView

struct CallEndedView: View {

    /// The name of the person the user caught up with.
    let otherPersonName: String

    /// Duration of the call in seconds.
    let durationSeconds: Int

    /// Called when the user taps "Nice." or after auto-dismiss.
    var onDismiss: () -> Void

    @State private var appeared = false

    var body: some View {
        ZStack {
            Constants.Colors.canvas
                .ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer()

                // MARK: - Check Icon
                ZStack {
                    Circle()
                        .fill(Constants.Colors.accent.opacity(0.10))
                        .frame(width: 88, height: 88)
                    Image(systemName: "checkmark")
                        .font(.system(size: 40, weight: .medium))
                        .foregroundColor(Constants.Colors.accent)
                }
                .scaleEffect(appeared ? 1 : 0.6)
                .opacity(appeared ? 1 : 0)

                // MARK: - Summary Text
                VStack(spacing: 8) {
                    Text("You caught up with \(otherPersonName)")
                        .font(.fraunces(22, weight: .medium))
                        .foregroundColor(Constants.Colors.textPrimary)
                        .multilineTextAlignment(.center)

                    Text("for \(formattedDuration)")
                        .font(.inter(17, weight: .regular))
                        .foregroundColor(Constants.Colors.textSecondary)
                }
                .opacity(appeared ? 1 : 0)

                Spacer()

                PrimaryButton(title: "Nice.") { onDismiss() }
                    .padding(.bottom, 32)
            }
            .padding(.horizontal, Space.xxl)
        }
        .onAppear {
            Haptics.success()
            withAnimation(Motion.spring) { appeared = true }
        }
        .task {
            // Auto-dismiss after 5 seconds.
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            onDismiss()
        }
    }

    // MARK: - Duration Formatting

    /// Formats the duration in a friendly, human-readable way.
    private var formattedDuration: String {
        let minutes = durationSeconds / 60
        let seconds = durationSeconds % 60

        if minutes == 0 {
            return "\(seconds) sec"
        } else if seconds == 0 {
            return "\(minutes) minute\(minutes == 1 ? "" : "s")"
        } else {
            return "\(minutes) min \(seconds) sec"
        }
    }
}

// MARK: - Preview

#Preview("Short call") {
    CallEndedView(
        otherPersonName: "Jordan",
        durationSeconds: 45,
        onDismiss: { print("Dismissed") }
    )
}

#Preview("Long call") {
    CallEndedView(
        otherPersonName: "Alex",
        durationSeconds: 725,
        onDismiss: { print("Dismissed") }
    )
}
