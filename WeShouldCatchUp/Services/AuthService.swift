import Foundation
import FirebaseAuth
import Combine

/// Firebase Auth wrapper handling phone number authentication.
final class AuthService: ObservableObject {

    // MARK: - Published Properties

    @Published var isAuthenticated: Bool = false
    @Published var currentUserId: String?
    @Published var verificationId: String?

    // MARK: - Private Properties

    private var authStateHandle: AuthStateDidChangeListenerHandle?

    // MARK: - Init

    init() {
        listenForAuthChanges()
    }

    deinit {
        if let handle = authStateHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }

    // MARK: - Auth State Listener

    /// Listens for Firebase Auth state changes and updates published properties accordingly.
    private func listenForAuthChanges() {
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            DispatchQueue.main.async {
                self?.isAuthenticated = user != nil
                self?.currentUserId = user?.uid
            }
        }
    }

    // MARK: - Phone Auth

    /// Sends a verification code to the provided phone number via Firebase Phone Auth.
    /// - Parameter phoneNumber: The phone number in E.164 format (e.g. "+14155551234").
    func sendVerificationCode(phoneNumber: String) async throws {
        let id = try await PhoneAuthProvider.provider().verifyPhoneNumber(
            phoneNumber,
            uiDelegate: nil
        )
        await MainActor.run {
            self.verificationId = id
        }
    }

    /// Verifies the SMS code the user entered and signs them in.
    /// - Parameter code: The 6-digit verification code from SMS.
    func verifyCode(code: String) async throws {
        guard let verificationId = verificationId else {
            throw AuthServiceError.missingVerificationId
        }

        let credential = PhoneAuthProvider.provider().credential(
            withVerificationID: verificationId,
            verificationCode: code
        )

        let result = try await Auth.auth().signIn(with: credential)

        await MainActor.run {
            self.isAuthenticated = true
            self.currentUserId = result.user.uid
            self.verificationId = nil
        }
    }

    /// Signs the current user out of Firebase Auth.
    func signOut() throws {
        try Auth.auth().signOut()
        DispatchQueue.main.async {
            self.isAuthenticated = false
            self.currentUserId = nil
            self.verificationId = nil
        }
    }

    // MARK: - Token Helper

    /// Returns the current user's Firebase ID token for authenticating backend requests.
    func getIDToken() async throws -> String {
        guard let user = Auth.auth().currentUser else {
            throw AuthServiceError.notAuthenticated
        }
        let token = try await user.getIDToken()
        return token
    }
}

// MARK: - Errors

enum AuthServiceError: LocalizedError {
    case missingVerificationId
    case notAuthenticated

    var errorDescription: String? {
        switch self {
        case .missingVerificationId:
            return "No verification ID found. Please request a new code."
        case .notAuthenticated:
            return "User is not authenticated."
        }
    }
}
