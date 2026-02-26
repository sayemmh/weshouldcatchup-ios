import SwiftUI

// MARK: - DisplayNameViewModel

/// ViewModel for the display name onboarding step.
final class DisplayNameViewModel: ObservableObject {

    @Published var displayName: String = ""
    @Published var isSaving: Bool = false
    @Published var errorMessage: String?

    var canSubmit: Bool {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && !isSaving
    }

    /// Saves the display name via API and calls the completion handler on success.
    @MainActor
    func save(completion: @escaping () -> Void) async {
        guard canSubmit else { return }
        isSaving = true
        errorMessage = nil

        // TODO: Call an API endpoint to save the display name (e.g., POST /set-display-name).
        // For now, we simulate a brief network call.
        do {
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5s simulated delay
            completion()
        } catch {
            errorMessage = error.localizedDescription
        }

        isSaving = false
    }
}

// MARK: - Design Constants

private extension Color {
    static let warmCoral = Color(red: 0.90, green: 0.45, blue: 0.35)
    static let warmCream = Color(red: 0.99, green: 0.97, blue: 0.94)
}

// MARK: - DisplayNameView

struct DisplayNameView: View {

    @StateObject private var viewModel = DisplayNameViewModel()

    /// Called when the user completes the display name step.
    var onComplete: () -> Void

    var body: some View {
        ZStack {
            Color.warmCream
                .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // MARK: - Headline
                headerSection

                // MARK: - Name Input
                nameInputSection

                // MARK: - Error
                errorSection

                Spacer()
                Spacer()

                // MARK: - Submit Button
                submitButton
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 32)
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.crop.circle.badge.plus")
                .font(.system(size: 52))
                .foregroundColor(.warmCoral)

            Text("What should we call you?")
                .font(.fraunces(28, weight: .semiBold))
                .fontWeight(.bold)
                .foregroundColor(.primary)

            Text("Just your first name is fine")
                .font(.inter(16))
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Name Input

    private var nameInputSection: some View {
        TextField("Your first name", text: $viewModel.displayName)
            .font(.fraunces(22, weight: .medium))
            .multilineTextAlignment(.center)
            .padding()
            .background(Color.white)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
            .textInputAutocapitalization(.words)
            .autocorrectionDisabled(true)
    }

    // MARK: - Error

    @ViewBuilder
    private var errorSection: some View {
        if let errorMessage = viewModel.errorMessage {
            Text(errorMessage)
                .font(.inter(12))
                .foregroundColor(.red)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Submit Button

    private var submitButton: some View {
        Button {
            Task {
                await viewModel.save {
                    onComplete()
                }
            }
        } label: {
            HStack(spacing: 8) {
                if viewModel.isSaving {
                    ProgressView()
                        .tint(.white)
                }
                Text(viewModel.isSaving ? "Saving..." : "Let's go")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(viewModel.canSubmit ? Color.warmCoral : Color.gray.opacity(0.3))
            .foregroundColor(.white)
            .cornerRadius(14)
        }
        .disabled(!viewModel.canSubmit)
    }
}

// MARK: - Preview

#Preview {
    DisplayNameView {
        print("Onboarding complete")
    }
}
