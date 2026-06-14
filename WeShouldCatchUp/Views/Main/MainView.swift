import SwiftUI

// MARK: - MainView

struct MainView: View {

    @StateObject private var viewModel = QueueViewModel()
    @StateObject private var caughtUpViewModel = CaughtUpViewModel()
    @State private var showInviteView: Bool = false
    @State private var showCaughtUp: Bool = false
    @State private var showCallHistory: Bool = false
    @State private var navigateToLive: Bool = false
    @State private var showSignOutAlert: Bool = false
    @State private var showSignOutConfirm: Bool = false
    @State private var showDeleteAccountAlert: Bool = false
    @State private var showDeleteAccountConfirm: Bool = false
    @State private var isDeletingAccount: Bool = false
    @State private var liveUntil: Date?
    @State private var isStoppingLive: Bool = false

    var body: some View {
        NavigationStack {
            ZStack {
                Constants.Colors.background
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    liveBanner

                    ScrollView {
                        queueSection
                        bottomLinks
                    }
                    .refreshable {
                        await viewModel.fetchQueue()
                        await caughtUpViewModel.fetch()
                    }

                    imFreeSection
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("We Should Catch Up")
                        .font(.fraunces(20, weight: .semiBold))
                        .foregroundColor(Constants.Colors.textPrimary)
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showSignOutAlert = true
                    } label: {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.system(size: 15, weight: .regular))
                            .foregroundColor(Constants.Colors.textSecondary)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showInviteView = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(Constants.Colors.textPrimary)
                    }
                }
            }
            .sheet(isPresented: $showInviteView) {
                InviteView()
            }
            .sheet(isPresented: $showCaughtUp) {
                CaughtUpListView(viewModel: caughtUpViewModel)
            }
            .sheet(isPresented: $showCallHistory) {
                CallHistoryView()
            }
            .navigationDestination(isPresented: $navigateToLive) {
                LiveWaitingView()
            }
            .confirmationDialog("Account", isPresented: $showSignOutAlert) {
                Button("Sign Out") {
                    showSignOutConfirm = true
                }
                Link("Contact Support", destination: URL(string: "mailto:support@weshouldcatchup.app")!)
                Button("Delete Account", role: .destructive) {
                    showDeleteAccountAlert = true
                }
                Button("Cancel", role: .cancel) { }
            }
            .alert("Are you really sure?", isPresented: $showSignOutConfirm) {
                Button("Yes, Sign Out", role: .destructive) {
                    signOut()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("You'll need to verify your phone number again to sign back in.")
            }
            .alert("Delete Account", isPresented: $showDeleteAccountAlert) {
                Button("Delete My Account", role: .destructive) {
                    showDeleteAccountConfirm = true
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will permanently delete your account, queue, and all data. This cannot be undone.")
            }
            .alert("Are you absolutely sure?", isPresented: $showDeleteAccountConfirm) {
                Button("Yes, Delete Everything", role: .destructive) {
                    Task { await deleteAccount() }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Your account, call history, and all connections will be permanently erased.")
            }
            .task {
                await viewModel.fetchQueue()
                await caughtUpViewModel.fetch()
                await refreshLiveStatus()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                Task {
                    await viewModel.fetchQueue()
                    await caughtUpViewModel.fetch()
                    await refreshLiveStatus()
                }
            }
            .onChange(of: navigateToLive) { isShowing in
                // Coming back from LiveWaitingView — pick up live state if still active.
                if !isShowing {
                    Task { await refreshLiveStatus() }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .queueUpdated)) { _ in
                Task {
                    await viewModel.fetchQueue()
                    await caughtUpViewModel.fetch()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .recatchRequest)) { _ in
                // Someone wants to catch up again — refresh so the badge + list update.
                Task { await caughtUpViewModel.fetch() }
            }
            .onReceive(NotificationCenter.default.publisher(for: .recatchAccepted)) { _ in
                // They're back in your queue.
                Task {
                    await viewModel.fetchQueue()
                    await caughtUpViewModel.fetch()
                }
            }
        }
    }

    // MARK: - Live Banner

    @ViewBuilder
    private var liveBanner: some View {
        if let until = liveUntil, until > Date() {
            HStack(spacing: 10) {
                Circle()
                    .fill(Constants.Colors.success)
                    .frame(width: 8, height: 8)

                VStack(alignment: .leading, spacing: 2) {
                    Text("You're available")
                        .font(.inter(14, weight: .semiBold))
                        .foregroundColor(Constants.Colors.textPrimary)
                    Text("We're pinging your queue — \(minutesLeft(until)) min left. Feel free to close the app.")
                        .font(.inter(12, weight: .regular))
                        .foregroundColor(Constants.Colors.textSecondary)
                }

                Spacer()

                Button {
                    Task { await stopLive() }
                } label: {
                    if isStoppingLive {
                        ProgressView()
                            .tint(Constants.Colors.textSecondary)
                    } else {
                        Text("Stop")
                            .font(.inter(13, weight: .semiBold))
                            .foregroundColor(Constants.Colors.primary)
                    }
                }
                .disabled(isStoppingLive)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Constants.Colors.success.opacity(0.10))
            .cornerRadius(12)
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
    }

    private func minutesLeft(_ until: Date) -> Int {
        max(1, Int((until.timeIntervalSinceNow / 60.0).rounded()))
    }

    @MainActor
    private func refreshLiveStatus() async {
        guard let me = try? await APIService.shared.fetchMe() else { return }
        if me.status == "live",
           let ttlString = me.liveTTL,
           let ttl = ISO8601DateFormatter().date(from: ttlString) {
            liveUntil = ttl
        } else {
            liveUntil = nil
        }
    }

    @MainActor
    private func stopLive() async {
        isStoppingLive = true
        _ = try? await APIService.shared.cancelLive()
        liveUntil = nil
        isStoppingLive = false
    }

    // MARK: - I'm Free Section

    private var imFreeSection: some View {
        VStack(spacing: 10) {
            Button {
                navigateToLive = true
            } label: {
                ZStack {
                    Circle()
                        .fill(Constants.Colors.primary)
                        .frame(width: 140, height: 140)
                        .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 4)

                    VStack(spacing: 6) {
                        Image(systemName: "hand.wave")
                            .font(.system(size: 28, weight: .regular))
                        Text("I'm Free")
                            .font(.inter(15, weight: .semiBold))
                    }
                    .foregroundColor(.white)
                }
            }

            Text("Tap when you have a few minutes")
                .font(.inter(13, weight: .regular))
                .foregroundColor(Constants.Colors.textTertiary)
        }
        .padding(.top, 16)
        .padding(.bottom, 44)
        .background(Constants.Colors.background)
    }

    // MARK: - Queue Section

    private var queueSection: some View {
        Group {
            if viewModel.isLoading {
                VStack(spacing: 12) {
                    Spacer().frame(height: 60)
                    ProgressView()
                    Text("Loading...")
                        .font(.inter(13, weight: .regular))
                        .foregroundColor(Constants.Colors.textSecondary)
                    Spacer()
                }
            } else if viewModel.queue.isEmpty {
                errorSection
                emptyQueueView
            } else {
                errorSection
                queueListView
            }
        }
    }

    // MARK: - Empty Queue

    private var emptyQueueView: some View {
        VStack(spacing: 14) {
            Spacer().frame(height: 32)

            Image(systemName: "person.2")
                .font(.system(size: 36, weight: .light))
                .foregroundColor(Constants.Colors.textTertiary)

            Text("No one in your queue yet")
                .font(.fraunces(18, weight: .medium))
                .foregroundColor(Constants.Colors.textPrimary)

            Text("Invite a friend to get started")
                .font(.inter(14, weight: .regular))
                .foregroundColor(Constants.Colors.textSecondary)

            Button {
                showInviteView = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "paperplane")
                        .font(.system(size: 13, weight: .regular))
                    Text("Send Invite")
                        .font(.inter(14, weight: .medium))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Constants.Colors.primary)
                .cornerRadius(24)
            }
            .padding(.top, 4)

            Spacer()
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Queue List

    private var queueListView: some View {
        VStack(spacing: 0) {
            // Section header
            HStack {
                Text("YOUR QUEUE")
                    .font(.inter(11, weight: .semiBold))
                    .foregroundColor(Constants.Colors.textTertiary)
                    .tracking(1.2)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 10)

            VStack(spacing: 8) {
                ForEach(viewModel.queue) { item in
                    let catchupId = item.catchupId
                    QueueRowView(
                        item: item,
                        onRemove: {
                            Task {
                                await viewModel.removeFromQueue(catchupId: catchupId)
                            }
                        },
                        onMoveToTop: {
                            withAnimation {
                                viewModel.moveToTop(catchupId: catchupId)
                            }
                        },
                        onReport: {
                            Task {
                                await viewModel.reportUser(catchupId: catchupId, userId: item.otherUser.userId)
                            }
                        },
                        onBlock: {
                            Task {
                                await viewModel.reportUser(catchupId: catchupId, userId: item.otherUser.userId)
                            }
                        }
                    )
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Bottom Links (Caught Up + Call History)

    private var bottomLinks: some View {
        HStack(spacing: 24) {
            Button {
                showCaughtUp = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 12, weight: .regular))
                    Text("Caught Up")
                        .font(.inter(13, weight: .medium))
                    if caughtUpViewModel.incomingCount > 0 {
                        Text("\(caughtUpViewModel.incomingCount)")
                            .font(.inter(11, weight: .semiBold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Constants.Colors.primary)
                            .clipShape(Capsule())
                    }
                }
                .foregroundColor(Constants.Colors.textSecondary)
            }

            Button {
                showCallHistory = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(.system(size: 12, weight: .regular))
                    Text("Call History")
                        .font(.inter(13, weight: .medium))
                }
                .foregroundColor(Constants.Colors.textSecondary)
            }
        }
        .padding(.vertical, 16)
    }

    // MARK: - Sign Out

    private func signOut() {
        try? AuthService.shared.signOut()
    }

    // MARK: - Delete Account

    @MainActor
    private func deleteAccount() async {
        isDeletingAccount = true
        do {
            try await APIService.shared.deleteAccount()
            try? AuthService.shared.signOut()
        } catch {
            viewModel.errorMessage = "Couldn't delete account. Please try again."
        }
        isDeletingAccount = false
    }

    // MARK: - Error

    @ViewBuilder
    private var errorSection: some View {
        if let errorMessage = viewModel.errorMessage {
            Text(errorMessage)
                .font(.inter(13, weight: .regular))
                .foregroundColor(.red)
                .padding(.horizontal, 24)
        }
    }
}

// MARK: - Preview

#Preview {
    MainView()
}
