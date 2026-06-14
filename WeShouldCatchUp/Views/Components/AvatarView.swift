import SwiftUI

/// Initials avatar in a soft accent circle. Consolidates the ~10 ad-hoc avatar
/// implementations across the app.
struct AvatarView: View {
    let name: String
    var size: CGFloat = 44
    var muted: Bool = false

    var body: some View {
        ZStack {
            Circle()
                .fill(muted ? Constants.Colors.textTertiary.opacity(0.12)
                            : Constants.Colors.accent.opacity(0.10))
            Text(initials)
                .font(.fraunces(size * 0.36, weight: .semiBold))
                .foregroundColor(muted ? Constants.Colors.textTertiary : Constants.Colors.accent)
        }
        .frame(width: size, height: size)
    }

    private var initials: String {
        let parts = name.split(separator: " ")
        if let first = parts.first?.first {
            if parts.count > 1, let second = parts[1].first {
                return "\(first)\(second)".uppercased()
            }
            return String(first).uppercased()
        }
        return "?"
    }
}

#Preview {
    HStack(spacing: 16) {
        AvatarView(name: "Alex Rivera", size: 56)
        AvatarView(name: "Jordan", size: 44)
        AvatarView(name: "Sam", size: 44, muted: true)
    }
    .padding()
    .background(Constants.Colors.canvas)
}
