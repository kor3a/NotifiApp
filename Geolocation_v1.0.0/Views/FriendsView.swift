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
    @State private var showAddFriend = false
    @State private var selectedFriendForMessage: Contact?
    @State private var selectedConversation: Conversation?
    @State private var friendshipToRemove: Friendship?
    @State private var showingRemoveAlert = false
    @State private var friendshipToCancel: Friendship?
    @State private var showingCancelAlert = false
    @State private var friendshipForFamilyAction: Friendship?
    @State private var showingFamilyActionSheet = false
    @Environment(\.colorScheme) var colorScheme

    private let gridColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

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
            if sessionManager.currentUser?.isSubscribed != true {
                VStack(spacing: 0) {
                    Spacer()
                    BannerAdView(adUnitID: kBannerAdUnitID)
                        .frame(height: 50)
                        .background(Color(.systemBackground).opacity(0.95))
                }
            }
        }
        .navigationTitle("Friends")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showAddFriend = true }) {
                    Image(systemName: "person.badge.plus")
                }
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
        .confirmationDialog(
            familyActionTitle,
            isPresented: $showingFamilyActionSheet,
            titleVisibility: .visible
        ) {
            if let friendship = friendshipForFamilyAction {
                if viewModel.isFamilyMember(friendship) {
                    Button("Remove from Family", role: .destructive) {
                        viewModel.removeFromFamily(friendship)
                        friendshipForFamilyAction = nil
                    }
                } else {
                    Button("Add to Family") {
                        viewModel.addToFamily(friendship)
                        friendshipForFamilyAction = nil
                    }
                }
            }
            Button("Cancel", role: .cancel) {
                friendshipForFamilyAction = nil
            }
        }
    }

    private var familyActionTitle: String {
        guard let friendship = friendshipForFamilyAction else { return "" }
        let name = friendship.friendName(currentUserId: sessionManager.currentUser?.userId ?? "")
        if viewModel.isFamilyMember(friendship) {
            return "Remove \(name) from Family?"
        } else {
            return "Add \(name) to Family?"
        }
    }

    // MARK: - Main Content

    private var mainContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Pending Friend Requests - Horizontal scroll
                if !viewModel.pendingRequests.isEmpty {
                    pendingRequestsSection
                }

                // Sent Requests - Horizontal chips
                if !viewModel.sentRequests.isEmpty {
                    sentRequestsSection
                }

                // Family Section - Above Friends
                if !viewModel.familyMembers.isEmpty {
                    familyGridSection
                }

                // Friends Grid
                if !viewModel.friends.isEmpty {
                    friendsGridSection
                }

                // Empty State
                if viewModel.friends.isEmpty && viewModel.familyMembers.isEmpty && viewModel.pendingRequests.isEmpty && viewModel.sentRequests.isEmpty {
                    emptyState
                        .padding(.top, 60)
                }
            }
            .padding(.top, 8)
            .padding(.bottom, 20)
        }
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: 50)
        }
    }

    // MARK: - Pending Requests Section

    private var pendingRequestsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Friend Requests")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text("\(viewModel.pendingRequests.count)")
                    .font(.caption.bold())
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.appAccent)
                    .clipShape(Capsule())

                Spacer()
            }
            .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(viewModel.pendingRequests) { friendship in
                        PendingRequestCard(
                            friendship: friendship,
                            colorScheme: colorScheme,
                            freshProfilePictureURL: viewModel.friendProfilePictures[friendship.requesterId],
                            onAccept: { viewModel.acceptRequest(friendship) },
                            onReject: { viewModel.rejectRequest(friendship) }
                        )
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Family Grid Section

    private var familyGridSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "house.fill")
                    .foregroundColor(.purple)
                Text("Family")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text("\(viewModel.familyMembers.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()
            }
            .padding(.horizontal)

            LazyVGrid(columns: gridColumns, spacing: 12) {
                ForEach(viewModel.familyMembers) { friendship in
                    let friendId = friendship.friendId(currentUserId: sessionManager.currentUser?.userId ?? "")
                    FriendCard(
                        friendship: friendship,
                        currentUserId: sessionManager.currentUser?.userId ?? "",
                        colorScheme: colorScheme,
                        isFamilyMember: true,
                        freshProfilePictureURL: viewModel.friendProfilePictures[friendId],
                        onMessage: { startConversation(with: friendship) },
                        onRemove: {
                            friendshipToRemove = friendship
                            showingRemoveAlert = true
                        },
                        onPhotoTap: {
                            friendshipForFamilyAction = friendship
                            showingFamilyActionSheet = true
                        }
                    )
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Friends Grid Section

    private var friendsGridSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "person.2.fill")
                    .foregroundColor(.blue)
                Text("Friends")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text("\(viewModel.friends.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()
            }
            .padding(.horizontal)

            LazyVGrid(columns: gridColumns, spacing: 12) {
                ForEach(viewModel.friends) { friendship in
                    let friendId = friendship.friendId(currentUserId: sessionManager.currentUser?.userId ?? "")
                    FriendCard(
                        friendship: friendship,
                        currentUserId: sessionManager.currentUser?.userId ?? "",
                        colorScheme: colorScheme,
                        isFamilyMember: false,
                        freshProfilePictureURL: viewModel.friendProfilePictures[friendId],
                        onMessage: { startConversation(with: friendship) },
                        onRemove: {
                            friendshipToRemove = friendship
                            showingRemoveAlert = true
                        },
                        onPhotoTap: {
                            friendshipForFamilyAction = friendship
                            showingFamilyActionSheet = true
                        }
                    )
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Sent Requests Section

    private var sentRequestsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Sent Requests")
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer()
            }
            .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(viewModel.sentRequests) { friendship in
                        SentRequestChip(
                            friendship: friendship,
                            currentUserId: sessionManager.currentUser?.userId ?? "",
                            colorScheme: colorScheme,
                            freshProfilePictureURL: viewModel.friendProfilePictures[friendship.receiverId],
                            onCancel: {
                                friendshipToCancel = friendship
                                showingCancelAlert = true
                            }
                        )
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Empty State

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
        }
        .padding()
        .frame(maxWidth: .infinity)
    }

    // MARK: - Actions

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

// MARK: - Friend Card (Grid Cell)

struct FriendCard: View {
    let friendship: Friendship
    let currentUserId: String
    let colorScheme: ColorScheme
    var isFamilyMember: Bool = false
    /// Fresh profile picture URL fetched from the `users` collection, overriding the stale one in the friendship doc.
    var freshProfilePictureURL: String?
    let onMessage: () -> Void
    let onRemove: () -> Void
    var onPhotoTap: (() -> Void)?

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
        VStack(spacing: 12) {
            // Avatar - tappable for family action
            Button(action: { onPhotoTap?() }) {
                ZStack(alignment: .bottomTrailing) {
                    ProfilePictureView(profilePictureURL: friendProfilePictureURL, size: 64) {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [avatarColor.opacity(0.7), avatarColor],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 64, height: 64)
                            .overlay(
                                Text(avatarInitial)
                                    .font(.title2.bold())
                                    .foregroundColor(.white)
                            )
                    }
                    .shadow(color: avatarColor.opacity(0.3), radius: 6, x: 0, y: 3)

                    if isFamilyMember {
                        Image(systemName: "house.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.white)
                            .padding(4)
                            .background(Color.purple)
                            .clipShape(Circle())
                            .offset(x: 2, y: 2)
                    }
                }
            }
            .buttonStyle(.plain)

            // Name & UserId
            VStack(spacing: 2) {
                Text(friendName)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)

                Text(friendUserId)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            // Action Buttons
            HStack(spacing: 8) {
                Button(action: onMessage) {
                    Image(systemName: "message.fill")
                        .font(.caption)
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                        .background(Color.appAccent)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

                Button(action: onRemove) {
                    Image(systemName: "person.badge.minus")
                        .font(.caption)
                        .foregroundColor(.appError)
                        .frame(width: 32, height: 32)
                        .background(Color.appError.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            isFamilyMember
                                ? LinearGradient(colors: [Color.purple.opacity(0.4), Color.purple.opacity(0.15)], startPoint: .topLeading, endPoint: .bottomTrailing)
                                : Color.cardBorder(for: colorScheme),
                            lineWidth: 1.5
                        )
                )
                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.08), radius: 8, x: 0, y: 4)
        )
    }
}

// MARK: - Pending Request Card

struct PendingRequestCard: View {
    let friendship: Friendship
    let colorScheme: ColorScheme
    var freshProfilePictureURL: String?
    let onAccept: () -> Void
    let onReject: () -> Void

    private var requesterPictureURL: String? {
        freshProfilePictureURL ?? friendship.requesterProfilePictureURL
    }

    var body: some View {
        VStack(spacing: 12) {
            // Avatar
            ProfilePictureView(profilePictureURL: requesterPictureURL, size: 52) {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.appWarning.opacity(0.6), Color.appWarning],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 52, height: 52)
                    .overlay(
                        Text(String(friendship.requesterName.prefix(1)).uppercased())
                            .font(.title3.bold())
                            .foregroundColor(.white)
                    )
            }

            VStack(spacing: 2) {
                Text(friendship.requesterName)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)

                Text("wants to be friends")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            // Accept / Reject
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
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .frame(width: 150)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            Color.appWarning.opacity(0.3),
                            lineWidth: 1.5
                        )
                )
                .shadow(color: Color.appWarning.opacity(0.15), radius: 8, x: 0, y: 4)
        )
    }
}

// MARK: - Sent Request Chip

struct SentRequestChip: View {
    let friendship: Friendship
    let currentUserId: String
    let colorScheme: ColorScheme
    var freshProfilePictureURL: String?
    let onCancel: () -> Void

    private var receiverPictureURL: String? {
        freshProfilePictureURL ?? friendship.receiverProfilePictureURL
    }

    var body: some View {
        HStack(spacing: 8) {
            ProfilePictureView(profilePictureURL: receiverPictureURL, size: 32) {
                Circle()
                    .fill(Color.secondary.opacity(0.2))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Text(String(friendship.receiverName.prefix(1)).uppercased())
                            .font(.caption.bold())
                            .foregroundColor(.secondary)
                    )
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(friendship.receiverName)
                    .font(.caption.weight(.medium))
                    .lineLimit(1)

                HStack(spacing: 2) {
                    Image(systemName: "clock")
                        .font(.system(size: 8))
                    Text("Pending")
                        .font(.caption2)
                }
                .foregroundColor(.secondary)
            }

            Button(action: onCancel) {
                Image(systemName: "xmark")
                    .font(.caption2.bold())
                    .foregroundColor(.appError)
                    .frame(width: 24, height: 24)
                    .background(Color.appError.opacity(0.1))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 8)
        .padding(.leading, 8)
        .padding(.trailing, 10)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule()
                        .stroke(
                            Color.cardBorder(for: colorScheme),
                            lineWidth: 1
                        )
                )
        )
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
