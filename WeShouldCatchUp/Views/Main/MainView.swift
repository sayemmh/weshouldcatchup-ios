import SwiftUI

// MARK: - MainView

struct MainView: View {

    @StateObject private var viewModel = QueueViewModel()
    @State private var showInviteView: Bool = false
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
                Constants.Colors.canvas.ignoresSafeArea()

                VStack(spacing: 0) {
                    liveBanner

                    ScrollView {
                        queueContent
                            .padding(.bottom, Space.sm)
                    }
                    .refreshable { await viewModel.fetchQueue() }

                    imFreeSection
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("We Should Catch Up")
                        .font(.fraunces(19, weight: .semiBold))
                        .foregroundColor(Constants.Colors.textPrimary)
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { showSignOutAlert = true } label: {
                        Image(systemName: "line.3.horizontal")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(Constants.Colors.textSecondary)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showInviteView = true } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 17, weight: .regular))
                            .foregroundColor(Constants.Colors.textPrimary)
                    }
                }
            }
            .sheet(isPresented: $showInviteView) { InviteView() }
            .sheet(isPresented: $showCallHistory) { CallHistoryView() }
            .navigationDestination(isPresented: $navigateToLive) { LiveWaitingView() }
            .confirmationDialog("Account", isPresented: $showSignOutAlert) {
                Button("Sign Out") { showSignOutConfirm = true }
                Link("Contact Support", destination: URL(string: "mailto:support@weshouldcatchup.app")!)
                Button("Delete Account", role: .destructive) { showDeleteAccountAlert = true }
                Button("Cancel", role: .cancel) { }
            }
            .alert("Are you really sure?", isPresented: $showSignOutConfirm) {
                Button("Yes, Sign Out", role: .destructive) { signOut() }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("You'll need to verify your phone number again to sign back in.")
            }
            .alert("Delete Account", isPresented: $showDeleteAccountAlert) {
                Button("Delete My Account", role: .destructive) { showDeleteAccountConfirm = true }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will permanently delete your account, queue, and all data. This cannot be undone.")
            }
            .alert("Are you absolutely sure?", isPresented: $showDeleteAccountConfirm) {
                Button("Yes, Delete Everything", role: .destructive) { Task { await deleteAccount() } }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Your account, call history, and all connections will be permanently erased.")
            }
            .task {
                await viewModel.fetchQueue()
                await refreshLiveStatus()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                Task { await viewModel.fetchQueue(); await refreshLiveStatus() }
            }
            .onChange(of: navigateToLive) { isShowing in
                if !isShowing { Task { await refreshLiveStatus() } }
            }
            .onReceive(NotificationCenter.default.publisher(for: .queueUpdated)) { _ in
                Task { await viewModel.fetchQueue() }
            }
            .onReceive(NotificationCenter.default.publisher(for: .recatchRequest)) { _ in
                Task { await viewModel.fetchQueue() }
            }
            .onReceive(NotificationCenter.default.publisher(for: .recatchAccepted)) { _ in
                Task { await viewModel.fetchQueue() }
            }
        }
    }

    // MARK: - Live Banner

    @ViewBuilder
    private var liveBanner: some View {
        if let until = liveUntil, until > Date() {
            HStack(spacing: Space.md) {
                LiveDot()
                VStack(alignment: .leading, spacing: 2) {
                    Text("You're available")
                        .font(.inter(14, weight: .semiBold))
                        .foregroundColor(Constants.Colors.textPrimary)
                    Text("We're pinging your queue — \(minutesLeft(until)) min left. Feel free to close the app.")
                        .font(Typography.caption)
                        .foregroundColor(Constants.Colors.textSecondary)
                }
                Spacer()
                Button { Task { await stopLive() } } label: {
                    if isStoppingLive {
                        ProgressView().tint(Constants.Colors.textSecondary)
                    } else {
                        Text("Stop").font(.inter(13, weight: .semiBold))
                            .foregroundColor(Constants.Colors.accent)
                    }
                }
                .buttonStyle(.pressable)
                .disabled(isStoppingLive)
            }
            .padding(.horizontal, Space.lg)
            .padding(.vertical, Space.md)
            .background(Constants.Colors.success.opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
            .padding(.horizontal, Space.lg)
            .padding(.top, Space.sm)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    private func minutesLeft(_ until: Date) -> Int { max(1, Int((until.timeIntervalSinceNow / 60.0).rounded())) }

    @MainActor
    private func refreshLiveStatus() async {
        guard let me = try? await APIService.shared.fetchMe() else { return }
        withAnimation(Motion.spring) {
            if me.status == "live", let s = me.liveTTL, let ttl = ISO8601DateFormatter().date(from: s) {
                liveUntil = ttl
            } else {
                liveUntil = nil
            }
        }
    }

    @MainActor
    private func stopLive() async {
        isStoppingLive = true
        _ = try? await APIService.shared.cancelLive()
        withAnimation(Motion.spring) { liveUntil = nil }
        isStoppingLive = false
    }

    // MARK: - I'm Free

    private var imFreeSection: some View {
        VStack(spacing: Space.sm) {
            Button { navigateToLive = true } label: {
                ZStack {
                    Circle()
                        .fill(Constants.Colors.accent)
                        .frame(width: 140, height: 140)
                        .raisedElevation()
                    VStack(spacing: Space.xs) {
                        Image(systemName: "hand.wave").font(.system(size: 28, weight: .regular))
                        Text("I'm Free").font(.inter(15, weight: .semiBold))
                    }
                    .foregroundColor(Constants.Colors.onAccent)
                }
            }
            .buttonStyle(.pressableHaptic)

            Text("Tap when you have a few minutes")
                .font(Typography.caption)
                .foregroundColor(Constants.Colors.textTertiary)
        }
        .padding(.top, Space.lg)
        .padding(.bottom, 44)
    }

    // MARK: - Queue content

    @ViewBuilder
    private var queueContent: some View {
        if viewModel.isLoading && viewModel.queue.isEmpty {
            VStack(spacing: Space.sm) {
                SectionHeader(title: "Your people")
                ForEach(0..<3, id: \.self) { _ in SkeletonRow() }
                    .padding(.horizontal, Space.lg)
            }
        } else if viewModel.queue.isEmpty {
            errorSection
            EmptyStateView(
                icon: "person.2",
                title: "No one in your queue yet",
                subtitle: "Invite a friend and you'll land in each other's queue. Tap “I'm Free” and we'll connect you when you're both around.",
                actionTitle: "Send an invite",
                action: { showInviteView = true }
            )
            .padding(.top, Space.xxxl)
        } else {
            errorSection
            queueList
        }
    }

    private var queueList: some View {
        VStack(spacing: Space.xl) {
            if !viewModel.availableItems.isEmpty {
                VStack(spacing: Space.sm) {
                    SectionHeader(title: "Available")
                    rows(viewModel.availableItems)
                }
            }

            if !viewModel.caughtUpItems.isEmpty {
                VStack(spacing: Space.sm) {
                    SectionHeader(title: "Caught up", badge: viewModel.incomingCount)
                    rows(viewModel.caughtUpItems)
                }
            }

            historyLink
        }
        .padding(.top, Space.xs)
        .animation(Motion.spring, value: viewModel.queue.map(\.id))
    }

    private func rows(_ items: [QueueItem]) -> some View {
        VStack(spacing: Space.sm) {
            ForEach(items) { item in
                let id = item.catchupId
                QueueRowView(
                    item: item,
                    onRemove: { Task { await viewModel.removeFromQueue(catchupId: id) } },
                    onMoveToTop: { withAnimation(Motion.spring) { viewModel.moveToTop(catchupId: id) } },
                    onReport: { Task { await viewModel.reportUser(catchupId: id, userId: item.otherUser.userId) } },
                    onBlock: { Task { await viewModel.reportUser(catchupId: id, userId: item.otherUser.userId) } },
                    onRequestRecatch: { Task { await viewModel.requestRecatch(catchupId: id) } },
                    onAcceptRecatch: { Task { await viewModel.acceptRecatch(catchupId: id) } },
                    onDeclineRecatch: { Task { await viewModel.declineRecatch(catchupId: id) } }
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, Space.lg)
    }

    private var historyLink: some View {
        Button { showCallHistory = true } label: {
            HStack(spacing: 6) {
                Image(systemName: "clock").font(.system(size: 12, weight: .regular))
                Text("Call History").font(.inter(13, weight: .medium))
            }
            .foregroundColor(Constants.Colors.textSecondary)
            .padding(.vertical, Space.lg)
        }
        .buttonStyle(.pressable)
    }

    // MARK: - Sign out / delete

    private func signOut() { try? AuthService.shared.signOut() }

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

    @ViewBuilder
    private var errorSection: some View {
        if let errorMessage = viewModel.errorMessage {
            Text(errorMessage)
                .font(Typography.caption)
                .foregroundColor(Constants.Colors.destructive)
                .padding(.horizontal, Space.xxl)
                .padding(.top, Space.sm)
        }
    }
}

// MARK: - Live Dot (pulsing availability indicator)

struct LiveDot: View {
    @State private var pulse = false
    var body: some View {
        ZStack {
            Circle().fill(Constants.Colors.success.opacity(0.35))
                .frame(width: 16, height: 16)
                .scaleEffect(pulse ? 1.4 : 0.8)
                .opacity(pulse ? 0 : 0.8)
            Circle().fill(Constants.Colors.success).frame(width: 8, height: 8)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.4).repeatForever(autoreverses: false)) { pulse = true }
        }
    }
}

#Preview { MainView() }
