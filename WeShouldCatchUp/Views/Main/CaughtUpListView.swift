import SwiftUI

// MARK: - CaughtUpListView

/// People you've already caught up with. Tap "Catch up again" to ask to reconnect;
/// they accept and you both land back in each other's active queues.
struct CaughtUpListView: View {

    @ObservedObject var viewModel: CaughtUpViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Constants.Colors.background.ignoresSafeArea()

                if viewModel.isLoading && viewModel.items.isEmpty {
                    ProgressView()
                } else if viewModel.items.isEmpty {
                    emptyView
                } else {
                    ScrollView {
                        VStack(spacing: 8) {
                            ForEach(viewModel.items) { item in
                                row(for: item)
                            }
                        }
                        .padding(16)
                    }
                    .refreshable { await viewModel.fetch() }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Caught Up")
                        .font(.fraunces(20, weight: .semiBold))
                        .foregroundColor(Constants.Colors.textPrimary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.inter(15, weight: .medium))
                        .foregroundColor(Constants.Colors.primary)
                }
            }
            .task { await viewModel.fetch() }
        }
    }

    // MARK: - Row

    @ViewBuilder
    private func row(for item: CaughtUpItem) -> some View {
        HStack(spacing: 12) {
            avatar(for: item)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.otherUser.name)
                    .font(.fraunces(16, weight: .medium))
                    .foregroundColor(Constants.Colors.textPrimary)

                Text(subtitle(for: item))
                    .font(.inter(12, weight: .regular))
                    .foregroundColor(Constants.Colors.textSecondary)
            }

            Spacer()

            trailing(for: item)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(Color.white)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(item.state == .incoming ? Constants.Colors.primary.opacity(0.4) : Constants.Colors.border,
                        lineWidth: 1)
        )
    }

    @ViewBuilder
    private func trailing(for item: CaughtUpItem) -> some View {
        switch item.state {
        case .idle:
            Button {
                Task { await viewModel.requestAgain(catchupId: item.catchupId) }
            } label: {
                Text("Catch up again")
                    .font(.inter(13, weight: .semiBold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(Constants.Colors.primary)
                    .cornerRadius(20)
            }
            .buttonStyle(.plain)

        case .requestedByMe:
            Text("Requested")
                .font(.inter(13, weight: .medium))
                .foregroundColor(Constants.Colors.textTertiary)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(Constants.Colors.background)
                .cornerRadius(20)

        case .incoming:
            HStack(spacing: 8) {
                Button {
                    Task { await viewModel.decline(catchupId: item.catchupId) }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Constants.Colors.textTertiary)
                        .frame(width: 36, height: 36)
                        .background(Constants.Colors.background)
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)

                Button {
                    Task { await viewModel.accept(catchupId: item.catchupId) }
                } label: {
                    Text("Accept")
                        .font(.inter(13, weight: .semiBold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(Constants.Colors.primary)
                        .cornerRadius(20)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func avatar(for item: CaughtUpItem) -> some View {
        ZStack {
            Circle()
                .fill(Constants.Colors.primary.opacity(0.10))
                .frame(width: 44, height: 44)
            Text(String(item.otherUser.name.first ?? "?").uppercased())
                .font(.fraunces(16, weight: .semiBold))
                .foregroundColor(Constants.Colors.primary)
        }
    }

    private func subtitle(for item: CaughtUpItem) -> String {
        if item.state == .incoming {
            return "Wants to catch up again"
        }
        return "Caught up \(timeSince(item.lastCallAt))"
    }

    private func timeSince(_ iso: String?) -> String {
        guard let iso, let date = ISO8601DateFormatter().date(from: iso) else { return "recently" }
        let interval = Date().timeIntervalSince(date)
        switch interval {
        case ..<3600: return "just now"
        case ..<86400: return "\(Int(interval / 3600))h ago"
        case ..<604800: return "\(Int(interval / 86400))d ago"
        case ..<2_592_000:
            let w = Int(interval / 604800); return "\(w) week\(w == 1 ? "" : "s") ago"
        default:
            let m = Int(interval / 2_592_000); return "\(m) month\(m == 1 ? "" : "s") ago"
        }
    }

    private var emptyView: some View {
        VStack(spacing: 14) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 36, weight: .light))
                .foregroundColor(Constants.Colors.textTertiary)
            Text("No one here yet")
                .font(.fraunces(18, weight: .medium))
                .foregroundColor(Constants.Colors.textPrimary)
            Text("After you catch up with someone, they'll move here. Tap “Catch up again” whenever you want to reconnect.")
                .font(.inter(14, weight: .regular))
                .foregroundColor(Constants.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 32)
    }
}
