import SwiftUI

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
    @State private var successAppeared: Bool = false
    @State private var errorMessage: String?
    @State private var resolvedInviterName: String?

    private let api = APIService.shared

    /// The best name we have for the inviter: server-resolved, else what the caller passed.
    private var displayInviterName: String {
        resolvedInviterName ?? inviterName
    }

    var body: some View {
        ZStack {
            Constants.Colors.background
                .ignoresSafeArea()

            if showSuccess {
                successContent
            } else {
                inviteContent
            }
        }
        .task {
            if let info = try? await api.fetchInviteInfo(catchupId: catchupId) {
                resolvedInviterName = info.inviterName
            }
        }
    }

    // MARK: - Invite Content

    private var inviteContent: some View {
        VStack(spacing: 32) {
            Spacer()

            // MARK: - Illustration
            Image(systemName: "person.badge.plus")
                .font(.system(size: 44, weight: .light))
                .foregroundColor(Constants.Colors.primary)

            // MARK: - Headline
            VStack(spacing: 12) {
                Text("\(displayInviterName) wants to catch up with you")
                    .font(.fraunces(22, weight: .medium))
                    .foregroundColor(Constants.Colors.textPrimary)
                    .multilineTextAlignment(.center)

                Text("whenever you're both free")
                    .font(.inter(15, weight: .regular))
                    .foregroundColor(Constants.Colors.textSecondary)
            }

            Spacer()

            // MARK: - Error
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .font(.inter(13, weight: .regular))
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }

            // MARK: - Action Buttons
            VStack(spacing: Space.md) {
                PrimaryButton(title: isAccepting ? "Joining…" : "I'm down", isLoading: isAccepting) {
                    Task { await acceptInvite() }
                }
                TextButton(title: "Nah") { onDeclined() }
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
                Circle().fill(Constants.Colors.accent.opacity(0.10)).frame(width: 88, height: 88)
                Image(systemName: "checkmark")
                    .font(.system(size: 40, weight: .medium))
                    .foregroundColor(Constants.Colors.accent)
            }
            .scaleEffect(successAppeared ? 1 : 0.6)
            .opacity(successAppeared ? 1 : 0)

            Text("Added to your queue!")
                .font(.fraunces(22, weight: .medium))
                .foregroundColor(Constants.Colors.textPrimary)

            Text("Next time either of you taps \"I'm Free,\" we'll connect you.")
                .font(.inter(15, weight: .regular))
                .foregroundColor(Constants.Colors.textSecondary)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .padding(.horizontal, 24)
        .onAppear {
            Haptics.success()
            withAnimation(Motion.spring) { successAppeared = true }
        }
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
