import SwiftUI
import UIKit

// MARK: - Motion
//
// One small, restrained motion vocabulary used app-wide. Motion that's felt, not seen.

enum Motion {
    /// Transitions, list reorders, section changes.
    static let spring = Animation.spring(response: 0.38, dampingFraction: 0.82)
    /// Button / control press feedback — a touch snappier.
    static let press = Animation.spring(response: 0.28, dampingFraction: 0.70)
    /// Simple opacity/cross-fades.
    static let fade = Animation.easeInOut(duration: 0.22)
}

// MARK: - Haptics

enum Haptics {
    static func light() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func medium() { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
}

// MARK: - Pressable Button Style

/// Shared press feedback for every button: a subtle scale + opacity dip on touch.
struct PressableButtonStyle: ButtonStyle {
    var haptic: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(Motion.press, value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { pressed in
                if pressed && haptic { Haptics.light() }
            }
    }
}

extension ButtonStyle where Self == PressableButtonStyle {
    static var pressable: PressableButtonStyle { PressableButtonStyle() }
    static var pressableHaptic: PressableButtonStyle { PressableButtonStyle(haptic: true) }
}
