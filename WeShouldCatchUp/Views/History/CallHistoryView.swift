import SwiftUI

// MARK: - CallHistoryView

struct CallHistoryView: View {

    @Environment(\.dismiss) private var dismiss

    @State private var calls: [CallHistoryItem] = []
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?

    private let api = APIService.shared

    var body: some View {
        NavigationStack {
            ZStack {
                Constants.Colors.background
                    .ignoresSafeArea()

                Group {
                    if isLoading {
                        loadingView
                    } else if calls.isEmpty {
                        emptyStateView
                    } else {
                        callListView
                    }
                }
            }
            .navigationTitle("Call History")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(Constants.Colors.primary)
                }
            }
            .task {
                await fetchHistory()
            }
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Loading call history...")
                .font(.fraunces(13, weight: .regular))
                .foregroundColor(Constants.Colors.textSecondary)
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "phone")
                .font(.system(size: 48, weight: .thin))
                .foregroundColor(Constants.Colors.textSecondary.opacity(0.4))

            Text("No calls yet.")
                .font(.fraunces(20, weight: .medium))
                .foregroundColor(Constants.Colors.textPrimary)

            Text("Tap I'm Free to get started.")
                .font(.fraunces(16, weight: .regular))
                .foregroundColor(Constants.Colors.textSecondary)
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Call List

    private var callListView: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(calls) { call in
                    callRow(call)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
        }
    }

    // MARK: - Call Row

    private func callRow(_ call: CallHistoryItem) -> some View {
        HStack(spacing: 14) {
            // Avatar
            ZStack {
                Circle()
                    .fill(Constants.Colors.primary.opacity(0.12))
                    .frame(width: 42, height: 42)

                Text(String(call.otherUser.name.prefix(1)).uppercased())
                    .font(.fraunces(16, weight: .semiBold))
                    .foregroundColor(Constants.Colors.primary)
            }

            // Details
            VStack(alignment: .leading, spacing: 4) {
                Text(call.otherUser.name)
                    .font(.fraunces(16, weight: .medium))
                    .foregroundColor(Constants.Colors.textPrimary)

                HStack(spacing: 8) {
                    Text(formattedDate(call.startedAt))
                        .font(.fraunces(12, weight: .regular))
                        .foregroundColor(Constants.Colors.textSecondary)

                    if let duration = call.duration {
                        Text(formattedCallDuration(duration))
                            .font(.fraunces(12, weight: .regular))
                            .foregroundColor(Constants.Colors.textSecondary)
                    }
                }
            }

            Spacer()

            Image(systemName: "phone")
                .font(.system(size: 12, weight: .light))
                .foregroundColor(Constants.Colors.primary.opacity(0.5))
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 16)
        .background(Color.white)
        .cornerRadius(12)
    }

    // MARK: - Formatting Helpers

    /// Formats an ISO 8601 date string as a relative date (e.g. "Yesterday", "Jan 15").
    private func formattedDate(_ isoString: String) -> String {
        guard let date = ISO8601DateFormatter().date(from: isoString) else {
            return isoString
        }

        let calendar = Calendar.current
        let now = Date()

        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            // Show "Jan 15" for dates in the current year, "Jan 15, 2025" otherwise.
            if calendar.component(.year, from: date) == calendar.component(.year, from: now) {
                formatter.dateFormat = "MMM d"
            } else {
                formatter.dateFormat = "MMM d, yyyy"
            }
            return formatter.string(from: date)
        }
    }

    /// Formats a duration in seconds to a human-readable string (e.g. "12 min", "3 min 45 sec").
    private func formattedCallDuration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60

        if minutes == 0 {
            return "\(secs) sec"
        } else if secs == 0 {
            return "\(minutes) min"
        } else {
            return "\(minutes) min \(secs) sec"
        }
    }

    // MARK: - Fetch

    @MainActor
    private func fetchHistory() async {
        isLoading = true
        errorMessage = nil
        do {
            calls = try await api.fetchCallHistory()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - Preview

#Preview {
    CallHistoryView()
}
