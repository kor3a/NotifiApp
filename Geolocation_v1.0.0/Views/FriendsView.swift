//
//  FriendsView.swift
//  Geolocation_v1.0.0
//
//  Created by Claude Code
//

import SwiftUI

// MARK: - Friends Palette

/// The Friends tab runs on its own warm, paper-toned palette instead of the
/// app's cool default gradient. The screen is about people rather than data, so
/// it uses a cream canvas, a terracotta accent and a sage green for Family —
/// the system blue and the frosted material cards read as clinical beside the
/// soft, rounded shapes the rest of this screen is built from.
enum FriendsPalette {
    /// Full-bleed paper backdrop behind the whole tab.
    static func canvas(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.10, green: 0.09, blue: 0.08)
            : Color(red: 0.95, green: 0.91, blue: 0.84)
    }

    /// Card and row surfaces — a shade lifted off the canvas, no border needed.
    static func surface(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.15, green: 0.13, blue: 0.11)
            : Color(red: 0.98, green: 0.96, blue: 0.93)
    }

    /// The recessed search pill — sunk into the canvas rather than raised off it.
    static func field(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.18, green: 0.16, blue: 0.14)
            : Color(red: 0.91, green: 0.87, blue: 0.82)
    }

    static func ink(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.95, green: 0.91, blue: 0.84)
            : Color(red: 0.14, green: 0.12, blue: 0.10)
    }

    static func inkSoft(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.66, green: 0.60, blue: 0.53)
            : Color(red: 0.42, green: 0.36, blue: 0.30)
    }

    /// Primary accent — the add button, request badges, action glyphs.
    static func terracotta(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.85, green: 0.48, blue: 0.27)
            : Color(red: 0.74, green: 0.39, blue: 0.19)
    }

    /// Tinted wash of the accent, for request cards and quiet icon buttons.
    static func blush(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.21, green: 0.14, blue: 0.10)
            : Color(red: 0.98, green: 0.92, blue: 0.87)
    }

    /// Family's own accent. Family is a warmer, closer relationship than a
    /// plain friendship, so it gets the one non-terracotta hue on the screen.
    static func sage(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.15, green: 0.21, blue: 0.12)
            : Color(red: 0.85, green: 0.91, blue: 0.78)
    }

    static func sageInk(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.78, green: 0.86, blue: 0.68)
            : Color(red: 0.18, green: 0.29, blue: 0.13)
    }

    /// Hairline used to outline the ghost buttons that sit on tinted cards.
    static func outline(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.16) : Color.black.opacity(0.14)
    }

    /// Cards sit on paper, so their shadow is a warm brown rather than black.
    static func shadow(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color.black.opacity(0.40)
            : Color(red: 0.35, green: 0.22, blue: 0.10).opacity(0.10)
    }

    /// Display type for titles and section headers. The serif is what makes the
    /// screen read as organic rather than as another system list.
    static func display(_ size: CGFloat) -> Font {
        .system(size: size, weight: .heavy, design: .serif)
    }
}

// MARK: - Avatar Tints

/// A fill and its matching glyph color, picked together so the initial always
/// has contrast — a light peach circle needs dark type, a saturated terracotta
/// one needs white.
struct FriendsAvatarTint {
    let fill: Color
    let glyph: Color

    /// The muted, earthy set the avatars cycle through, chosen by name so a
    /// given friend keeps the same color between launches.
    static let all: [FriendsAvatarTint] = [
        FriendsAvatarTint(
            fill: Color(red: 0.96, green: 0.73, blue: 0.59),
            glyph: Color(red: 0.55, green: 0.26, blue: 0.11)
        ),
        FriendsAvatarTint(
            fill: Color(red: 0.64, green: 0.74, blue: 0.53),
            glyph: Color(red: 0.15, green: 0.25, blue: 0.10)
        ),
        FriendsAvatarTint(
            fill: Color(red: 0.78, green: 0.75, blue: 0.68),
            glyph: Color(red: 0.28, green: 0.24, blue: 0.19)
        ),
        FriendsAvatarTint(
            fill: Color(red: 0.79, green: 0.45, blue: 0.24),
            glyph: .white
        ),
        FriendsAvatarTint(
            fill: Color(red: 0.87, green: 0.68, blue: 0.40),
            glyph: Color(red: 0.40, green: 0.25, blue: 0.07)
        ),
        FriendsAvatarTint(
            fill: Color(red: 0.55, green: 0.62, blue: 0.44),
            glyph: .white
        ),
    ]

    static func forName(_ name: String) -> FriendsAvatarTint {
        // `hashValue` is seeded per launch, so sum the scalars instead — the
        // same name has to land on the same color every time the app opens.
        let seed = name.unicodeScalars.reduce(0) { $0 &+ Int($1.value) }
        return all[seed % all.count]
    }
}

// MARK: - Organic Avatar

/// The round avatar used everywhere on this screen: a profile photo when we
/// have one, otherwise a tinted circle carrying the first initial.
struct OrganicAvatar: View {
    let name: String
    let profilePictureURL: String?
    var size: CGFloat = 52
    /// Ring drawn around the circle. Used by the stacked avatars on the Family
    /// card so overlapping circles stay separated.
    var ringColor: Color?

    private var tint: FriendsAvatarTint {
        FriendsAvatarTint.forName(name)
    }

    private var initial: String {
        String(name.trimmingCharacters(in: .whitespaces).prefix(1)).uppercased()
    }

    var body: some View {
        ProfilePictureView(profilePictureURL: profilePictureURL, size: size) {
            Circle()
                .fill(tint.fill)
                .frame(width: size, height: size)
                .overlay(
                    Text(initial)
                        .font(.system(size: size * 0.42, weight: .bold, design: .serif))
                        .foregroundColor(tint.glyph)
                )
        }
        .overlay(
            Circle().strokeBorder(ringColor ?? .clear, lineWidth: ringColor == nil ? 0 : 3)
        )
    }
}

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
    /// While on, every friend row swaps its message button for a Family toggle.
    /// The Family card's "Manage" button drives it, so adding and removing
    /// people happens in the same list they're already looking at.
    @State private var isManagingFamily = false
    @FocusState private var isSearchFocused: Bool
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ZStack {
            FriendsPalette.canvas(colorScheme)
                .ignoresSafeArea()

            if viewModel.isLoading && viewModel.friends.isEmpty && viewModel.pendingRequests.isEmpty {
                ProgressView("Loading friends...")
                    .tint(FriendsPalette.terracotta(colorScheme))
                    .foregroundColor(FriendsPalette.inkSoft(colorScheme))
            } else {
                mainContent
            }

            // Sticky banner ad above tab bar (hidden for subscribers)
            if !subscriptionManager.isSubscribed {
                VStack(spacing: 0) {
                    Spacer()
                    BannerAdView(adUnitID: kBannerAdUnitID)
                        .frame(height: 50)
                        .background(FriendsPalette.canvas(colorScheme))
                }
            }
        }
        // The screen draws its own oversized serif title, so the system bar
        // would only stack a second "Friends" above it.
        .toolbar(.hidden, for: .navigationBar)
        .tint(FriendsPalette.terracotta(colorScheme))
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
        .onChange(of: viewModel.familyMembers.isEmpty) { _, isEmpty in
            // The Manage toggle lives on the Family card; once the last member
            // is removed that card goes away and nothing could switch it back.
            if isEmpty { isManagingFamily = false }
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
                    .plainRow()
            }

            if hasNoConnections && !viewModel.isFilteringFriends {
                emptyState
                    .padding(.top, 24)
                    .plainRow()
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
                        .font(FriendsPalette.display(40))
                        .foregroundColor(FriendsPalette.ink(colorScheme))

                    Spacer()

                    Button(action: { showAddFriend = true }) {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 54, height: 54)
                            .background(Circle().fill(FriendsPalette.terracotta(colorScheme)))
                            .shadow(color: FriendsPalette.terracotta(colorScheme).opacity(0.35), radius: 10, x: 0, y: 5)
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
            .plainRow()
        }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(FriendsPalette.inkSoft(colorScheme))

            TextField(
                "",
                text: $viewModel.searchText,
                prompt: Text("Search friends")
                    .foregroundColor(FriendsPalette.inkSoft(colorScheme).opacity(0.8))
            )
            .font(.system(size: 17))
            .foregroundColor(FriendsPalette.ink(colorScheme))
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
                        .foregroundColor(FriendsPalette.inkSoft(colorScheme).opacity(0.7))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 18)
        .frame(height: 54)
        .background(Capsule().fill(FriendsPalette.field(colorScheme)))
    }

    // MARK: - Family Card

    /// The sage summary card. Family is otherwise invisible — it only shows up
    /// as a sort order inside the share sheets — so this states what the group
    /// is for and gives it one place to be edited from.
    private var familyCard: some View {
        let members = viewModel.familyMembers
        let count = members.count

        return VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Family")
                        .font(FriendsPalette.display(26))
                        .foregroundColor(FriendsPalette.sageInk(colorScheme))

                    Text(count == 1 ? "1 person you share with first" : "\(count) people you share with first")
                        .font(.system(size: 15))
                        .foregroundColor(FriendsPalette.sageInk(colorScheme).opacity(0.75))
                }

                Spacer(minLength: 12)

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isManagingFamily.toggle()
                    }
                } label: {
                    Text(isManagingFamily ? "Done" : "Manage")
                        .font(.system(size: 15, weight: .bold, design: .serif))
                        .foregroundColor(FriendsPalette.sageInk(colorScheme))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(isManagingFamily ? FriendsPalette.sageInk(colorScheme).opacity(0.15) : .clear)
                        )
                        .overlay(
                            Capsule().stroke(FriendsPalette.sageInk(colorScheme).opacity(0.35), lineWidth: 1.5)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isManagingFamily ? "Finish managing Family" : "Manage Family")
            }

            HStack(spacing: 14) {
                avatarStack(for: members)

                Text(isManagingFamily
                     ? "Tap the house on any friend to add or remove them."
                     : "Shared stores and reminders reach them first.")
                    .font(.system(size: 15))
                    .foregroundColor(FriendsPalette.sageInk(colorScheme).opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(FriendsPalette.sage(colorScheme))
        )
    }

    /// Overlapping avatars for the Family card, capped at four with a "+n" disc
    /// so a large family doesn't run off the edge of the card.
    private func avatarStack(for members: [Friendship]) -> some View {
        let shown = Array(members.prefix(4))
        let overflow = members.count - shown.count

        return HStack(spacing: -16) {
            ForEach(shown) { friendship in
                let name = friendship.friendName(currentUserId: currentUserId)
                OrganicAvatar(
                    name: name,
                    profilePictureURL: profilePictureURL(for: friendship),
                    size: 46,
                    ringColor: FriendsPalette.sage(colorScheme)
                )
            }

            if overflow > 0 {
                Text("+\(overflow)")
                    .font(.system(size: 15, weight: .bold, design: .serif))
                    .foregroundColor(FriendsPalette.sageInk(colorScheme))
                    .frame(width: 46, height: 46)
                    .background(Circle().fill(FriendsPalette.sageInk(colorScheme).opacity(0.18)))
                    .overlay(Circle().strokeBorder(FriendsPalette.sage(colorScheme), lineWidth: 3))
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
                .plainRow()
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
                .plainRow()
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
            isManagingFamily: isManagingFamily,
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
        .plainRow()
        .tutorialHighlight(id: tutorialId ?? "noop_friend_\(friendship.id)")
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

    /// Section titles are ordinary rows rather than List headers. A `.plain`
    /// list pins its headers and draws its own backing behind them, which puts
    /// a grey bar across the cream canvas as soon as the list scrolls.
    private func sectionLabel(_ title: String, count: Int, highlighted: Bool = false) -> some View {
        HStack(spacing: 10) {
            Text(title)
                .font(FriendsPalette.display(22))
                .foregroundColor(FriendsPalette.ink(colorScheme))

            if highlighted {
                Text("\(count)")
                    .font(.system(size: 14, weight: .bold, design: .serif))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(FriendsPalette.terracotta(colorScheme)))
            } else {
                Text("\(count)")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(FriendsPalette.inkSoft(colorScheme))
            }

            Spacer()
        }
        .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 2, trailing: 20))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }

    // MARK: - Empty States

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "person.2")
                .font(.system(size: 44, weight: .light))
                .foregroundColor(FriendsPalette.terracotta(colorScheme).opacity(0.55))
                .frame(width: 96, height: 96)
                .background(Circle().fill(FriendsPalette.blush(colorScheme)))

            Text("No friends yet")
                .font(FriendsPalette.display(26))
                .foregroundColor(FriendsPalette.ink(colorScheme))

            Text("Add friends to share stores and reminders with the people you shop for.")
                .font(.system(size: 16))
                .foregroundColor(FriendsPalette.inkSoft(colorScheme))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            Button(action: { showAddFriend = true }) {
                Text("Add a friend")
                    .font(.system(size: 17, weight: .bold, design: .serif))
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .frame(height: 52)
                    .background(Capsule().fill(FriendsPalette.terracotta(colorScheme)))
            }
            .buttonStyle(.plain)
            .padding(.top, 4)

            Button(action: inviteFriends) {
                Text("Invite friends to Allim")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(FriendsPalette.terracotta(colorScheme))
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
                .foregroundColor(FriendsPalette.terracotta(colorScheme).opacity(0.55))
                .frame(width: 72, height: 72)
                .background(Circle().fill(FriendsPalette.blush(colorScheme)))

            Text("No matches")
                .font(FriendsPalette.display(22))
                .foregroundColor(FriendsPalette.ink(colorScheme))

            Text("Nobody matches \u{201C}\(viewModel.searchText)\u{201D}")
                .font(.system(size: 15))
                .foregroundColor(FriendsPalette.inkSoft(colorScheme))
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

// MARK: - List Row Style

private extension View {
    /// Strips the List chrome so each row is just the card it draws itself.
    /// Every surface on this screen carries its own shape and fill, so the row
    /// background, separators and default insets would only fight them.
    func plainRow() -> some View {
        self
            .listRowInsets(EdgeInsets(top: 5, leading: 20, bottom: 5, trailing: 20))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
    }
}

// MARK: - Card Surface

/// The raised paper surface shared by request cards and friend rows.
private struct FriendsCardBackground: View {
    let colorScheme: ColorScheme
    var fill: Color?

    var body: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(fill ?? FriendsPalette.surface(colorScheme))
            .shadow(color: FriendsPalette.shadow(colorScheme), radius: 10, x: 0, y: 4)
    }
}

// MARK: - Friend Card

struct FriendCard: View {
    let friendship: Friendship
    let currentUserId: String
    var isFamilyMember: Bool = false
    /// While the Family card is in manage mode the trailing button becomes a
    /// house toggle instead of the message shortcut.
    var isManagingFamily: Bool = false
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
        HStack(spacing: 14) {
            OrganicAvatar(name: friendName, profilePictureURL: friendProfilePictureURL)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(friendName)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(FriendsPalette.ink(colorScheme))
                        .lineLimit(1)

                    if isFamilyMember {
                        Text("FAMILY")
                            .font(.system(size: 10, weight: .bold))
                            .kerning(0.6)
                            .foregroundColor(FriendsPalette.sageInk(colorScheme))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(FriendsPalette.sage(colorScheme)))
                    }
                }

                Text(handle)
                    .font(.system(size: 14))
                    .foregroundColor(FriendsPalette.inkSoft(colorScheme))
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            trailingButton
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(FriendsCardBackground(colorScheme: colorScheme))
    }

    @ViewBuilder
    private var trailingButton: some View {
        if isManagingFamily {
            Button(action: onToggleFamily) {
                Image(systemName: isFamilyMember ? "house.fill" : "house")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(isFamilyMember ? .white : FriendsPalette.sageInk(colorScheme))
                    .frame(width: 44, height: 44)
                    .background(
                        Circle().fill(
                            isFamilyMember
                                ? FriendsPalette.sageInk(colorScheme)
                                : FriendsPalette.sage(colorScheme)
                        )
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isFamilyMember ? "Remove \(friendName) from Family" : "Add \(friendName) to Family")
        } else {
            Button(action: onMessage) {
                Image(systemName: "message.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(FriendsPalette.terracotta(colorScheme))
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(FriendsPalette.blush(colorScheme)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Message \(friendName)")
        }
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
                    .foregroundColor(FriendsPalette.ink(colorScheme))
                    .lineLimit(1)

                Text("wants to share lists")
                    .font(.system(size: 14))
                    .foregroundColor(FriendsPalette.inkSoft(colorScheme))
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
                        .background(Capsule().fill(FriendsPalette.terracotta(colorScheme)))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Accept request from \(friendship.requesterName)")

                Button(action: onReject) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(FriendsPalette.inkSoft(colorScheme))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Circle().stroke(FriendsPalette.outline(colorScheme), lineWidth: 1.5)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Decline request from \(friendship.requesterName)")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            FriendsCardBackground(colorScheme: colorScheme, fill: FriendsPalette.blush(colorScheme))
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
                    .foregroundColor(FriendsPalette.ink(colorScheme).opacity(0.8))
                    .lineLimit(1)

                Text("Request sent")
                    .font(.system(size: 14))
                    .foregroundColor(FriendsPalette.inkSoft(colorScheme))
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Button(action: onCancel) {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(FriendsPalette.inkSoft(colorScheme))
                    .frame(width: 38, height: 38)
                    .overlay(
                        Circle().stroke(FriendsPalette.outline(colorScheme), lineWidth: 1.5)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Cancel request to \(friendship.receiverName)")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(FriendsPalette.outline(colorScheme).opacity(0.7), lineWidth: 1.5)
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
                FriendsPalette.canvas(colorScheme)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Add a friend")
                            .font(FriendsPalette.display(32))
                            .foregroundColor(FriendsPalette.ink(colorScheme))
                            .padding(.top, 8)

                        Text("Search by email address or username to send them a request.")
                            .font(.system(size: 16))
                            .foregroundColor(FriendsPalette.inkSoft(colorScheme))

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
                                .foregroundColor(FriendsPalette.inkSoft(colorScheme))
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
            .toolbarBackground(FriendsPalette.canvas(colorScheme), for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(FriendsPalette.terracotta(colorScheme))
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
                .foregroundColor(FriendsPalette.inkSoft(colorScheme))

            TextField(
                "",
                text: $searchQuery,
                prompt: Text("Email or username")
                    .foregroundColor(FriendsPalette.inkSoft(colorScheme).opacity(0.8))
            )
            .font(.system(size: 17))
            .foregroundColor(FriendsPalette.ink(colorScheme))
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .submitLabel(.search)
            .focused($isQueryFocused)
            .onSubmit { runSearch() }

            if viewModel.isSearching {
                ProgressView()
                    .tint(FriendsPalette.terracotta(colorScheme))
            } else {
                Button(action: runSearch) {
                    Text("Search")
                        .font(.system(size: 15, weight: .bold, design: .serif))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .frame(height: 38)
                        .background(Capsule().fill(FriendsPalette.terracotta(colorScheme)))
                }
                .buttonStyle(.plain)
                .disabled(searchQuery.isEmpty)
                .opacity(searchQuery.isEmpty ? 0.4 : 1)
            }
        }
        .padding(.leading, 18)
        .padding(.trailing, 8)
        .frame(height: 56)
        .background(Capsule().fill(FriendsPalette.field(colorScheme)))
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
                    .foregroundColor(FriendsPalette.ink(colorScheme))
                    .lineLimit(1)

                Text(contact.email)
                    .font(.system(size: 14))
                    .foregroundColor(FriendsPalette.inkSoft(colorScheme))
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            addButton
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(FriendsCardBackground(colorScheme: colorScheme))
    }

    @ViewBuilder
    private var addButton: some View {
        let relationship = viewModel.getRelationshipStatus(with: contact.id)

        if relationship.exists {
            switch relationship.status {
            case .accepted:
                statusPill("Friends", tint: FriendsPalette.sageInk(colorScheme), fill: FriendsPalette.sage(colorScheme))
            case .pending:
                if relationship.isSentByMe {
                    statusPill(
                        "Pending",
                        tint: FriendsPalette.inkSoft(colorScheme),
                        fill: FriendsPalette.field(colorScheme)
                    )
                } else {
                    statusPill(
                        "Respond",
                        tint: FriendsPalette.terracotta(colorScheme),
                        fill: FriendsPalette.blush(colorScheme)
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
                .background(Capsule().fill(FriendsPalette.terracotta(colorScheme)))
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
