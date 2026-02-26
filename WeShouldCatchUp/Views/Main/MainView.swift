import SwiftUI

// MARK: - QueueViewModel

/// ViewModel for the main screen queue and "I'm Free" action.
final class QueueViewModel: ObservableObject {

    @Published var queue: [QueueItem] = []
    @Published var isLoading: Bool = false
    @Published var isGoingLive: Bool = false
    @Published var errorMessage: String?

    private let api = APIService.shared

    // MARK: - Fetch Queue

    @MainActor
    func fetchQueue() async {
        isLoading = true
        errorMessage = nil
        do {
            queue = try await api.fetchQueue()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: - Go Live

    @MainActor
    func goLive() async -> Bool {
        isGoingLive = true
        errorMessage = nil
        do {
            _ = try await api.goLive()
            isGoingLive = false
            return true
        } catch {
            errorMessage = error.localizedDescription
            isGoingLive = false
            return false
        }
    }

    // MARK: - Remove from Queue

    @MainActor
    func removeCatchup(catchupId: String) async {
        errorMessage = nil
        do {
            _ = try await api.removeCatchup(catchupId: catchupId)
            queue.removeAll { $0.catchupId == catchupId }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Design Constants

private extension Color {
    static let warmCoral = Color(red: 0.90, green: 0.45, blue: 0.35)
    static let warmCream = Color(red: 0.99, green: 0.97, blue: 0.94)
}

// MARK: - MainView

struct MainView: View {

    @StateObject private var viewModel = QueueViewModel()
    @State private var showInviteView: Bool = false
    @State private var showCallHistory: Bool = false
    @State private var navigateToLive: Bool = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.warmCream
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // MARK: - I'm Free Button
                    imFreeSection

                    Divider()
                        .padding(.horizontal, 24)

                    // MARK: - Queue List
                    queueSection
                }
            }
            .navigationTitle("We Should Catch Up")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showInviteView = true
                    } label: {
                        Image(systemName: "plus.circle")
                            .foregroundColor(.warmCoral)
                    }
                }
            }
            .sheet(isPresented: $showInviteView) {
                InviteView()
            }
            .sheet(isPresented: $showCallHistory) {
                CallHistoryView()
            }
            .navigationDestination(isPresented: $navigateToLive) {
                LiveWaitingView()
            }
            .task {
                await viewModel.fetchQueue()
            }
        }
    }

    // MARK: - I'm Free Section

    private var imFreeSection: some View {
        VStack(spacing: 16) {
            Button {
                Task {
                    let success = await viewModel.goLive()
                    if success {
                        navigateToLive = true
                    }
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.warmCoral)
                        .frame(width: 120, height: 120)
                        .shadow(color: Color.warmCoral.opacity(0.4), radius: 16, x: 0, y: 6)

                    if viewModel.isGoingLive {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(1.2)
                    } else {
                        VStack(spacing: 4) {
                            Image(systemName: "hand.wave.fill")
                                .font(.title)
                            Text("I'm Free")
                                .font(.body)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                    }
                }
            }
            .disabled(viewModel.isGoingLive)
            .padding(.top, 24)

            Text("Tap when you have a few minutes to chat")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.bottom, 20)
        }
    }

    // MARK: - Queue Section

    private var queueSection: some View {
        Group {
            if viewModel.isLoading {
                Spacer()
                ProgressView("Loading your queue...")
                    .foregroundColor(.secondary)
                Spacer()
            } else if viewModel.queue.isEmpty {
                emptyQueueView
            } else {
                queueListView
            }
        }
    }

    // MARK: - Empty Queue

    private var emptyQueueView: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "person.2.slash")
                .font(.system(size: 40))
                .foregroundColor(.secondary.opacity(0.5))

            Text("No one in your queue yet.")
                .font(.body)
                .foregroundColor(.secondary)

            Text("Invite someone to catch up.")
                .font(.caption)
                .foregroundColor(.secondary)

            Button {
                showInviteView = true
            } label: {
                Label("Invite a friend", systemImage: "paperplane.fill")
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.warmCoral)
                    .cornerRadius(12)
            }
            .padding(.top, 8)

            Spacer()
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Queue List

    private var queueListView: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(viewModel.queue.indices, id: \.self) { index in
                        QueueRowView(
                            item: $viewModel.queue[index],
                            onRemove: {
                                Task {
                                    await viewModel.removeCatchup(
                                        catchupId: viewModel.queue[index].catchupId
                                    )
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
            }

            // MARK: - Call History Link
            Button {
                showCallHistory = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "clock.arrow.circlepath")
                    Text("Call History")
                }
                .font(.caption)
                .foregroundColor(.warmCoral)
                .padding(.vertical, 12)
            }
        }
    }

    // MARK: - Error

    @ViewBuilder
    private var errorSection: some View {
        if let errorMessage = viewModel.errorMessage {
            Text(errorMessage)
                .font(.caption)
                .foregroundColor(.red)
                .padding(.horizontal, 24)
        }
    }
}

// MARK: - Preview

#Preview {
    MainView()
}
