import SwiftUI

// MARK: - Design Constants

private extension Color {
    static let warmCoral = Color(red: 0.90, green: 0.45, blue: 0.35)
    static let warmCream = Color(red: 0.99, green: 0.97, blue: 0.94)
}

// MARK: - CallEndedView

struct CallEndedView: View {

    /// The name of the person the user caught up with.
    let otherPersonName: String

    /// Duration of the call in seconds.
    let durationSeconds: Int

    /// Called when the user taps "Nice." or after auto-dismiss.
    var onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.warmCream
                .ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer()

                // MARK: - Check Icon
                ZStack {
                    Circle()
                        .fill(Color.warmCoral.opacity(0.12))
                        .frame(width: 100, height: 100)

                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 52))
                        .foregroundColor(.warmCoral)
                }

                // MARK: - Summary Text
                VStack(spacing: 10) {
                    Text("You caught up with \(otherPersonName)")
                        .font(.fraunces(22, weight: .medium))
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)

                    Text("for \(formattedDuration)")
                        .font(.fraunces(20, weight: .medium))
                        .foregroundColor(.secondary)
                }

                Spacer()

                // MARK: - Dismiss Button
                Button {
                    onDismiss()
                } label: {
                    Text("Nice.")
                        .font(.fraunces(20, weight: .medium))
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.warmCoral)
                        .foregroundColor(.white)
                        .cornerRadius(14)
                }
                .padding(.bottom, 32)
            }
            .padding(.horizontal, 24)
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
