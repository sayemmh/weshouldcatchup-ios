import SwiftUI

enum Constants {
    // MARK: - API
    /// Base URL for the backend. Update this with your Cloud Run URL.
    static let backendBaseURL = "https://weshouldcatchup-api-395053466295.us-east1.run.app" // Local dev — update to Cloud Run URL for production

    // MARK: - Agora
    /// Agora App ID from the Agora Console.
    static let agoraAppID = "ea5bfbc0e9184dbea8d5b48b37babfe2"

    // MARK: - Deep Links
    static let universalLinkHost = "weshouldcatchup.app"
    static let invitePathPrefix = "/invite/"

    // MARK: - Timing
    static let pingTimeoutSeconds: TimeInterval = 60
    static let liveTTLMinutes: TimeInterval = 10
    static let callEndedAutoDismissSeconds: TimeInterval = 5

    // MARK: - Design
    enum Colors {
        // Coffee accent — primary brand color
        static let primary = Color(hex: 0x6F4E37)             // coffee brown
        static let primaryDark = Color(hex: 0x553A28)         // espresso
        static let primaryLight = Color(hex: 0xE8D5C4)        // latte

        // Backgrounds
        static let background = Color(hex: 0xFAF6F1)          // cream
        static let backgroundDark = Color(hex: 0xF0E8DF)      // oat milk
        static let cardBackground = Color.white                // card

        // Text
        static let textPrimary = Color(hex: 0x2C2119)         // dark roast
        static let textSecondary = Color(hex: 0x5C4F44)       // medium roast
        static let textTertiary = Color(hex: 0x8C7E73)        // light roast

        // Borders
        static let border = Color(hex: 0xDDD3C8)              // border

        // Utility
        static let destructive = Color(hex: 0xFB2C36)         // red
        static let success = Color(red: 0.30, green: 0.70, blue: 0.45)
        static let callBackground = Color(hex: 0x2C2119)      // dark roast for call screen
    }

    enum Fonts {
        // Fraunces is the serif display font from the landing page.
        // On iOS we use the system serif as a fallback since Fraunces
        // needs to be bundled. Replace with "Fraunces" once the font
        // files are added to the project.
        static let displaySerif = "Fraunces"
        static let bodySans = "Inter"
    }

    enum Layout {
        static let horizontalPadding: CGFloat = 24
        static let sectionSpacing: CGFloat = 32
        static let cornerRadius: CGFloat = 12               // 0.75rem
        static let cornerRadiusSmall: CGFloat = 8           // 0.5rem
        static let buttonHeight: CGFloat = 56
        static let imFreeButtonSize: CGFloat = 160
    }
}
