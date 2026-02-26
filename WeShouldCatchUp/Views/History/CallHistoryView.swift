import SwiftUI

// MARK: - Design Constants

private extension Color {
    static let warmCoral = Color(red: 0.90, green: 0.45, blue: 0.35)
    static let warmCream = Color(red: 0.99, green: 0.97, blue: 0.94)
}

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
                Color.warmCream
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
                    .foregroundColor(.warmCoral)
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
                .font(.inter(12))
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "phone.badge.waveform")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.4))

            Text("No calls yet.")
                .font(.fraunces(20, weight: .medium))
                .fontWeight(.medium)
                .foregroundColor(.primary)

            Text("Tap I'm Free to get started.")
                .font(.inter(16))
                .foregroundColor(.secondary)
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
                    .fill(Color.warmCoral.opacity(0.12))
                    .frame(width: 42, height: 42)

                Text(String(call.otherUser.name.prefix(1)).uppercased())
                    .font(.inter(16))
                    .fontWeight(.semibold)
                    .foregroundColor(.warmCoral)
            }

            // Details
            VStack(alignment: .leading, spacing: 4) {
                Text(call.otherUser.name)
                    .font(.inter(16))
                    .fontWeight(.medium)
                    .foregroundColor(.primary)

                HStack(spacing: 8) {
                    Text(formattedDate(call.startedAt))
                        .font(.inter(12))
                        .foregroundColor(.secondary)

                    if let duration = call.duration {
                        Text(formattedCallDuration(duration))
                            .font(.inter(12))
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            Image(systemName: "phone.fill")
                .font(.inter(12))
                .foregroundColor(.warmCoral.opacity(0.5))
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
