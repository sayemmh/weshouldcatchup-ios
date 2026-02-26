import SwiftUI

enum Constants {
    // MARK: - API
    /// Base URL for the backend. Update this with your Cloud Run URL.
    static let backendBaseURL = "https://your-cloud-run-url.run.app" // TODO: Replace with actual URL

    // MARK: - Agora
    /// Agora App ID from the Agora Console.
    static let agoraAppID = "" // TODO: Add your Agora App ID

    // MARK: - Deep Links
    static let universalLinkHost = "weshouldcatchup.app"
    static let invitePathPrefix = "/invite/"

    // MARK: - Timing
    static let pingTimeoutSeconds: TimeInterval = 60
    static let liveTTLMinutes: TimeInterval = 10
    static let callEndedAutoDismissSeconds: TimeInterval = 5

    // MARK: - Design
    enum Colors {
        static let primary = Color(red: 0.90, green: 0.45, blue: 0.35)     // Warm coral
        static let primaryDark = Color(red: 0.78, green: 0.35, blue: 0.27)
        static let background = Color(red: 0.99, green: 0.97, blue: 0.94)  // Warm cream
        static let cardBackground = Color.white
        static let textPrimary = Color(red: 0.20, green: 0.18, blue: 0.16)
        static let textSecondary = Color(red: 0.55, green: 0.50, blue: 0.46)
        static let destructive = Color(red: 0.85, green: 0.25, blue: 0.20)
        static let success = Color(red: 0.30, green: 0.70, blue: 0.45)
        static let callBackground = Color(red: 0.12, green: 0.11, blue: 0.10)
    }

    enum Layout {
        static let horizontalPadding: CGFloat = 24
        static let sectionSpacing: CGFloat = 32
        static let cornerRadius: CGFloat = 16
        static let buttonHeight: CGFloat = 56
        static let imFreeButtonSize: CGFloat = 160
    }
}
