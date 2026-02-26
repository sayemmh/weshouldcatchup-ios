import SwiftUI
import UIKit

// MARK: - Design Constants

private extension Color {
    static let warmCoral = Color(red: 0.90, green: 0.45, blue: 0.35)
    static let warmCream = Color(red: 0.99, green: 0.97, blue: 0.94)
}

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
                Color.warmCream
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
                    .foregroundColor(.warmCoral)
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
                .fill(Color.warmCoral.opacity(0.12))
                .frame(width: 120, height: 120)

            Image(systemName: "paperplane.fill")
                .font(.system(size: 48))
                .foregroundColor(.warmCoral)
        }
    }

    // MARK: - Text

    private var textSection: some View {
        VStack(spacing: 12) {
            Text("Invite someone to catch up")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)

            Text("Send them a link. When you both have a free moment, the app connects you.")
                .font(.body)
                .foregroundColor(.secondary)
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
            .background(isCreatingLink ? Color.gray.opacity(0.3) : Color.warmCoral)
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
                .font(.caption)
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
