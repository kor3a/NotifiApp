//
//  FriendsView.swift
//  Geolocation_v1.0.0
//
//  Created by Claude Code
//

import SwiftUI

struct FriendsView: View {
    @StateObject private var viewModel = FriendsViewModel()
    @ObservedObject var messagesViewModel: MessagesViewModel
    @ObservedObject private var sessionManager = UserSessionManager.shared
    @ObservedObject private var subscriptionManager = SubscriptionManager.shared
    @ObservedObject private var tutorialManager = TutorialManager.shared
    @State private var showAddFriend = false
    @State private var selectedFriendForMessage: Contact?
    @State private var selectedConversation: Conversation?
    @State private var friendshipToRemove: Friendship?
    @State private var showingRemoveAlert = false
    @State private var friendshipToCancel: Friendship?
    @State private var showingCancelAlert = false
    @State private var showInviteAlert = false
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ZStack {
            Color.backgroundGradient(for: colorScheme)
                .ignoresSafeArea()

            if viewModel.isLoading && viewModel.friends.isEmpty && viewModel.pendingRequests.isEmpty {
                ProgressView("Loading friends...")
            } else {
                mainContent
            }

            // Sticky banner ad above tab bar (hidden for subscribers)
            if !subscriptionManager.isSubscribed {
                VStack(spacing: 0) {
                    Spacer()
                    BannerAdView(adUnitID: kBannerAdUnitID)
                        .frame(height: 50)
                        .background(Color(.systemBackground).opacity(0.95))
                }
            }
        }
        .navigationTitle("Friends")
        .searchable(text: $viewModel.searchText, prompt: "Search friends")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showAddFriend = true }) {
                    Image(systemName: "person.badge.plus")
                }
                .tutorialHighlight(id: "tutorial_addFriend")
            }
        }
        .sheet(isPresented: $showAddFriend) {
            AddFriendView(viewModel: viewModel)
        }
        .navigationDestination(item: $selectedConversation) { conversation in
            ConversationView(conversation: conversation, viewModel: messagesViewModel)
        }
        .onAppear {
            viewModel.fetchFriendships()
            viewModel.fetchPendingRequestCount()
        }
        .onDisappear {
            viewModel.stopListening()
        }
        .alert("Success", isPresented: .init(
            get: { viewModel.successMessage != nil },
            set: { if !$0 { viewModel.clearMessages() } }
        )) {
            Button("OK") { viewModel.clearMessages() }
        } message: {
            Text(viewModel.successMessage ?? "")
        }
        .alert("Error", isPresented: .init(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.clearMessages() } }
        )) {
            Button("OK") { viewModel.clearMessages() }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .alert("Remove Friend", isPresented: $showingRemoveAlert) {
            Button("Cancel", role: .cancel) {
                friendshipToRemove = nil
            }
            Button("Remove", role: .destructive) {
                if let friendship = friendshipToRemove {
                    viewModel.removeFriend(friendship)
                    friendshipToRemove = nil
                }
            }
        } message: {
            if let friendship = friendshipToRemove {
                Text("Are you sure you want to remove \(friendship.friendName(currentUserId: sessionManager.currentUser?.userId ?? "")) from your friends? Any stores shared between you will be unshared.")
            } else {
                Text("Are you sure you want to remove this friend?")
            }
        }
        .alert("Invite Friends", isPresented: $showInviteAlert) {
            Button("OK") { }
        } message: {
            Text(AppInvite.linkCopiedMessage)
        }
        .alert("Cancel Request", isPresented: $showingCancelAlert) {
            Button("No", role: .cancel) {
                friendshipToCancel = nil
            }
            Button("Yes, Cancel", role: .destructive) {
                if let friendship = friendshipToCancel {
                    viewModel.cancelRequest(friendship)
                    friendshipToCancel = nil
                }
            }
        } message: {
            if let friendship = friendshipToCancel {
                Text("Cancel your friend request to \(friendship.receiverName)?")
            } else {
                Text("Cancel this friend request?")
            }
        }
    }

    // MARK: - Main Content

    private var mainContent: some View {
        List {
            // Pending requests sit at the top — received first, then the ones
            // we sent and are still waiting on.
            if !viewModel.filteredPendingRequests.isEmpty || !viewModel.filteredSentRequests.isEmpty {
                pendingSection
            }

            if !viewModel.filteredFamilyMembers.isEmpty {
                familySection
            }

            if !viewModel.filteredFriends.isEmpty {
                friendsSection
            }

            if viewModel.hasNoSearchResults {
                noSearchResultsState
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }

            if hasNoConnections && !viewModel.isFilteringFriends {
                emptyState
                    .padding(.top, 40)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: 50)
        }
    }

    /// True when the user has no friends, family or requests at all.
    private var hasNoConnections: Bool {
        viewModel.friends.isEmpty
            && viewModel.familyMembers.isEmpty
            && viewModel.pendingRequests.isEmpty
            && viewModel.sentRequests.isEmpty
    }

    private var currentUserId: String {
        sessionManager.currentUser?.userId ?? ""
    }

    // MARK: - Pending Section

    private var pendingSection: some View {
        Section {
            ForEach(viewModel.filteredPendingRequests) { friendship in
                PendingRequestRow(
                    friendship: friendship,
                    freshProfilePictureURL: viewModel.friendProfilePictures[friendship.requesterId],
                    onAccept: { viewModel.acceptRequest(friendship) },
                    onReject: { viewModel.rejectRequest(friendship) }
                )
                .modifier(FriendListRowStyle(
                    colorScheme: colorScheme,
                    borderStyle: AnyShapeStyle(Color.appWarning.opacity(0.3))
                ))
            }

            ForEach(viewModel.filteredSentRequests) { friendship in
                SentRequestRow(
                    friendship: friendship,
                    freshProfilePictureURL: viewModel.friendProfilePictures[friendship.receiverId],
                    onCancel: {
                        friendshipToCancel = friendship
                        showingCancelAlert = true
                    }
                )
                .modifier(FriendListRowStyle(colorScheme: colorScheme))
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        friendshipToCancel = friendship
                        showingCancelAlert = true
                    } label: {
                        Label("Cancel", systemImage: "xmark")
                    }
                }
            }
        } header: {
            sectionHeader(
                title: "Pending",
                systemImage: "clock.fill",
                tint: .appWarning,
                count: viewModel.filteredPendingRequests.count + viewModel.filteredSentRequests.count,
                highlightCount: !viewModel.filteredPendingRequests.isEmpty
            )
        }
    }

    // MARK: - Family Section

    private var familySection: some View {
        Section {
            ForEach(viewModel.filteredFamilyMembers) { friendship in
                friendRow(for: friendship, isFamilyMember: true)
            }
        } header: {
            sectionHeader(
                title: "Family",
                systemImage: "house.fill",
                tint: .purple,
                count: viewModel.filteredFamilyMembers.count
            )
        }
    }

    // MARK: - Friends Section

    private var friendsSection: some View {
        Section {
            ForEach(Array(viewModel.filteredFriends.enumerated()), id: \.element.id) { index, friendship in
                friendRow(for: friendship, isFamilyMember: false)
                    .tutorialHighlight(id: index == 0 ? "tutorial_friendCard" : "noop_friend_\(index)")
            }
        } header: {
            sectionHeader(
                title: "Friends",
                systemImage: "person.2.fill",
                tint: .blue,
                count: viewModel.filteredFriends.count
            )
        }
    }

    // MARK: - Friend Row

    private func friendRow(for friendship: Friendship, isFamilyMember: Bool) -> some View {
        let friendId = friendship.friendId(currentUserId: currentUserId)

        return FriendRow(
            friendship: friendship,
            currentUserId: currentUserId,
            isFamilyMember: isFamilyMember,
            freshProfilePictureURL: viewModel.friendProfilePictures[friendId],
            onMessage: { startConversation(with: friendship) },
            onAddToFamily: { viewModel.addToFamily(friendship) },
            onRemoveFromFamily: { viewModel.removeFromFamily(friendship) }
        )
        .modifier(FriendListRowStyle(
            colorScheme: colorScheme,
            borderStyle: isFamilyMember
                ? AnyShapeStyle(LinearGradient(
                    colors: [Color.purple.opacity(0.4), Color.purple.opacity(0.15)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                : nil
        ))
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                friendshipToRemove = friendship
                showingRemoveAlert = true
            } label: {
                Label("Remove", systemImage: "person.badge.minus")
            }
        }
        .contextMenu {
            Button {
                startConversation(with: friendship)
            } label: {
                Label("Message", systemImage: "message.fill")
            }

            if isFamilyMember {
                Button {
                    viewModel.removeFromFamily(friendship)
                } label: {
                    Label("Remove from Family", systemImage: "house.slash.fill")
                }
            } else {
                Button {
                    viewModel.addToFamily(friendship)
                } label: {
                    Label("Add to Family", systemImage: "house.fill")
                }
            }

            Button(role: .destructive) {
                friendshipToRemove = friendship
                showingRemoveAlert = true
            } label: {
                Label("Remove Friend", systemImage: "person.badge.minus")
            }
        }
    }

    // MARK: - Section Header

    private func sectionHeader(
        title: String,
        systemImage: String,
        tint: Color,
        count: Int,
        highlightCount: Bool = false
    ) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.caption)
                .foregroundColor(tint)

            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)

            if highlightCount {
                Text("\(count)")
                    .font(.caption.bold())
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.appAccent)
                    .clipShape(Capsule())
            } else {
                Text("\(count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .textCase(nil)
        .padding(.vertical, 4)
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 4, trailing: 16))
    }

    // MARK: - Empty States

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.2")
                .resizable()
                .scaledToFit()
                .frame(width: 60, height: 60)
                .foregroundStyle(.gray)

            Text("No Friends Yet")
                .font(.title2)
                .bold()

            Text("Add friends to easily share stores and reminders")
                .foregroundStyle(.gray)
                .multilineTextAlignment(.center)

            Button(action: { showAddFriend = true }) {
                Label("Add Friend", systemImage: "person.badge.plus")
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal, 40)

            Button(action: inviteFriends) {
                Label("Invite Friends", systemImage: "envelope.open.fill")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.appAccent)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
    }

    private var noSearchResultsState: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 36))
                .foregroundStyle(.gray)

            Text("No Matches")
                .font(.headline)

            Text("No friends match \u{201C}\(viewModel.searchText)\u{201D}")
                .font(.subheadline)
                .foregroundStyle(.gray)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 60)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Actions

    /// Copies Allim's App Store link so the user can invite friends who don't have the app yet.
    private func inviteFriends() {
        AppInvite.copyLinkToClipboard()
        showInviteAlert = true
    }

    private func startConversation(with friendship: Friendship) {
        guard let userId = sessionManager.currentUser?.userId,
              let userName = sessionManager.currentUser?.name else { return }

        let contact = friendship.toContact(currentUserId: userId)

        messagesViewModel.startConversation(with: contact, currentUserName: userName) { conversation in
            if let conversation = conversation {
                selectedConversation = conversation
            }
        }
    }
}

// MARK: - List Row Style

/// Shared card styling for the rows of the Friends list.
private struct FriendListRowStyle: ViewModifier {
    let colorScheme: ColorScheme
    /// Border stroke; falls back to the standard card border when nil.
    var borderStyle: AnyShapeStyle?

    func body(content: Content) -> some View {
        content
            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
            .listRowSeparator(.hidden)
            .listRowBackground(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                borderStyle ?? AnyShapeStyle(Color.cardBorder(for: colorScheme)),
                                lineWidth: 1.5
                            )
                    )
                    .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.08), radius: 8, x: 0, y: 4)
                    .padding(.vertical, 4)
            )
    }
}

// MARK: - Friend Row

struct FriendRow: View {
    let friendship: Friendship
    let currentUserId: String
    var isFamilyMember: Bool = false
    /// Fresh profile picture URL fetched from the `users` collection, overriding the stale one in the friendship doc.
    var freshProfilePictureURL: String?
    let onMessage: () -> Void
    var onAddToFamily: (() -> Void)?
    var onRemoveFromFamily: (() -> Void)?

    private var friendName: String {
        friendship.friendName(currentUserId: currentUserId)
    }

    private var friendUserId: String {
        "@\(friendship.friendId(currentUserId: currentUserId))"
    }

    private var avatarInitial: String {
        String(friendName.prefix(1)).uppercased()
    }

    private var avatarColor: Color {
        let colors: [Color] = [.blue, .purple, .pink, .orange, .teal, .indigo, .mint, .cyan]
        let index = abs(friendName.hashValue) % colors.count
        return colors[index]
    }

    private var friendProfilePictureURL: String? {
        freshProfilePictureURL ?? friendship.friendProfilePictureURL(currentUserId: currentUserId)
    }

    var body: some View {
        HStack(spacing: 12) {
            ProfilePictureView(profilePictureURL: friendProfilePictureURL, size: 48) {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [avatarColor.opacity(0.7), avatarColor],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 48, height: 48)
                    .overlay(
                        Text(avatarInitial)
                            .font(.headline)
                            .foregroundColor(.white)
                    )
            }
            .shadow(color: avatarColor.opacity(0.3), radius: 4, x: 0, y: 2)

            VStack(alignment: .leading, spacing: 2) {
                Text(friendName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(friendUserId)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            HStack(spacing: 8) {
                // Family toggle — filled while they're in Family, outlined otherwise.
                Button {
                    if isFamilyMember {
                        onRemoveFromFamily?()
                    } else {
                        onAddToFamily?()
                    }
                } label: {
                    Image(systemName: isFamilyMember ? "house.fill" : "house")
                        .font(.caption)
                        .foregroundColor(isFamilyMember ? .white : .purple)
                        .frame(width: 32, height: 32)
                        .background(isFamilyMember ? Color.purple : Color.purple.opacity(0.12))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isFamilyMember ? "Remove \(friendName) from Family" : "Add \(friendName) to Family")

                Button(action: onMessage) {
                    Image(systemName: "message.fill")
                        .font(.caption)
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                        .background(Color.appAccent)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Message \(friendName)")
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
    }
}

// MARK: - Pending Request Row

struct PendingRequestRow: View {
    let friendship: Friendship
    var freshProfilePictureURL: String?
    let onAccept: () -> Void
    let onReject: () -> Void

    private var requesterPictureURL: String? {
        freshProfilePictureURL ?? friendship.requesterProfilePictureURL
    }

    var body: some View {
        HStack(spacing: 12) {
            ProfilePictureView(profilePictureURL: requesterPictureURL, size: 48) {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.appWarning.opacity(0.6), Color.appWarning],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 48, height: 48)
                    .overlay(
                        Text(String(friendship.requesterName.prefix(1)).uppercased())
                            .font(.headline)
                            .foregroundColor(.white)
                    )
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(friendship.requesterName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text("wants to be friends")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            HStack(spacing: 8) {
                Button(action: onReject) {
                    Image(systemName: "xmark")
                        .font(.caption.bold())
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                        .background(Color.appError.opacity(0.85))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

                Button(action: onAccept) {
                    Image(systemName: "checkmark")
                        .font(.caption.bold())
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                        .background(Color.appSuccess)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
    }
}

// MARK: - Sent Request Row

struct SentRequestRow: View {
    let friendship: Friendship
    var freshProfilePictureURL: String?
    let onCancel: () -> Void

    private var receiverPictureURL: String? {
        freshProfilePictureURL ?? friendship.receiverProfilePictureURL
    }

    var body: some View {
        HStack(spacing: 12) {
            ProfilePictureView(profilePictureURL: receiverPictureURL, size: 48) {
                Circle()
                    .fill(Color.secondary.opacity(0.2))
                    .frame(width: 48, height: 48)
                    .overlay(
                        Text(String(friendship.receiverName.prefix(1)).uppercased())
                            .font(.headline)
                            .foregroundColor(.secondary)
                    )
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(friendship.receiverName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                HStack(spacing: 3) {
                    Image(systemName: "clock")
                        .font(.system(size: 9))
                    Text("Request sent")
                        .font(.caption2)
                }
                .foregroundColor(.secondary)
            }

            Spacer(minLength: 8)

            Button(action: onCancel) {
                Image(systemName: "xmark")
                    .font(.caption2.bold())
                    .foregroundColor(.appError)
                    .frame(width: 32, height: 32)
                    .background(Color.appError.opacity(0.1))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
    }
}

// MARK: - Add Friend View

struct AddFriendView: View {
    @ObservedObject var viewModel: FriendsViewModel
    @ObservedObject private var sessionManager = UserSessionManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var searchQuery = ""

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        TextField("Enter email or username", text: $searchQuery)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()

                        if viewModel.isSearching {
                            ProgressView()
                        } else {
                            Button("Search") {
                                viewModel.searchUser(query: searchQuery)
                            }
                            .disabled(searchQuery.isEmpty)
                        }
                    }
                } header: {
                    Text("Find Friends")
                } footer: {
                    Text("Search by email address or username")
                }

                if let contact = viewModel.searchedUser {
                    Section("Search Result") {
                        SearchResultRow(
                            contact: contact,
                            viewModel: viewModel,
                            onAdd: {
                                viewModel.sendFriendRequest(to: contact)
                            }
                        )
                    }
                } else if !searchQuery.isEmpty && !viewModel.isSearching {
                    Section {
                        HStack {
                            Image(systemName: "person.slash")
                                .foregroundColor(.secondary)
                            Text("No user found")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Add Friend")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Success", isPresented: .init(
                get: { viewModel.successMessage != nil },
                set: { if !$0 { viewModel.clearMessages(); dismiss() } }
            )) {
                Button("OK") {
                    viewModel.clearMessages()
                    dismiss()
                }
            } message: {
                Text(viewModel.successMessage ?? "")
            }
            .alert("Error", isPresented: .init(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.clearMessages() } }
            )) {
                Button("OK") { viewModel.clearMessages() }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }
}

// MARK: - Search Result Row

struct SearchResultRow: View {
    let contact: Contact
    @ObservedObject var viewModel: FriendsViewModel
    let onAdd: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ProfilePictureView(profilePictureURL: contact.profilePictureURL, size: 50) {
                Circle()
                    .fill(Color.appAccent.opacity(0.2))
                    .frame(width: 50, height: 50)
                    .overlay(
                        Text(String(contact.name.prefix(1)).uppercased())
                            .font(.headline)
                            .foregroundColor(.appAccent)
                    )
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(contact.name)
                    .font(.headline)
                    .lineLimit(1)

                Text(contact.email)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            addButton
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var addButton: some View {
        let relationship = viewModel.getRelationshipStatus(with: contact.id)

        if relationship.exists {
            switch relationship.status {
            case .accepted:
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Friends")
                }
                .font(.caption)
                .foregroundColor(.appSuccess)
            case .pending:
                if relationship.isSentByMe {
                    Text("Pending")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(Capsule())
                } else {
                    Text("Respond")
                        .font(.caption)
                        .foregroundColor(.appWarning)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.appWarning.opacity(0.1))
                        .clipShape(Capsule())
                }
            case .rejected, .none:
                addFriendButton
            }
        } else {
            addFriendButton
        }
    }

    private var addFriendButton: some View {
        Button(action: onAdd) {
            HStack(spacing: 4) {
                Image(systemName: "person.badge.plus")
                Text("Add")
            }
            .font(.caption)
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.appAccent)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isLoading)
    }
}

#Preview {
    NavigationStack {
        FriendsView(messagesViewModel: MessagesViewModel())
    }
}
