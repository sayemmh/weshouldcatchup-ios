import SwiftUI

// MARK: - PhoneAuthView

struct PhoneAuthView: View {

    @ObservedObject var viewModel: AuthViewModel

    var body: some View {
        ZStack {
            Constants.Colors.background
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 32) {
                    headerSection
                    if viewModel.isCodeSent {
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
                .foregroundColor(Constants.Colors.primary)

            Text("Let's get you set up")
                .font(.fraunces(28, weight: .semiBold))
                .fontWeight(.bold)
                .foregroundColor(Constants.Colors.textPrimary)

            Text("We'll send you a code to verify your number.")
                .font(.inter(16))
                .foregroundColor(Constants.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Phone Input

    private var phoneInputSection: some View {
        VStack(spacing: 20) {
            // Phone number (includes country code, e.g. "+1")
            TextField("Phone number", text: $viewModel.phoneNumber)
                .keyboardType(.phonePad)
                .foregroundColor(Constants.Colors.textPrimary)
                .font(.inter(18))
                .padding()
                .background(Color.white)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )

            Button {
                Task { await viewModel.sendVerificationCode() }
            } label: {
                HStack(spacing: 8) {
                    if viewModel.isLoading {
                        ProgressView()
                            .tint(.white)
                    }
                    Text(viewModel.isLoading ? "Sending..." : "Send Code")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(!viewModel.isLoading ? Constants.Colors.primary : Color.gray.opacity(0.3))
                .foregroundColor(.white)
                .cornerRadius(14)
            }
            .disabled(viewModel.isLoading)
        }
    }

    // MARK: - Verification Code Input

    private var verificationSection: some View {
        VStack(spacing: 20) {
            Text("Enter the 6-digit code we sent to \(viewModel.phoneNumber)")
                .font(.inter(16))
                .foregroundColor(Constants.Colors.textSecondary)
                .multilineTextAlignment(.center)

            TextField("000000", text: $viewModel.verificationCode)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .font(.title2.monospacedDigit())
                .foregroundColor(Constants.Colors.textPrimary)
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
                Task { await viewModel.verifyCode() }
            } label: {
                HStack(spacing: 8) {
                    if viewModel.isLoading {
                        ProgressView()
                            .tint(.white)
                    }
                    Text(viewModel.isLoading ? "Verifying..." : "Verify")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(!viewModel.isLoading ? Constants.Colors.primary : Color.gray.opacity(0.3))
                .foregroundColor(.white)
                .cornerRadius(14)
            }
            .disabled(viewModel.isLoading)

            Button {
                viewModel.isCodeSent = false
                viewModel.verificationCode = ""
                viewModel.errorMessage = nil
            } label: {
                Text("Use a different number")
                    .font(.inter(12))
                    .foregroundColor(Constants.Colors.primary)
            }
        }
    }

    // MARK: - Error Section

    @ViewBuilder
    private var errorSection: some View {
        if let errorMessage = viewModel.errorMessage {
            Text(errorMessage)
                .font(.inter(12))
                .foregroundColor(.red)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }
}

// MARK: - Preview

#Preview {
    PhoneAuthView(viewModel: AuthViewModel())
}
