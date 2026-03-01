import SwiftUI

// MARK: - MainView

struct MainView: View {

    @StateObject private var viewModel = QueueViewModel()
    @State private var showInviteView: Bool = false
    @State private var showCallHistory: Bool = false
    @State private var navigateToLive: Bool = false

    var body: some View {
        NavigationStack {
            ZStack {
                Constants.Colors.background
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
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("We Should Catch Up")
                        .font(.fraunces(22, weight: .semiBold))
                        .foregroundColor(Constants.Colors.textPrimary)
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        signOut()
                    } label: {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .foregroundColor(Constants.Colors.textSecondary)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showInviteView = true
                    } label: {
                        Image(systemName: "plus.circle")
                            .foregroundColor(Constants.Colors.primary)
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
                navigateToLive = true
            } label: {
                ZStack {
                    Circle()
                        .fill(Constants.Colors.primary)
                        .frame(width: 120, height: 120)
                        .shadow(color: Constants.Colors.primary.opacity(0.4), radius: 16, x: 0, y: 6)

                    VStack(spacing: 4) {
                        Image(systemName: "hand.wave.fill")
                            .font(.fraunces(28, weight: .semiBold))
                        Text("I'm Free")
                            .font(.inter(16))
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                }
            }
            .padding(.top, 24)

            Text("Tap when you have a few minutes to chat")
                .font(.inter(12))
                .foregroundColor(Constants.Colors.textSecondary)
                .padding(.bottom, 20)
        }
    }

    // MARK: - Queue Section

    private var queueSection: some View {
        Group {
            if viewModel.isLoading {
                Spacer()
                ProgressView("Loading your queue...")
                    .foregroundColor(Constants.Colors.textSecondary)
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
                .foregroundColor(Constants.Colors.textSecondary.opacity(0.5))

            Text("No one in your queue yet.")
                .font(.inter(16))
                .foregroundColor(Constants.Colors.textSecondary)

            Text("Invite someone to catch up.")
                .font(.inter(12))
                .foregroundColor(Constants.Colors.textSecondary)

            Button {
                showInviteView = true
            } label: {
                Label("Invite a friend", systemImage: "paperplane.fill")
                    .font(.inter(16))
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Constants.Colors.primary)
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
                                    await viewModel.removeFromQueue(
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
                .font(.inter(12))
                .foregroundColor(Constants.Colors.primary)
                .padding(.vertical, 12)
            }
        }
    }

    // MARK: - Sign Out

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    private func signOut() {
        try? AuthService.shared.signOut()
        hasCompletedOnboarding = false
    }

    // MARK: - Error

    @ViewBuilder
    private var errorSection: some View {
        if let errorMessage = viewModel.errorMessage {
            Text(errorMessage)
                .font(.inter(12))
                .foregroundColor(.red)
                .padding(.horizontal, 24)
        }
    }
}

// MARK: - Preview

#Preview {
    MainView()
}
