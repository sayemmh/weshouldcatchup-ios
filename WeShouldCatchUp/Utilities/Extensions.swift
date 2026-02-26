import Foundation
import SwiftUI

// MARK: - Color Hex Init

extension Color {
    /// Initialize a Color from a hex integer, e.g. Color(hex: 0xC4604A)
    init(hex: UInt, opacity: Double = 1.0) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: opacity
        )
    }
}

// MARK: - Date Formatting

extension Date {
    /// Returns a human-readable relative time string like "3 weeks ago" or "never".
    func relativeDateString() -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}

extension Optional where Wrapped == Date {
    /// Returns "never" for nil dates, or a relative string for actual dates.
    func relativeOrNever() -> String {
        switch self {
        case .none:
            return "never"
        case .some(let date):
            return date.relativeDateString()
        }
    }
}

// MARK: - Duration Formatting

extension Int {
    /// Formats seconds into a human-readable duration string.
    /// e.g., 45 -> "45 sec", 125 -> "2 min 5 sec", 3600 -> "1 hr"
    func formattedDuration() -> String {
        let hours = self / 3600
        let minutes = (self % 3600) / 60
        let seconds = self % 60

        if hours > 0 {
            if minutes > 0 {
                return "\(hours) hr \(minutes) min"
            }
            return "\(hours) hr"
        } else if minutes > 0 {
            if seconds > 0 {
                return "\(minutes) min \(seconds) sec"
            }
            return "\(minutes) min"
        } else {
            return "\(seconds) sec"
        }
    }

    /// Formats seconds as mm:ss for a call timer display.
    func callTimerString() -> String {
        let minutes = self / 60
        let seconds = self % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - String Validation

extension String {
    /// Basic phone number validation: must start with + and contain at least 10 digits.
    var isValidPhoneNumber: Bool {
        let digits = self.filter { $0.isNumber }
        return self.hasPrefix("+") && digits.count >= 10
    }

    /// Basic display name validation: at least 1 character, no more than 30.
    var isValidDisplayName: Bool {
        let trimmed = self.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed.count <= 30
    }
}
