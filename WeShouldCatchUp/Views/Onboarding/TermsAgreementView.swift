import SwiftUI

struct TermsAgreementView: View {

    var onAccepted: () -> Void

    var body: some View {
        ZStack {
            Constants.Colors.background
                .ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer()

                Image(systemName: "doc.text")
                    .font(.system(size: 48, weight: .light))
                    .foregroundColor(Constants.Colors.primary)

                VStack(spacing: 12) {
                    Text("Before we start")
                        .font(.fraunces(28, weight: .semiBold))
                        .foregroundColor(Constants.Colors.textPrimary)

                    Text("By using We Should Catch Up, you agree to our Terms of Service and Privacy Policy.")
                        .font(.inter(15, weight: .regular))
                        .foregroundColor(Constants.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: 12) {
                    bulletPoint("Be respectful — no harassment, threats, or abuse")
                    bulletPoint("No objectionable or inappropriate content")
                    bulletPoint("Violations result in immediate account removal")
                    bulletPoint("Report concerns: support@weshouldcatchup.app")
                }
                .padding(20)
                .background(Color.white)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Constants.Colors.border, lineWidth: 1)
                )

                HStack(spacing: 16) {
                    Link(destination: URL(string: "https://weshouldcatchup.app/terms")!) {
                        Text("Terms")
                            .font(.inter(13, weight: .medium))
                            .foregroundColor(Constants.Colors.primary)
                    }
                    Link(destination: URL(string: "https://weshouldcatchup.app/privacy")!) {
                        Text("Privacy")
                            .font(.inter(13, weight: .medium))
                            .foregroundColor(Constants.Colors.primary)
                    }
                }

                Spacer()

                Button {
                    onAccepted()
                } label: {
                    Text("I Agree")
                        .font(.inter(15, weight: .semiBold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Constants.Colors.primary)
                        .foregroundColor(.white)
                        .cornerRadius(28)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 32)
        }
    }

    private func bulletPoint(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("•")
                .font(.inter(14, weight: .medium))
                .foregroundColor(Constants.Colors.primary)
            Text(text)
                .font(.inter(14, weight: .regular))
                .foregroundColor(Constants.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview {
    TermsAgreementView {
        print("Accepted")
    }
}
