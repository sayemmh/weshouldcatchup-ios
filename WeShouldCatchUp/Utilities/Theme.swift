import SwiftUI

// MARK: - Theme
//
// Premium, editorial take on the warm coffee identity. Fraunces for display with
// real size jumps, Inter for UI; generous whitespace, hairline dividers, one
// confident accent. Use these named tokens instead of magic numbers per view.

enum Typography {
    static let display  = Font.fraunces(30, weight: .semiBold)   // hero headlines
    static let title    = Font.fraunces(24, weight: .semiBold)   // screen titles
    static let headline = Font.fraunces(18, weight: .medium)     // names, row headlines
    static let body     = Font.inter(15, weight: .regular)       // body copy
    static let callout  = Font.inter(14, weight: .medium)        // emphasized labels
    static let caption  = Font.inter(12, weight: .regular)       // metadata, captions
    static let button   = Font.inter(16, weight: .semiBold)      // button labels
    static let overline = Font.inter(11, weight: .semiBold)      // section headers (tracked)
}

enum Space {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 20
    static let xxl: CGFloat = 24
    static let xxxl: CGFloat = 32
}

enum Radius {
    static let sm: CGFloat = 10
    static let md: CGFloat = 14
    static let lg: CGFloat = 20
    static let pill: CGFloat = 28
}

// MARK: - Elevation

extension View {
    /// Soft, low-opacity card shadow — the standard raised surface.
    func cardElevation() -> some View {
        shadow(color: .black.opacity(0.04), radius: 12, x: 0, y: 4)
    }

    /// A slightly stronger lift for floating/emphasized surfaces.
    func raisedElevation() -> some View {
        shadow(color: .black.opacity(0.06), radius: 18, x: 0, y: 6)
    }
}
