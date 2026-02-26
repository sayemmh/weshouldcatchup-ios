import Foundation
import Combine

/// Manages the onboarding and authentication flow.
@MainActor
class AuthViewModel: ObservableObject {

    // MARK: - Published State

    @Published var phoneNumber: String = "+1"
    @Published var verificationCode: String = ""
    @Published var displayName: String = ""

    @Published var isCodeSent: Bool = false
    @Published var isLoading: Bool = false
    @Published var isAuthenticated: Bool = false
    @Published var hasCompletedOnboarding: Bool = false
    @Published var errorMessage: String?

    // MARK: - Dependencies

    private let authService = AuthService.shared

    // MARK: - Onboarding Step Tracking

    enum OnboardingStep {
        case phoneEntry
        case codeVerification
        case notificationPermission
        case displayNameEntry
        case complete
    }

    @Published var currentStep: OnboardingStep = .phoneEntry

    // MARK: - Phone Auth

    func sendVerificationCode() async {
        guard phoneNumber.isValidPhoneNumber else {
            errorMessage = "Please enter a valid phone number."
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            try await authService.sendVerificationCode(phoneNumber: phoneNumber)
            isCodeSent = true
            currentStep = .codeVerification
        } catch {
            errorMessage = "Couldn't send verification code. Please try again."
        }

        isLoading = false
    }

    func verifyCode() async {
        guard verificationCode.count == 6 else {
            errorMessage = "Please enter the 6-digit code."
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            try await authService.verifyCode(code: verificationCode)
            isAuthenticated = true
            currentStep = .notificationPermission
        } catch {
            errorMessage = "Invalid code. Please try again."
        }

        isLoading = false
    }

    // MARK: - Notifications

    func notificationsEnabled() {
        currentStep = .displayNameEntry
    }

    // MARK: - Display Name

    func saveDisplayName() async {
        guard displayName.isValidDisplayName else {
            errorMessage = "Please enter your first name."
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            try await APIService.shared.updateDisplayName(displayName.trimmingCharacters(in: .whitespacesAndNewlines))
            hasCompletedOnboarding = true
            currentStep = .complete
        } catch {
            errorMessage = "Couldn't save your name. Please try again."
        }

        isLoading = false
    }
}
