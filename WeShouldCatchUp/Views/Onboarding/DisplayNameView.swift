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

        do {
            try await APIService.shared.updateDisplayName(displayName.trimmingCharacters(in: .whitespacesAndNewlines))
            completion()
        } catch {
            errorMessage = error.localizedDescription
        }

        isSaving = false
    }
}

// MARK: - DisplayNameView

struct DisplayNameView: View {

    @StateObject private var viewModel = DisplayNameViewModel()

    /// Called when the user completes the display name step.
    var onComplete: () -> Void

    var body: some View {
        ZStack {
            Constants.Colors.background
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
            Image(systemName: "person")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(Constants.Colors.primary)

            Text("What should we call you?")
                .font(.fraunces(28, weight: .semiBold))
                .foregroundColor(Constants.Colors.textPrimary)

            Text("Just your first name is fine")
                .font(.inter(15, weight: .regular))
                .foregroundColor(Constants.Colors.textSecondary)
        }
    }

    // MARK: - Name Input

    private var nameInputSection: some View {
        TextField("", text: $viewModel.displayName, prompt: Text("Your first name").foregroundColor(Constants.Colors.textTertiary))
            .font(.fraunces(22, weight: .medium))
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
    }

    // MARK: - Error

    @ViewBuilder
    private var errorSection: some View {
        if let errorMessage = viewModel.errorMessage {
            Text(errorMessage)
                .font(.inter(13, weight: .regular))
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
                    .font(.inter(15, weight: .semiBold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(viewModel.canSubmit ? Constants.Colors.primary : Color.gray.opacity(0.3))
            .foregroundColor(.white)
            .cornerRadius(28)
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
