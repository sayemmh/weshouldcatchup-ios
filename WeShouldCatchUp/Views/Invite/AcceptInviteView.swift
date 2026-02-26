import SwiftUI

// MARK: - Design Constants

private extension Color {
    static let warmCoral = Color(red: 0.90, green: 0.45, blue: 0.35)
    static let warmCream = Color(red: 0.99, green: 0.97, blue: 0.94)
}

// MARK: - AcceptInviteView

struct AcceptInviteView: View {

    /// The catch-up ID from the deep link.
    let catchupId: String

    /// The name of the person who sent the invite.
    let inviterName: String

    /// Called when the invite is accepted and the user should navigate to the main screen.
    var onAccepted: () -> Void

    /// Called when the user declines the invite.
    var onDeclined: () -> Void

    // MARK: - State

    @State private var isAccepting: Bool = false
    @State private var showSuccess: Bool = false
    @State private var errorMessage: String?

    private let api = APIService.shared

    var body: some View {
        ZStack {
            Color.warmCream
                .ignoresSafeArea()

            if showSuccess {
                successContent
            } else {
                inviteContent
            }
        }
    }

    // MARK: - Invite Content

    private var inviteContent: some View {
        VStack(spacing: 32) {
            Spacer()

            // MARK: - Illustration
            ZStack {
                Circle()
                    .fill(Color.warmCoral.opacity(0.12))
                    .frame(width: 110, height: 110)

                Image(systemName: "person.crop.circle.badge.plus")
                    .font(.system(size: 50))
                    .foregroundColor(.warmCoral)
            }

            // MARK: - Headline
            VStack(spacing: 12) {
                Text("\(inviterName) wants to catch up with you")
                    .font(.fraunces(22, weight: .medium))
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)

                Text("whenever you're both free")
                    .font(.inter(16))
                    .foregroundColor(.secondary)
            }

            Spacer()

            // MARK: - Error
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .font(.inter(12))
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }

            // MARK: - Action Buttons
            VStack(spacing: 14) {
                // Accept
                Button {
                    Task { await acceptInvite() }
                } label: {
                    HStack(spacing: 8) {
                        if isAccepting {
                            ProgressView()
                                .tint(.white)
                        }
                        Text(isAccepting ? "Joining..." : "I'm down")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isAccepting ? Color.gray.opacity(0.3) : Color.warmCoral)
                    .foregroundColor(.white)
                    .cornerRadius(14)
                }
                .disabled(isAccepting)

                // Decline
                Button {
                    onDeclined()
                } label: {
                    Text("Nah")
                        .font(.inter(16))
                        .foregroundColor(.secondary)
                        .padding(.vertical, 8)
                }
                .disabled(isAccepting)
            }
            .padding(.bottom, 32)
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Success Content

    private var successContent: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.warmCoral.opacity(0.12))
                    .frame(width: 100, height: 100)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 52))
                    .foregroundColor(.warmCoral)
            }

            Text("Added to your queue!")
                .font(.fraunces(22, weight: .medium))
                .fontWeight(.bold)
                .foregroundColor(.primary)

            Text("Next time either of you taps \"I'm Free,\" we'll connect you.")
                .font(.inter(16))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .padding(.horizontal, 24)
        .task {
            // Navigate to main after a brief delay.
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            onAccepted()
        }
    }

    // MARK: - Actions

    @MainActor
    private func acceptInvite() async {
        isAccepting = true
        errorMessage = nil
        do {
            _ = try await api.acceptCatchup(catchupId: catchupId)
            withAnimation {
                showSuccess = true
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isAccepting = false
    }
}

// MARK: - Preview

#Preview {
    AcceptInviteView(
        catchupId: "preview-catchup-1",
        inviterName: "Jordan",
        onAccepted: { print("Accepted and navigating") },
        onDeclined: { print("Declined") }
    )
}
