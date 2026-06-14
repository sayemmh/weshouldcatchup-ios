import SwiftUI

struct QueueRowView: View {

    var item: QueueItem
    var onRemove: () -> Void
    var onMoveToTop: () -> Void
    var onReport: () -> Void
    var onBlock: () -> Void
    var onRequestRecatch: () -> Void = {}
    var onAcceptRecatch: () -> Void = {}
    var onDeclineRecatch: () -> Void = {}

    @State private var showConfirm = false
    @State private var showReport = false

    private var isCaughtUp: Bool { item.isCaughtUp }

    var body: some View {
        HStack(spacing: Space.md) {
            AvatarView(name: item.otherUser.name, size: 44, muted: isCaughtUp && item.recatch != .incoming)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: Space.sm) {
                    Text(item.otherUser.name)
                        .font(Typography.headline)
                        .foregroundColor(item.isPending ? Constants.Colors.textSecondary : Constants.Colors.textPrimary)

                    if item.isPending {
                        Pill(text: "Pending")
                    }
                }
                subtitle
            }

            Spacer()

            trailing
        }
        .padding(.vertical, Space.md)
        .padding(.horizontal, Space.lg)
        .background(Constants.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                .stroke(item.recatch == .incoming ? Constants.Colors.accent.opacity(0.35) : Constants.Colors.hairline,
                        lineWidth: 1)
        )
        .cardElevation()
        .contextMenu {
            if !item.isPending {
                Button(role: .destructive) { showReport = true } label: { Label("Report", systemImage: "flag") }
                Button(role: .destructive) { onBlock() } label: { Label("Block", systemImage: "hand.raised") }
                Button(role: .destructive) { showConfirm = true } label: { Label("Remove", systemImage: "xmark") }
            }
        }
        .alert(item.isPending ? "Cancel invite?" : "Remove \(item.otherUser.name)?", isPresented: $showConfirm) {
            Button("Remove", role: .destructive) { onRemove() }
            Button("Keep", role: .cancel) {}
        }
        .alert("Report \(item.otherUser.name)?", isPresented: $showReport) {
            Button("Report & Block", role: .destructive) { onReport() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will block them and notify our team. We review all reports within 24 hours.")
        }
    }

    // MARK: - Subtitle

    @ViewBuilder
    private var subtitle: some View {
        if item.isPending {
            Text("Waiting for them to accept")
                .font(Typography.caption)
                .foregroundColor(Constants.Colors.textTertiary)
        } else if item.recatch == .incoming {
            Text("Wants to catch up again")
                .font(Typography.caption)
                .foregroundColor(Constants.Colors.accent)
        } else if isCaughtUp {
            Text("Caught up \(timeSinceLastCall)")
                .font(Typography.caption)
                .foregroundColor(Constants.Colors.textTertiary)
        } else {
            HStack(spacing: Space.md) {
                Label(timeSinceLastCall, systemImage: "clock")
                Label(callCountLabel, systemImage: "phone")
            }
            .font(Typography.caption)
            .foregroundColor(Constants.Colors.textSecondary)
        }
    }

    // MARK: - Trailing controls

    @ViewBuilder
    private var trailing: some View {
        switch (isCaughtUp, item.recatch) {
        case (true, .incoming):
            HStack(spacing: Space.sm) {
                iconButton("xmark", action: onDeclineRecatch)
                Button(action: onAcceptRecatch) {
                    Text("Accept")
                        .font(.inter(13, weight: .semiBold))
                        .foregroundColor(Constants.Colors.onAccent)
                        .padding(.horizontal, Space.md).padding(.vertical, 9)
                        .background(Constants.Colors.accent)
                        .clipShape(Capsule())
                }
                .buttonStyle(.pressableHaptic)
            }
        case (true, .requestedByMe):
            Text("Requested")
                .font(.inter(13, weight: .medium))
                .foregroundColor(Constants.Colors.textTertiary)
                .padding(.horizontal, Space.md).padding(.vertical, 9)
                .background(Constants.Colors.backgroundDark)
                .clipShape(Capsule())
        case (true, _):
            Button(action: onRequestRecatch) {
                Text("Catch up again")
                    .font(.inter(13, weight: .semiBold))
                    .foregroundColor(Constants.Colors.accent)
                    .padding(.horizontal, Space.md).padding(.vertical, 9)
                    .background(Constants.Colors.accentSoft)
                    .clipShape(Capsule())
            }
            .buttonStyle(.pressableHaptic)
        default:
            HStack(spacing: Space.sm) {
                iconButton("arrow.up", action: onMoveToTop)
                iconButton("xmark", action: { showConfirm = true })
            }
        }
    }

    private func iconButton(_ system: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Constants.Colors.textTertiary)
                .frame(width: 36, height: 36)
                .background(Constants.Colors.canvas)
                .clipShape(RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
        }
        .buttonStyle(.pressable)
    }

    // MARK: - Helpers

    private var timeSinceLastCall: String {
        guard let lastCallAt = item.lastCallAt,
              let date = ISO8601DateFormatter().date(from: lastCallAt) else { return "never" }
        let interval = Date().timeIntervalSince(date)
        switch interval {
        case ..<60: return "just now"
        case ..<3600: return "\(Int(interval / 60)) min ago"
        case ..<86400: return "\(Int(interval / 3600))h ago"
        case ..<604800: return "\(Int(interval / 86400))d ago"
        case ..<2_592_000: let w = Int(interval / 604800); return "\(w) week\(w == 1 ? "" : "s") ago"
        default: let m = Int(interval / 2_592_000); return "\(m) month\(m == 1 ? "" : "s") ago"
        }
    }

    private var callCountLabel: String {
        switch item.callCount {
        case 0: return "no calls"
        case 1: return "1 call"
        default: return "\(item.callCount) calls"
        }
    }
}

// MARK: - Pill

struct Pill: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.inter(10, weight: .semiBold))
            .foregroundColor(Constants.Colors.accent)
            .padding(.horizontal, Space.sm)
            .padding(.vertical, 3)
            .background(Constants.Colors.accentSoft)
            .clipShape(Capsule())
    }
}
