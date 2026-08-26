//
//  FriendsView.swift
//  Geolocation_v1.0.0
//
//  Created by Claude Code
//

import SwiftUI

// MARK: - Friends View

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
    @FocusState private var isSearchFocused: Bool
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ZStack {
            OrganicPalette.canvas(colorScheme)
                .ignoresSafeArea()

            if viewModel.isLoading && viewModel.friends.isEmpty && viewModel.pendingRequests.isEmpty {
                ProgressView("Loading friends...")
                    .tint(OrganicPalette.terracotta(colorScheme))
                    .foregroundColor(OrganicPalette.inkSoft(colorScheme))
            } else {
                mainContent
            }

            // Sticky banner ad above tab bar (hidden for subscribers)
            if !subscriptionManager.isSubscribed {
                VStack(spacing: 0) {
                    Spacer()
                    BannerAdView(adUnitID: kBannerAdUnitID)
                        .frame(height: 50)
                        .background(OrganicPalette.canvas(colorScheme))
                }
            }
        }
        // The screen draws its own oversized serif title, so the system bar
        // would only stack a second "Friends" above it.
        .toolbar(.hidden, for: .navigationBar)
        .tint(OrganicPalette.terracotta(colorScheme))
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
            headerSection

            // Received requests sit above everything else — they're the only
            // rows on the screen waiting on the user to do something.
            if !viewModel.filteredPendingRequests.isEmpty {
                requestsSection
            }

            if !viewModel.filteredSentRequests.isEmpty {
                sentSection
            }

            if !viewModel.filteredFamilyMembers.isEmpty || !viewModel.filteredFriends.isEmpty {
                allFriendsSection
            }

            if viewModel.hasNoSearchResults {
                noSearchResultsState
                    .organicRow()
            }

            if hasNoConnections && !viewModel.isFilteringFriends {
                emptyState
                    .padding(.top, 24)
                    .organicRow()
            }
        }
        .listStyle(.plain)
        .listSectionSpacing(20)
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.immediately)
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: subscriptionManager.isSubscribed ? 0 : 50)
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

    // MARK: - Header

    private var headerSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .center) {
                    Text("Friends")
                        .font(OrganicPalette.display(40))
                        .foregroundColor(OrganicPalette.ink(colorScheme))

                    Spacer()

                    Button(action: { showAddFriend = true }) {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 54, height: 54)
                            .background(Circle().fill(OrganicPalette.terracotta(colorScheme)))
                            .shadow(color: OrganicPalette.terracotta(colorScheme).opacity(0.35), radius: 10, x: 0, y: 5)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Add friend")
                    .tutorialHighlight(id: "tutorial_addFriend")
                }
                .padding(.top, 8)

                searchField

                if !viewModel.familyMembers.isEmpty && !viewModel.isFilteringFriends {
                    familyCard
                }
            }
            .organicRow()
        }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(OrganicPalette.inkSoft(colorScheme))

            TextField(
                "",
                text: $viewModel.searchText,
                prompt: Text("Search friends")
                    .foregroundColor(OrganicPalette.inkSoft(colorScheme).opacity(0.8))
            )
            .font(.system(size: 17))
            .foregroundColor(OrganicPalette.ink(colorScheme))
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .submitLabel(.search)
            .focused($isSearchFocused)

            if !viewModel.searchText.isEmpty {
                Button {
                    viewModel.searchText = ""
                    isSearchFocused = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(OrganicPalette.inkSoft(colorScheme).opacity(0.7))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 18)
        .frame(height: 54)
        .background(Capsule().fill(OrganicPalette.field(colorScheme)))
    }

    // MARK: - Family Card

    /// The sage summary card. Family is otherwise invisible — it only shows up
    /// as a sort order inside the share sheets — so this states what the group
    /// is for and points at the house button that edits it.
    private var familyCard: some View {
        let members = viewModel.familyMembers
        let count = members.count

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Family")
                        .font(OrganicPalette.display(26))
                        .foregroundColor(OrganicPalette.sageInk(colorScheme))

                    Text(count == 1 ? "1 person you share with first" : "\(count) people you share with first")
                        .font(.system(size: 15))
                        .foregroundColor(OrganicPalette.sageInk(colorScheme).opacity(0.75))
                }

                Spacer(minLength: 12)

                avatarStack(for: members)
            }

            Text("Shared stores and reminders reach them first. Tap the house on a friend to add or remove them.")
                .font(.system(size: 15))
                .foregroundColor(OrganicPalette.sageInk(colorScheme).opacity(0.8))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(OrganicPalette.sage(colorScheme))
        )
    }

    /// Overlapping avatars for the Family card. Four circles wide at most,
    /// counting the "+n" disc — the stack shares the title row now, so a large
    /// family has to stay inside the same width a small one takes.
    private func avatarStack(for members: [Friendship]) -> some View {
        let shown = Array(members.prefix(members.count > 4 ? 3 : 4))
        let overflow = members.count - shown.count

        return HStack(spacing: -16) {
            ForEach(shown) { friendship in
                let name = friendship.friendName(currentUserId: currentUserId)
                OrganicAvatar(
                    name: name,
                    profilePictureURL: profilePictureURL(for: friendship),
                    size: 46,
                    ringColor: OrganicPalette.sage(colorScheme)
                )
            }

            if overflow > 0 {
                Text("+\(overflow)")
                    .font(.system(size: 15, weight: .bold, design: .serif))
                    .foregroundColor(OrganicPalette.sageInk(colorScheme))
                    .frame(width: 46, height: 46)
                    .background(Circle().fill(OrganicPalette.sageInk(colorScheme).opacity(0.18)))
                    .overlay(Circle().strokeBorder(OrganicPalette.sage(colorScheme), lineWidth: 3))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(members.count) family members")
    }

    // MARK: - Requests

    private var requestsSection: some View {
        Section {
            sectionLabel(
                "Requests",
                count: viewModel.filteredPendingRequests.count,
                highlighted: true
            )

            ForEach(viewModel.filteredPendingRequests) { friendship in
                RequestCard(
                    friendship: friendship,
                    freshProfilePictureURL: viewModel.friendProfilePictures[friendship.requesterId],
                    onAccept: { viewModel.acceptRequest(friendship) },
                    onReject: { viewModel.rejectRequest(friendship) }
                )
                .organicRow()
            }
        }
    }

    private var sentSection: some View {
        Section {
            sectionLabel("Waiting on them", count: viewModel.filteredSentRequests.count)

            ForEach(viewModel.filteredSentRequests) { friendship in
                SentRequestCard(
                    friendship: friendship,
                    freshProfilePictureURL: viewModel.friendProfilePictures[friendship.receiverId],
                    onCancel: {
                        friendshipToCancel = friendship
                        showingCancelAlert = true
                    }
                )
                .organicRow()
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        friendshipToCancel = friendship
                        showingCancelAlert = true
                    } label: {
                        Label("Cancel", systemImage: "xmark")
                    }
                }
            }
        }
    }

    // MARK: - All Friends

    /// Family and friends share one list. Family members keep their own badge
    /// rather than a separate section, so the list reads as the whole address
    /// book instead of the same names split across two places.
    private var allFriendsSection: some View {
        Section {
            sectionLabel(
                "All friends",
                count: viewModel.filteredFamilyMembers.count + viewModel.filteredFriends.count
            )

            ForEach(viewModel.filteredFamilyMembers) { friendship in
                friendRow(for: friendship, isFamilyMember: true, tutorialId: nil)
            }

            ForEach(Array(viewModel.filteredFriends.enumerated()), id: \.element.id) { index, friendship in
                friendRow(
                    for: friendship,
                    isFamilyMember: false,
                    tutorialId: index == 0 ? "tutorial_friendCard" : nil
                )
            }
        }
    }

    private func friendRow(
        for friendship: Friendship,
        isFamilyMember: Bool,
        tutorialId: String?
    ) -> some View {
        FriendCard(
            friendship: friendship,
            currentUserId: currentUserId,
            isFamilyMember: isFamilyMember,
            freshProfilePictureURL: profilePictureURL(for: friendship),
            onMessage: { startConversation(with: friendship) },
            onToggleFamily: {
                if isFamilyMember {
                    viewModel.removeFromFamily(friendship)
                } else {
                    viewModel.addToFamily(friendship)
                }
            }
        )
        .organicRow()
        .tutorialHighlight(id: tutorialId ?? "noop_friend_\(friendship.id)")
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                friendshipToRemove = friendship
                showingRemoveAlert = true
            } label: {
                Label("Remove", systemImage: "person.badge.minus")
            }
        }
        // Messaging and Family both have their own button on the row, so the
        // long-press menu is left with the one action that doesn't.
        .contextMenu {
            Button(role: .destructive) {
                friendshipToRemove = friendship
                showingRemoveAlert = true
            } label: {
                Label("Remove Friend", systemImage: "person.badge.minus")
            }
        }
    }

    /// The freshly fetched picture for whoever the other party is, falling back
    /// to the copy stored on the friendship document. The stored copy goes
    /// stale when someone changes their photo, but it's what keeps avatars from
    /// flashing initials while the `users` lookup is still in flight.
    private func profilePictureURL(for friendship: Friendship) -> String? {
        let friendId = friendship.friendId(currentUserId: currentUserId)
        return viewModel.friendProfilePictures[friendId]
            ?? friendship.friendProfilePictureURL(currentUserId: currentUserId)
    }

    // MARK: - Section Label

    private func sectionLabel(_ title: String, count: Int, highlighted: Bool = false) -> some View {
        HStack(spacing: 10) {
            Text(title)
                .font(OrganicPalette.display(22))
                .foregroundColor(OrganicPalette.ink(colorScheme))

            if highlighted {
                Text("\(count)")
                    .font(.system(size: 14, weight: .bold, design: .serif))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(OrganicPalette.terracotta(colorScheme)))
            } else {
                Text("\(count)")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(OrganicPalette.inkSoft(colorScheme))
            }

            Spacer()
        }
        .organicSectionLabelRow()
    }

    // MARK: - Empty States

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "person.2")
                .font(.system(size: 44, weight: .light))
                .foregroundColor(OrganicPalette.terracotta(colorScheme).opacity(0.55))
                .frame(width: 96, height: 96)
                .background(Circle().fill(OrganicPalette.blush(colorScheme)))

            Text("No friends yet")
                .font(OrganicPalette.display(26))
                .foregroundColor(OrganicPalette.ink(colorScheme))

            Text("Add friends to share stores and reminders with the people you shop for.")
                .font(.system(size: 16))
                .foregroundColor(OrganicPalette.inkSoft(colorScheme))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            Button(action: { showAddFriend = true }) {
                Text("Add a friend")
                    .font(.system(size: 17, weight: .bold, design: .serif))
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .frame(height: 52)
                    .background(Capsule().fill(OrganicPalette.terracotta(colorScheme)))
            }
            .buttonStyle(.plain)
            .padding(.top, 4)

            Button(action: inviteFriends) {
                Text("Invite friends to Allim")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(OrganicPalette.terracotta(colorScheme))
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
    }

    private var noSearchResultsState: some View {
        VStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 30, weight: .light))
                .foregroundColor(OrganicPalette.terracotta(colorScheme).opacity(0.55))
                .frame(width: 72, height: 72)
                .background(Circle().fill(OrganicPalette.blush(colorScheme)))

            Text("No matches")
                .font(OrganicPalette.display(22))
                .foregroundColor(OrganicPalette.ink(colorScheme))

            Text("Nobody matches \u{201C}\(viewModel.searchText)\u{201D}")
                .font(.system(size: 15))
                .foregroundColor(OrganicPalette.inkSoft(colorScheme))
                .multilineTextAlignment(.center)
        }
        .padding(.top, 40)
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

// MARK: - Friend Card

struct FriendCard: View {
    let friendship: Friendship
    let currentUserId: String
    var isFamilyMember: Bool = false
    /// Fresh profile picture URL fetched from the `users` collection, overriding the stale one in the friendship doc.
    var freshProfilePictureURL: String?
    let onMessage: () -> Void
    let onToggleFamily: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    private var friendName: String {
        friendship.friendName(currentUserId: currentUserId)
    }

    private var handle: String {
        "@\(friendship.friendId(currentUserId: currentUserId))"
    }

    private var friendProfilePictureURL: String? {
        freshProfilePictureURL ?? friendship.friendProfilePictureURL(currentUserId: currentUserId)
    }

    var body: some View {
        // Two controls plus the badge leave little room for the name, so the
        // avatar and buttons run a size smaller here than elsewhere.
        HStack(spacing: 12) {
            OrganicAvatar(name: friendName, profilePictureURL: friendProfilePictureURL, size: 48)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(friendName)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(OrganicPalette.ink(colorScheme))
                        .lineLimit(1)

                    if isFamilyMember {
                        Text("FAMILY")
                            .font(.system(size: 10, weight: .bold))
                            .kerning(0.6)
                            .foregroundColor(OrganicPalette.sageInk(colorScheme))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(OrganicPalette.sage(colorScheme)))
                    }
                }

                Text(handle)
                    .font(.system(size: 14))
                    .foregroundColor(OrganicPalette.inkSoft(colorScheme))
                    .lineLimit(1)
            }

            Spacer(minLength: 6)

            HStack(spacing: 8) {
                familyButton
                messageButton
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(OrganicCardBackground(colorScheme: colorScheme))
    }

    /// Filled while they're in Family, outlined while they aren't — the icon
    /// doubles as the row's status, so tapping it is both the toggle and the
    /// only place Family membership is set.
    private var familyButton: some View {
        Button(action: onToggleFamily) {
            Image(systemName: isFamilyMember ? "house.fill" : "house")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(isFamilyMember ? .white : OrganicPalette.sageInk(colorScheme))
                .frame(width: 40, height: 40)
                .background(
                    Circle().fill(
                        isFamilyMember
                            ? OrganicPalette.sageInk(colorScheme)
                            : OrganicPalette.sage(colorScheme)
                    )
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isFamilyMember ? "Remove \(friendName) from Family" : "Add \(friendName) to Family")
    }

    private var messageButton: some View {
        Button(action: onMessage) {
            Image(systemName: "message.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(OrganicPalette.terracotta(colorScheme))
                .frame(width: 40, height: 40)
                .background(Circle().fill(OrganicPalette.blush(colorScheme)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Message \(friendName)")
    }
}

// MARK: - Request Card

/// An incoming friend request. It sits on the blush tint rather than the plain
/// paper surface so the rows that need an answer stand out from the ones that
/// don't, and it leads with a full Accept pill because that's the likely answer.
struct RequestCard: View {
    let friendship: Friendship
    var freshProfilePictureURL: String?
    let onAccept: () -> Void
    let onReject: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    private var requesterPictureURL: String? {
        freshProfilePictureURL ?? friendship.requesterProfilePictureURL
    }

    var body: some View {
        HStack(spacing: 14) {
            OrganicAvatar(
                name: friendship.requesterName,
                profilePictureURL: requesterPictureURL
            )

            VStack(alignment: .leading, spacing: 3) {
                Text(friendship.requesterName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(OrganicPalette.ink(colorScheme))
                    .lineLimit(1)

                Text("wants to share lists")
                    .font(.system(size: 14))
                    .foregroundColor(OrganicPalette.inkSoft(colorScheme))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .layoutPriority(1)

            Spacer(minLength: 6)

            HStack(spacing: 6) {
                Button(action: onAccept) {
                    Text("Accept")
                        .font(.system(size: 15, weight: .bold, design: .serif))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .frame(height: 42)
                        .background(Capsule().fill(OrganicPalette.terracotta(colorScheme)))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Accept request from \(friendship.requesterName)")

                Button(action: onReject) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(OrganicPalette.inkSoft(colorScheme))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Circle().stroke(OrganicPalette.outline(colorScheme), lineWidth: 1.5)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Decline request from \(friendship.requesterName)")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            OrganicCardBackground(colorScheme: colorScheme, fill: OrganicPalette.blush(colorScheme))
        )
    }
}

// MARK: - Sent Request Card

/// A request the user sent that hasn't been answered. Nothing to act on, so it
/// stays quiet: no card fill, just an outline and the cancel affordance.
struct SentRequestCard: View {
    let friendship: Friendship
    var freshProfilePictureURL: String?
    let onCancel: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    private var receiverPictureURL: String? {
        freshProfilePictureURL ?? friendship.receiverProfilePictureURL
    }

    var body: some View {
        HStack(spacing: 14) {
            OrganicAvatar(
                name: friendship.receiverName,
                profilePictureURL: receiverPictureURL,
                size: 46
            )
            .opacity(0.6)

            VStack(alignment: .leading, spacing: 3) {
                Text(friendship.receiverName)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(OrganicPalette.ink(colorScheme).opacity(0.8))
                    .lineLimit(1)

                Text("Request sent")
                    .font(.system(size: 14))
                    .foregroundColor(OrganicPalette.inkSoft(colorScheme))
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Button(action: onCancel) {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(OrganicPalette.inkSoft(colorScheme))
                    .frame(width: 38, height: 38)
                    .overlay(
                        Circle().stroke(OrganicPalette.outline(colorScheme), lineWidth: 1.5)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Cancel request to \(friendship.receiverName)")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(OrganicPalette.outline(colorScheme).opacity(0.7), lineWidth: 1.5)
        )
    }
}

// MARK: - Add Friend View

struct AddFriendView: View {
    @ObservedObject var viewModel: FriendsViewModel
    @ObservedObject private var sessionManager = UserSessionManager.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var searchQuery = ""
    @FocusState private var isQueryFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                OrganicPalette.canvas(colorScheme)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Add a friend")
                            .font(OrganicPalette.display(32))
                            .foregroundColor(OrganicPalette.ink(colorScheme))
                            .padding(.top, 8)

                        Text("Search by email address or username to send them a request.")
                            .font(.system(size: 16))
                            .foregroundColor(OrganicPalette.inkSoft(colorScheme))

                        queryField

                        if let contact = viewModel.searchedUser {
                            SearchResultCard(
                                contact: contact,
                                viewModel: viewModel,
                                onAdd: { viewModel.sendFriendRequest(to: contact) }
                            )
                        } else if !searchQuery.isEmpty && !viewModel.isSearching {
                            Text("No user found")
                                .font(.system(size: 15))
                                .foregroundColor(OrganicPalette.inkSoft(colorScheme))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 24)
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .scrollDismissesKeyboard(.immediately)
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(OrganicPalette.canvas(colorScheme), for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(OrganicPalette.terracotta(colorScheme))
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

    private var queryField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(OrganicPalette.inkSoft(colorScheme))

            TextField(
                "",
                text: $searchQuery,
                prompt: Text("Email or username")
                    .foregroundColor(OrganicPalette.inkSoft(colorScheme).opacity(0.8))
            )
            .font(.system(size: 17))
            .foregroundColor(OrganicPalette.ink(colorScheme))
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .submitLabel(.search)
            .focused($isQueryFocused)
            .onSubmit { runSearch() }

            if viewModel.isSearching {
                ProgressView()
                    .tint(OrganicPalette.terracotta(colorScheme))
            } else {
                Button(action: runSearch) {
                    Text("Search")
                        .font(.system(size: 15, weight: .bold, design: .serif))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .frame(height: 38)
                        .background(Capsule().fill(OrganicPalette.terracotta(colorScheme)))
                }
                .buttonStyle(.plain)
                .disabled(searchQuery.isEmpty)
                .opacity(searchQuery.isEmpty ? 0.4 : 1)
            }
        }
        .padding(.leading, 18)
        .padding(.trailing, 8)
        .frame(height: 56)
        .background(Capsule().fill(OrganicPalette.field(colorScheme)))
    }

    private func runSearch() {
        guard !searchQuery.isEmpty else { return }
        isQueryFocused = false
        viewModel.searchUser(query: searchQuery)
    }
}

// MARK: - Search Result Card

struct SearchResultCard: View {
    let contact: Contact
    @ObservedObject var viewModel: FriendsViewModel
    let onAdd: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 14) {
            OrganicAvatar(name: contact.name, profilePictureURL: contact.profilePictureURL)

            VStack(alignment: .leading, spacing: 3) {
                Text(contact.name)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(OrganicPalette.ink(colorScheme))
                    .lineLimit(1)

                Text(contact.email)
                    .font(.system(size: 14))
                    .foregroundColor(OrganicPalette.inkSoft(colorScheme))
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            addButton
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(OrganicCardBackground(colorScheme: colorScheme))
    }

    @ViewBuilder
    private var addButton: some View {
        let relationship = viewModel.getRelationshipStatus(with: contact.id)

        if relationship.exists {
            switch relationship.status {
            case .accepted:
                statusPill("Friends", tint: OrganicPalette.sageInk(colorScheme), fill: OrganicPalette.sage(colorScheme))
            case .pending:
                if relationship.isSentByMe {
                    statusPill(
                        "Pending",
                        tint: OrganicPalette.inkSoft(colorScheme),
                        fill: OrganicPalette.field(colorScheme)
                    )
                } else {
                    statusPill(
                        "Respond",
                        tint: OrganicPalette.terracotta(colorScheme),
                        fill: OrganicPalette.blush(colorScheme)
                    )
                }
            case .rejected, .none:
                addFriendButton
            }
        } else {
            addFriendButton
        }
    }

    private func statusPill(_ title: String, tint: Color, fill: Color) -> some View {
        Text(title)
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(tint)
            .padding(.horizontal, 14)
            .frame(height: 38)
            .background(Capsule().fill(fill))
    }

    private var addFriendButton: some View {
        Button(action: onAdd) {
            Text("Add")
                .font(.system(size: 15, weight: .bold, design: .serif))
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .frame(height: 38)
                .background(Capsule().fill(OrganicPalette.terracotta(colorScheme)))
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
