import SwiftUI

// MARK: - Primary Button
//
// The one confident accent CTA. Full-width pill, press feedback + haptic.

struct PrimaryButton: View {
    let title: String
    var systemImage: String? = nil
    var isLoading: Bool = false
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Space.sm) {
                if isLoading {
                    ProgressView().tint(Constants.Colors.onAccent)
                } else {
                    if let systemImage {
                        Image(systemName: systemImage).font(.system(size: 15, weight: .semibold))
                    }
                    Text(title).font(Typography.button)
                }
            }
            .foregroundColor(Constants.Colors.onAccent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Space.lg)
            .background(Constants.Colors.accent.opacity(isEnabled && !isLoading ? 1.0 : 0.4))
            .clipShape(RoundedRectangle(cornerRadius: Radius.pill, style: .continuous))
        }
        .buttonStyle(.pressableHaptic)
        .disabled(!isEnabled || isLoading)
    }
}

// MARK: - Secondary Button
//
// Quieter action — soft accent tint, accent text.

struct SecondaryButton: View {
    let title: String
    var systemImage: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Space.sm) {
                if let systemImage {
                    Image(systemName: systemImage).font(.system(size: 14, weight: .semibold))
                }
                Text(title).font(Typography.button)
            }
            .foregroundColor(Constants.Colors.accent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Space.lg)
            .background(Constants.Colors.accentSoft)
            .clipShape(RoundedRectangle(cornerRadius: Radius.pill, style: .continuous))
        }
        .buttonStyle(.pressable)
    }
}

// MARK: - Text Button
//
// Lowest-emphasis tappable label.

struct TextButton: View {
    let title: String
    var color: Color = Constants.Colors.textSecondary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.inter(15, weight: .medium))
                .foregroundColor(color)
        }
        .buttonStyle(.pressable)
    }
}

#Preview {
    VStack(spacing: 16) {
        PrimaryButton(title: "I'm Free", systemImage: "hand.wave") {}
        PrimaryButton(title: "Loading", isLoading: true) {}
        PrimaryButton(title: "Disabled", isEnabled: false) {}
        SecondaryButton(title: "Catch up again", systemImage: "arrow.clockwise") {}
        TextButton(title: "Not now") {}
    }
    .padding()
    .background(Constants.Colors.canvas)
}
