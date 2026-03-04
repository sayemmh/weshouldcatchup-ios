import SwiftUI

// MARK: - QueueRowView

struct QueueRowView: View {

    @Binding var item: QueueItem

    /// Called when the user confirms removal of this item from the queue.
    var onRemove: () -> Void

    @State private var showRemoveConfirmation: Bool = false

    var body: some View {
        HStack(spacing: 14) {
            // MARK: - Avatar
            avatarView

            // MARK: - Info
            VStack(alignment: .leading, spacing: 4) {
                Text(item.otherUser.name)
                    .font(.fraunces(16, weight: .medium))
                    .foregroundColor(Constants.Colors.textPrimary)

                HStack(spacing: 10) {
                    Label(timeSinceLastCall, systemImage: "clock")
                        .font(.inter(12, weight: .regular))
                        .foregroundColor(Constants.Colors.textSecondary)

                    Label(callCountLabel, systemImage: "phone")
                        .font(.inter(12, weight: .regular))
                        .foregroundColor(Constants.Colors.textSecondary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .regular))
                .foregroundColor(Constants.Colors.textTertiary)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(Color.white)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Constants.Colors.border, lineWidth: 1)
        )
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                showRemoveConfirmation = true
            } label: {
                Label("Remove", systemImage: "trash")
            }
        }
        .alert("Remove from queue?", isPresented: $showRemoveConfirmation) {
            Button("Remove", role: .destructive) {
                onRemove()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You'll no longer be able to catch up with \(item.otherUser.name). You can always add them back later.")
        }
    }

    // MARK: - Avatar

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

    // MARK: - Computed Properties

    /// Returns the initials from the user's name (first letter).
    private var initials: String {
        let name = item.otherUser.name
        guard let first = name.first else { return "?" }
        return String(first).uppercased()
    }

    /// Formats the time since the last call as a human-readable string.
    private var timeSinceLastCall: String {
        guard let lastCallAt = item.lastCallAt,
              let date = ISO8601DateFormatter().date(from: lastCallAt) else {
            return "never"
        }

        let now = Date()
        let interval = now.timeIntervalSince(date)

        switch interval {
        case ..<60:
            return "just now"
        case ..<3600:
            let minutes = Int(interval / 60)
            return "\(minutes) min ago"
        case ..<86400:
            let hours = Int(interval / 3600)
            return "\(hours)h ago"
        case ..<604800:
            let days = Int(interval / 86400)
            return "\(days)d ago"
        case ..<2_592_000:
            let weeks = Int(interval / 604800)
            return "\(weeks) week\(weeks == 1 ? "" : "s") ago"
        default:
            let months = Int(interval / 2_592_000)
            return "\(months) month\(months == 1 ? "" : "s") ago"
        }
    }

    /// Formats the call count.
    private var callCountLabel: String {
        switch item.callCount {
        case 0:
            return "no calls"
        case 1:
            return "1 call"
        default:
            return "\(item.callCount) calls"
        }
    }
}

// MARK: - Preview

#Preview {
    let sampleItem = QueueItem(
        catchupId: "preview-1",
        otherUser: QueueItem.OtherUser(name: "Alex", userId: "user-123"),
        lastCallAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-604800 * 3)),
        callCount: 5
    )

    return List {
        QueueRowView(item: .constant(sampleItem)) {
            print("Remove tapped")
        }
    }
    .listStyle(.plain)
    .background(Constants.Colors.background)
}
