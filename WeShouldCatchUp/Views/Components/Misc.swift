import SwiftUI

// MARK: - Section Header

struct SectionHeader: View {
    let title: String
    var badge: Int = 0

    var body: some View {
        HStack(spacing: Space.sm) {
            Text(title.uppercased())
                .font(Typography.overline)
                .tracking(1.2)
                .foregroundColor(Constants.Colors.textTertiary)
            if badge > 0 {
                Badge(count: badge)
            }
            Spacer()
        }
        .padding(.horizontal, Space.xl)
        .padding(.top, Space.lg)
        .padding(.bottom, Space.sm)
    }
}

// MARK: - Badge

struct Badge: View {
    let count: Int

    var body: some View {
        Text("\(count)")
            .font(.inter(11, weight: .semiBold))
            .foregroundColor(Constants.Colors.onAccent)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Constants.Colors.accent)
            .clipShape(Capsule())
    }
}

// MARK: - Empty State

struct EmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    @State private var appeared = false

    var body: some View {
        VStack(spacing: Space.md) {
            Image(systemName: icon)
                .font(.system(size: 40, weight: .light))
                .foregroundColor(Constants.Colors.textTertiary)
                .scaleEffect(appeared ? 1 : 0.8)
                .opacity(appeared ? 1 : 0)

            Text(title)
                .font(Typography.headline)
                .foregroundColor(Constants.Colors.textPrimary)

            Text(subtitle)
                .font(Typography.body)
                .foregroundColor(Constants.Colors.textSecondary)
                .multilineTextAlignment(.center)

            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(Typography.callout)
                        .foregroundColor(Constants.Colors.onAccent)
                        .padding(.horizontal, Space.xxl)
                        .padding(.vertical, Space.md)
                        .background(Constants.Colors.accent)
                        .clipShape(Capsule())
                }
                .buttonStyle(.pressableHaptic)
                .padding(.top, Space.xs)
            }
        }
        .padding(.horizontal, Space.xxxl)
        .onAppear { withAnimation(Motion.spring) { appeared = true } }
    }
}

// MARK: - Skeleton Row (loading placeholder)

struct SkeletonRow: View {
    @State private var shimmer = false

    var body: some View {
        HStack(spacing: Space.md) {
            Circle().fill(shimmerColor).frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: Space.sm) {
                RoundedRectangle(cornerRadius: 4).fill(shimmerColor).frame(width: 120, height: 12)
                RoundedRectangle(cornerRadius: 4).fill(shimmerColor).frame(width: 80, height: 10)
            }
            Spacer()
        }
        .padding(Space.lg)
        .background(Constants.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                shimmer = true
            }
        }
    }

    private var shimmerColor: Color {
        Constants.Colors.textTertiary.opacity(shimmer ? 0.10 : 0.20)
    }
}
