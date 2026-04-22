import SwiftUI
import UIKit

struct InviteView: View {

    @Environment(\.dismiss) private var dismiss

    @State private var friendName: String = ""
    @State private var isCreatingLink: Bool = false
    @State private var pendingCatchupId: String?
    @State private var inviteLink: String?
    @State private var errorMessage: String?
    @State private var showShareSheet: Bool = false

    private let api = APIService.shared

    var body: some View {
        NavigationStack {
            ZStack {
                Constants.Colors.background
                    .ignoresSafeArea()

                VStack(spacing: 32) {
                    Spacer()

                    Image(systemName: "paperplane")
                        .font(.system(size: 44, weight: .light))
                        .foregroundColor(Constants.Colors.primary)

                    textSection

                    TextField("", text: $friendName, prompt: Text("Their first name").foregroundColor(Constants.Colors.textTertiary))
                        .font(.fraunces(20, weight: .medium))
                        .foregroundColor(Constants.Colors.textPrimary)
                        .multilineTextAlignment(.center)
                        .padding()
                        .background(Color.white)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Constants.Colors.border, lineWidth: 1)
                        )
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled(true)

                    inviteButton
                    errorSection

                    Spacer()
                }
                .padding(.horizontal, 24)
            }
            .navigationTitle("Invite")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        cleanupAndDismiss()
                    }
                    .font(.inter(15, weight: .medium))
                    .foregroundColor(Constants.Colors.textSecondary)
                }
            }
            .sheet(isPresented: $showShareSheet, onDismiss: {
                // If share sheet closed without the invite being accepted elsewhere,
                // the catchup stays pending — that's fine, invite was shown to the user.
                // But if they never actually shared it, we should clean up.
                // We can't reliably detect if they shared, so we keep it.
                // The real cleanup happens if user taps Close without sharing.
            }) {
                if let link = inviteLink {
                    ActivityViewController(
                        activityItems: [shareMessage(link: link)],
                        onComplete: { completed in
                            if !completed, let id = pendingCatchupId {
                                Task {
                                    try? await api.removeCatchup(catchupId: id)
                                    pendingCatchupId = nil
                                }
                            }
                        }
                    )
                }
            }
        }
    }

    private var textSection: some View {
        VStack(spacing: 12) {
            Text("Invite someone to catch up")
                .font(.fraunces(22, weight: .medium))
                .foregroundColor(Constants.Colors.textPrimary)
                .multilineTextAlignment(.center)

            Text("Send them a link. When you both have a free moment, the app connects you.")
                .font(.inter(15, weight: .regular))
                .foregroundColor(Constants.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var inviteButton: some View {
        Button {
            Task { await createAndShare() }
        } label: {
            HStack(spacing: 8) {
                if isCreatingLink {
                    ProgressView()
                        .tint(.white)
                }
                Text(isCreatingLink ? "Creating link..." : "Share Invite Link")
                    .font(.inter(15, weight: .semiBold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Constants.Colors.primary.opacity(
                isCreatingLink || friendName.trimmingCharacters(in: .whitespaces).isEmpty ? 0.4 : 1.0
            ))
            .foregroundColor(.white)
            .cornerRadius(28)
        }
        .disabled(isCreatingLink || friendName.trimmingCharacters(in: .whitespaces).isEmpty)
    }

    @ViewBuilder
    private var errorSection: some View {
        if let errorMessage = errorMessage {
            Text(errorMessage)
                .font(.inter(13, weight: .regular))
                .foregroundColor(.red)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }

    @MainActor
    private func createAndShare() async {
        isCreatingLink = true
        errorMessage = nil
        do {
            let response = try await api.createCatchup(invitedName: friendName.trimmingCharacters(in: .whitespaces))
            pendingCatchupId = response.catchupId
            inviteLink = response.inviteLink
            showShareSheet = true
        } catch {
            errorMessage = error.localizedDescription
        }
        isCreatingLink = false
    }

    private func cleanupAndDismiss() {
        if let id = pendingCatchupId {
            Task {
                try? await api.removeCatchup(catchupId: id)
            }
        }
        dismiss()
    }

    private func shareMessage(link: String) -> String {
        "Hey, we should catch up! Tap this link and we'll talk whenever we're both free: \(link)"
    }
}

struct ActivityViewController: UIViewControllerRepresentable {

    let activityItems: [Any]
    var onComplete: ((Bool) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(onComplete: onComplete)
    }

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let vc = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )
        vc.completionWithItemsHandler = { _, completed, _, _ in
            context.coordinator.onComplete?(completed)
        }
        return vc
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}

    class Coordinator {
        let onComplete: ((Bool) -> Void)?
        init(onComplete: ((Bool) -> Void)?) {
            self.onComplete = onComplete
        }
    }
}

#Preview {
    InviteView()
}
