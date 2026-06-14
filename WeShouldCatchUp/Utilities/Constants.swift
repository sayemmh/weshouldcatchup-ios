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
        // Coffee accent — primary brand color (richer espresso for stronger contrast)
        static let primary = Color(hex: 0x6B4A34)             // espresso accent
        static let primaryDark = Color(hex: 0x4F3625)         // dark espresso (pressed)
        static let primaryLight = Color(hex: 0xF1E7DC)        // soft latte tint

        // Backgrounds
        static let background = Color(hex: 0xFBF8F4)          // warm canvas
        static let backgroundDark = Color(hex: 0xF3ECE3)      // oat milk
        static let cardBackground = Color.white                // card surface

        // Text
        static let textPrimary = Color(hex: 0x221A13)         // dark roast
        static let textSecondary = Color(hex: 0x5C4F44)       // medium roast
        static let textTertiary = Color(hex: 0x9C8E82)        // light roast

        // Borders
        static let border = Color(hex: 0xECE4D9)              // hairline

        // Utility
        static let destructive = Color(hex: 0xE5484D)         // softer red
        static let success = Color(hex: 0x3FA972)             // green
        static let callBackground = Color(hex: 0x221A13)      // dark roast for call screen

        // Semantic aliases — prefer these in new components.
        static let canvas = background
        static let surface = cardBackground
        static let hairline = border
        static let accent = primary
        static let accentSoft = primaryLight
        static let onAccent = Color.white
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
