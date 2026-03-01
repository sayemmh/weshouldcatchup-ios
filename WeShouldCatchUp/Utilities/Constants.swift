import SwiftUI

enum Constants {
    // MARK: - API
    /// Base URL for the backend. Update this with your Cloud Run URL.
    static let backendBaseURL = "http://10.0.0.11:8080" // Local dev — update to Cloud Run URL for production

    // MARK: - Agora
    /// Agora App ID from the Agora Console.
    static let agoraAppID = "e7f6e9aeecf14b2ba10e3f40be9f56e7"

    // MARK: - Deep Links
    static let universalLinkHost = "weshouldcatchup.app"
    static let invitePathPrefix = "/invite/"

    // MARK: - Timing
    static let pingTimeoutSeconds: TimeInterval = 60
    static let liveTTLMinutes: TimeInterval = 10
    static let callEndedAutoDismissSeconds: TimeInterval = 5

    // MARK: - Design (matches weshouldcatchup.vercel.app)
    enum Colors {
        // Muted terracotta accent — primary brand color
        static let primary = Color(hex: 0xB5695A)             // muted terracotta
        static let primaryDark = Color(hex: 0x96524A)         // darker muted
        static let primaryLight = Color(hex: 0xF0DDD7)        // --color-terracotta-light

        // Backgrounds
        static let background = Color(hex: 0xFBF7F4)          // --color-cream
        static let backgroundDark = Color(hex: 0xF5EDE8)      // --color-cream-dark
        static let cardBackground = Color.white                // --color-card

        // Text
        static let textPrimary = Color(hex: 0x2D2926)         // --color-warm-charcoal
        static let textSecondary = Color(hex: 0x6B6560)       // --color-warm-muted
        static let textTertiary = Color(hex: 0x9A9490)        // --color-warm-light

        // Borders
        static let border = Color(hex: 0xE8E0DA)              // --color-border

        // Utility
        static let destructive = Color(hex: 0xFB2C36)         // --color-red-500
        static let success = Color(red: 0.30, green: 0.70, blue: 0.45)
        static let callBackground = Color(hex: 0x2D2926)      // warm charcoal for call screen
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
