import Foundation
import FirebaseAuth
import Combine

/// Firebase Auth wrapper handling phone number authentication.
final class AuthService: ObservableObject {

    static let shared = AuthService()

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

    private func listenForAuthChanges() {
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            DispatchQueue.main.async {
                self?.isAuthenticated = user != nil
                self?.currentUserId = user?.uid
            }
        }
    }

    // MARK: - Phone Auth

    func sendVerificationCode(phoneNumber: String) async throws {
        #if targetEnvironment(simulator)
        // Firebase Phone Auth crashes on simulator due to missing APNs.
        // Sign in anonymously instead so we can test the rest of the app.
        let result = try await Auth.auth().signInAnonymously()
        await MainActor.run {
            self.isAuthenticated = true
            self.currentUserId = result.user.uid
            self.verificationId = "simulator-bypass"
        }
        return
        #else
        Auth.auth().settings?.isAppVerificationDisabledForTesting = false
        let id = try await PhoneAuthProvider.provider().verifyPhoneNumber(
            phoneNumber,
            uiDelegate: nil
        )
        await MainActor.run {
            self.verificationId = id
        }
        #endif
    }

    func verifyCode(code: String) async throws {
        #if targetEnvironment(simulator)
        // Already signed in via anonymous auth in sendVerificationCode.
        return
        #else
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
        #endif
    }

    func signOut() throws {
        try Auth.auth().signOut()
        DispatchQueue.main.async {
            self.isAuthenticated = false
            self.currentUserId = nil
            self.verificationId = nil
        }
    }

    // MARK: - Token Helper

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
