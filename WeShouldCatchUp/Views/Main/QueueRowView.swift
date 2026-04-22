import SwiftUI

struct QueueRowView: View {

    var item: QueueItem
    var onRemove: () -> Void
    var onMoveToTop: () -> Void
    var onReport: () -> Void
    var onBlock: () -> Void

    @State private var showConfirm = false
    @State private var showReport = false

    var body: some View {
        HStack(spacing: 12) {
            avatarView

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(item.otherUser.name)
                        .font(.fraunces(16, weight: .medium))
                        .foregroundColor(item.isPending ? Constants.Colors.textSecondary : Constants.Colors.textPrimary)

                    if item.isPending {
                        Text("Pending")
                            .font(.inter(10, weight: .semiBold))
                            .foregroundColor(Constants.Colors.primary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Constants.Colors.primaryLight)
                            .cornerRadius(6)
                    }
                }

                if item.isPending {
                    Text("Waiting for them to accept")
                        .font(.inter(12, weight: .regular))
                        .foregroundColor(Constants.Colors.textTertiary)
                } else {
                    HStack(spacing: 10) {
                        Label(timeSinceLastCall, systemImage: "clock")
                            .font(.inter(12, weight: .regular))
                            .foregroundColor(Constants.Colors.textSecondary)

                        Label(callCountLabel, systemImage: "phone")
                            .font(.inter(12, weight: .regular))
                            .foregroundColor(Constants.Colors.textSecondary)
                    }
                }
            }

            Spacer()

            Button {
                onMoveToTop()
            } label: {
                Image(systemName: "arrow.up")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Constants.Colors.textTertiary)
                    .frame(width: 36, height: 36)
                    .background(Constants.Colors.background)
                    .cornerRadius(8)
            }
            .buttonStyle(.plain)

            Button {
                showConfirm = true
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Constants.Colors.textTertiary)
                    .frame(width: 36, height: 36)
                    .background(Constants.Colors.background)
                    .cornerRadius(8)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(Color.white)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Constants.Colors.border, lineWidth: 1)
        )
        .contextMenu {
            if !item.isPending {
                Button(role: .destructive) {
                    showReport = true
                } label: {
                    Label("Report", systemImage: "flag")
                }
                Button(role: .destructive) {
                    onBlock()
                } label: {
                    Label("Block", systemImage: "hand.raised")
                }
            }
        }
        .alert(item.isPending ? "Cancel invite?" : "Remove \(item.otherUser.name)?", isPresented: $showConfirm) {
            Button("Remove", role: .destructive) {
                onRemove()
            }
            Button("Keep", role: .cancel) {}
        }
        .alert("Report \(item.otherUser.name)?", isPresented: $showReport) {
            Button("Report & Block", role: .destructive) {
                onReport()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will block them and notify our team. We review all reports within 24 hours.")
        }
    }

    private var avatarView: some View {
        ZStack {
            Circle()
                .fill(Constants.Colors.primary.opacity(0.10))
                .frame(width: 44, height: 44)

            Text(initials)
                .font(.fraunces(16, weight: .semiBold))
                .foregroundColor(Constants.Colors.primary)
        }
    }

    private var initials: String {
        let name = item.otherUser.name
        guard let first = name.first else { return "?" }
        return String(first).uppercased()
    }

    private var timeSinceLastCall: String {
        guard let lastCallAt = item.lastCallAt,
              let date = ISO8601DateFormatter().date(from: lastCallAt) else {
            return "never"
        }

        let interval = Date().timeIntervalSince(date)

        switch interval {
        case ..<60: return "just now"
        case ..<3600: return "\(Int(interval / 60)) min ago"
        case ..<86400: return "\(Int(interval / 3600))h ago"
        case ..<604800: return "\(Int(interval / 86400))d ago"
        case ..<2_592_000:
            let w = Int(interval / 604800)
            return "\(w) week\(w == 1 ? "" : "s") ago"
        default:
            let m = Int(interval / 2_592_000)
            return "\(m) month\(m == 1 ? "" : "s") ago"
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

#Preview {
    let sampleItem = QueueItem(
        catchupId: "preview-1",
        otherUser: QueueItem.OtherUser(name: "Alex", userId: "user-123"),
        lastCallAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-604800 * 3)),
        callCount: 5,
        status: "active"
    )

    VStack {
        QueueRowView(item: sampleItem, onRemove: {}, onMoveToTop: {}, onReport: {}, onBlock: {})
    }
    .padding()
    .background(Constants.Colors.background)
}
