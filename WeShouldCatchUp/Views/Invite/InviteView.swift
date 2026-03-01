import SwiftUI
import UIKit

// MARK: - InviteView

struct InviteView: View {

    @Environment(\.dismiss) private var dismiss

    @State private var isCreatingLink: Bool = false
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

                    // MARK: - Illustration
                    illustrationSection

                    // MARK: - Headline
                    textSection

                    // MARK: - Invite Button
                    inviteButton

                    // MARK: - Error
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
                        dismiss()
                    }
                    .foregroundColor(Constants.Colors.primary)
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let link = inviteLink {
                    ActivityViewController(
                        activityItems: [shareMessage(link: link)]
                    )
                }
            }
        }
    }

    // MARK: - Illustration

    private var illustrationSection: some View {
        ZStack {
            Circle()
                .fill(Constants.Colors.primary.opacity(0.12))
                .frame(width: 120, height: 120)

            Image(systemName: "paperplane.fill")
                .font(.system(size: 48))
                .foregroundColor(Constants.Colors.primary)
        }
    }

    // MARK: - Text

    private var textSection: some View {
        VStack(spacing: 12) {
            Text("Invite someone to catch up")
                .font(.fraunces(22, weight: .medium))
                .fontWeight(.bold)
                .foregroundColor(Constants.Colors.textPrimary)
                .multilineTextAlignment(.center)

            Text("Send them a link. When you both have a free moment, the app connects you.")
                .font(.inter(16))
                .foregroundColor(Constants.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Invite Button

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
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(isCreatingLink ? Color.gray.opacity(0.3) : Constants.Colors.primary)
            .foregroundColor(.white)
            .cornerRadius(14)
        }
        .disabled(isCreatingLink)
    }

    // MARK: - Error

    @ViewBuilder
    private var errorSection: some View {
        if let errorMessage = errorMessage {
            Text(errorMessage)
                .font(.inter(12))
                .foregroundColor(.red)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }

    // MARK: - Actions

    @MainActor
    private func createAndShare() async {
        isCreatingLink = true
        errorMessage = nil
        do {
            let response = try await api.createCatchup()
            inviteLink = response.inviteLink
            showShareSheet = true
        } catch {
            errorMessage = error.localizedDescription
        }
        isCreatingLink = false
    }

    // MARK: - Share Message

    private func shareMessage(link: String) -> String {
        "Hey, we should catch up! Tap this link and we'll talk whenever we're both free: \(link)"
    }
}

// MARK: - UIActivityViewController Wrapper

/// Wraps UIActivityViewController for use in SwiftUI's .sheet modifier.
struct ActivityViewController: UIViewControllerRepresentable {

    let activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: applicationActivities
        )
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Preview

#Preview {
    InviteView()
}
