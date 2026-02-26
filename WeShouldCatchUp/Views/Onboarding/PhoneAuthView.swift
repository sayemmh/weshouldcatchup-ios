import SwiftUI

// MARK: - AuthViewModel

/// ViewModel for phone-based authentication.
/// Wraps AuthService and provides UI-friendly state for the phone auth flow.
final class AuthViewModel: ObservableObject {

    // MARK: - Published State

    @Published var phoneNumber: String = ""
    @Published var countryCode: String = "+1"
    @Published var verificationCode: String = ""
    @Published var codeSent: Bool = false
    @Published var isSendingCode: Bool = false
    @Published var isVerifying: Bool = false
    @Published var errorMessage: String?
    @Published var isAuthenticated: Bool = false

    // MARK: - Dependencies

    private let authService: AuthService

    init(authService: AuthService = AuthService()) {
        self.authService = authService
    }

    // MARK: - Computed Properties

    /// Full E.164 formatted phone number.
    var fullPhoneNumber: String {
        "\(countryCode)\(phoneNumber)"
    }

    var canSendCode: Bool {
        phoneNumber.count >= 10 && !isSendingCode
    }

    var canVerify: Bool {
        verificationCode.count == 6 && !isVerifying
    }

    // MARK: - Actions

    @MainActor
    func sendCode() async {
        isSendingCode = true
        errorMessage = nil
        do {
            try await authService.sendVerificationCode(phoneNumber: fullPhoneNumber)
            codeSent = true
        } catch {
            errorMessage = error.localizedDescription
        }
        isSendingCode = false
    }

    @MainActor
    func verify() async {
        isVerifying = true
        errorMessage = nil
        do {
            try await authService.verifyCode(code: verificationCode)
            isAuthenticated = true
        } catch {
            errorMessage = error.localizedDescription
        }
        isVerifying = false
    }
}

// MARK: - Design Constants

private extension Color {
    static let warmCoral = Color(red: 0.90, green: 0.45, blue: 0.35)
    static let warmCream = Color(red: 0.99, green: 0.97, blue: 0.94)
}

// MARK: - PhoneAuthView

struct PhoneAuthView: View {

    @StateObject private var viewModel = AuthViewModel()

    var body: some View {
        ZStack {
            Color.warmCream
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 32) {
                    headerSection
                    if viewModel.codeSent {
                        verificationSection
                    } else {
                        phoneInputSection
                    }
                    errorSection
                }
                .padding(.horizontal, 24)
                .padding(.top, 60)
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "phone.bubble.fill")
                .font(.system(size: 56))
                .foregroundColor(.warmCoral)

            Text("Let's get you set up")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.primary)

            Text("We'll send you a code to verify your number.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Phone Input

    private var phoneInputSection: some View {
        VStack(spacing: 20) {
            HStack(spacing: 12) {
                // Country code
                TextField("+1", text: $viewModel.countryCode)
                    .keyboardType(.phonePad)
                    .frame(width: 60)
                    .padding()
                    .background(Color.white)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )

                // Phone number
                TextField("Phone number", text: $viewModel.phoneNumber)
                    .keyboardType(.phonePad)
                    .padding()
                    .background(Color.white)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
            }

            Button {
                Task { await viewModel.sendCode() }
            } label: {
                HStack(spacing: 8) {
                    if viewModel.isSendingCode {
                        ProgressView()
                            .tint(.white)
                    }
                    Text(viewModel.isSendingCode ? "Sending..." : "Send Code")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(viewModel.canSendCode ? Color.warmCoral : Color.gray.opacity(0.3))
                .foregroundColor(.white)
                .cornerRadius(14)
            }
            .disabled(!viewModel.canSendCode)
        }
    }

    // MARK: - Verification Code Input

    private var verificationSection: some View {
        VStack(spacing: 20) {
            Text("Enter the 6-digit code we sent to \(viewModel.fullPhoneNumber)")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            TextField("000000", text: $viewModel.verificationCode)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .font(.title2.monospacedDigit())
                .padding()
                .background(Color.white)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
                .onChange(of: viewModel.verificationCode) { newValue in
                    // Limit to 6 digits
                    if newValue.count > 6 {
                        viewModel.verificationCode = String(newValue.prefix(6))
                    }
                }

            Button {
                Task { await viewModel.verify() }
            } label: {
                HStack(spacing: 8) {
                    if viewModel.isVerifying {
                        ProgressView()
                            .tint(.white)
                    }
                    Text(viewModel.isVerifying ? "Verifying..." : "Verify")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(viewModel.canVerify ? Color.warmCoral : Color.gray.opacity(0.3))
                .foregroundColor(.white)
                .cornerRadius(14)
            }
            .disabled(!viewModel.canVerify)

            Button {
                viewModel.codeSent = false
                viewModel.verificationCode = ""
                viewModel.errorMessage = nil
            } label: {
                Text("Use a different number")
                    .font(.caption)
                    .foregroundColor(.warmCoral)
            }
        }
    }

    // MARK: - Error Section

    @ViewBuilder
    private var errorSection: some View {
        if let errorMessage = viewModel.errorMessage {
            Text(errorMessage)
                .font(.caption)
                .foregroundColor(.red)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }
}

// MARK: - Preview

#Preview {
    PhoneAuthView()
}
