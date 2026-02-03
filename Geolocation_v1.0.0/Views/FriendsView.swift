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
                Text("Are you sure you want to remove \(friendship.friendName(currentUserId: sessionManager.currentUser?.userId ?? "")) from your friends?")
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
    }

    private var mainContent: some View {
        List {
            // Pending Friend Requests Section
            if !viewModel.pendingRequests.isEmpty {
                Section {
                    ForEach(viewModel.pendingRequests) { friendship in
                        PendingRequestRow(
                            friendship: friendship,
                            onAccept: { viewModel.acceptRequest(friendship) },
                            onReject: { viewModel.rejectRequest(friendship) }
                        )
                        .listRowBackground(cardBackground)
                    }
                } header: {
                    HStack {
                        Text("Friend Requests")
                        Spacer()
                        Text("\(viewModel.pendingRequests.count)")
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.appAccent)
                            .clipShape(Capsule())
                    }
                }
                .listRowSeparator(.hidden)
            }

            // Friends List Section
            if !viewModel.friends.isEmpty {
                Section("Friends") {
                    ForEach(viewModel.friends) { friendship in
                        FriendRow(
                            friendship: friendship,
                            currentUserId: sessionManager.currentUser?.userId ?? "",
                            onMessage: { startConversation(with: friendship) },
                            onRemove: {
                                friendshipToRemove = friendship
                                showingRemoveAlert = true
                            }
                        )
                        .listRowBackground(cardBackground)
                    }
                }
                .listRowSeparator(.hidden)
            }

            // Sent Requests Section
            if !viewModel.sentRequests.isEmpty {
                Section("Sent Requests") {
                    ForEach(viewModel.sentRequests) { friendship in
                        SentRequestRow(
                            friendship: friendship,
                            currentUserId: sessionManager.currentUser?.userId ?? "",
                            onCancel: {
                                friendshipToCancel = friendship
                                showingCancelAlert = true
                            }
                        )
                        .listRowBackground(cardBackground)
                    }
                }
                .listRowSeparator(.hidden)
            }

            // Empty State
            if viewModel.friends.isEmpty && viewModel.pendingRequests.isEmpty && viewModel.sentRequests.isEmpty {
                Section {
                    emptyState
                        .listRowBackground(Color.clear)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        Color.cardBorder(for: colorScheme),
                        lineWidth: 1.5
                    )
            )
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.1), radius: 8, x: 0, y: 4)
            .padding(.vertical, 4)
    }

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

// MARK: - Friend Row

struct FriendRow: View {
    let friendship: Friendship
    let currentUserId: String
    let onMessage: () -> Void
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            Circle()
                .fill(Color.appAccent.opacity(0.2))
                .frame(width: 50, height: 50)
                .overlay(
                    Text(avatarInitial)
                        .font(.headline)
                        .foregroundColor(.appAccent)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(friendship.friendName(currentUserId: currentUserId))
                    .font(.headline)
                    .lineLimit(1)

                Text(friendship.friendEmail(currentUserId: currentUserId))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // Message Button
            Button(action: onMessage) {
                Image(systemName: "message.fill")
                    .foregroundColor(.appAccent)
                    .frame(width: 36, height: 36)
                    .background(Color.appAccent.opacity(0.1))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 8)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                onRemove()
            } label: {
                Image(systemName: "person.badge.minus")
            }
        }
    }

    private var avatarInitial: String {
        String(friendship.friendName(currentUserId: currentUserId).prefix(1)).uppercased()
    }
}

// MARK: - Pending Request Row

struct PendingRequestRow: View {
    let friendship: Friendship
    let onAccept: () -> Void
    let onReject: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            Circle()
                .fill(Color.appWarning.opacity(0.2))
                .frame(width: 50, height: 50)
                .overlay(
                    Text(String(friendship.requesterName.prefix(1)).uppercased())
                        .font(.headline)
                        .foregroundColor(.appWarning)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(friendship.requesterName)
                    .font(.headline)
                    .lineLimit(1)

                Text(friendship.requesterEmail)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                Text("Wants to be your friend")
                    .font(.caption)
                    .foregroundColor(.appWarning)
            }

            Spacer()

            // Accept/Reject Buttons
            HStack(spacing: 8) {
                Button(action: onReject) {
                    Image(systemName: "xmark")
                        .foregroundColor(.appError)
                        .frame(width: 32, height: 32)
                        .background(Color.appError.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

                Button(action: onAccept) {
                    Image(systemName: "checkmark")
                        .foregroundColor(.appSuccess)
                        .frame(width: 32, height: 32)
                        .background(Color.appSuccess.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Sent Request Row

struct SentRequestRow: View {
    let friendship: Friendship
    let currentUserId: String
    let onCancel: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            Circle()
                .fill(Color.secondary.opacity(0.2))
                .frame(width: 50, height: 50)
                .overlay(
                    Text(String(friendship.receiverName.prefix(1)).uppercased())
                        .font(.headline)
                        .foregroundColor(.secondary)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(friendship.receiverName)
                    .font(.headline)
                    .lineLimit(1)

                Text(friendship.receiverEmail)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.caption2)
                    Text("Request pending")
                        .font(.caption)
                }
                .foregroundColor(.secondary)
            }

            Spacer()

            // Cancel button
            Button(action: onCancel) {
                Text("Cancel")
                    .font(.caption)
                    .foregroundColor(.appError)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.appError.opacity(0.1))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 8)
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
            Circle()
                .fill(Color.appAccent.opacity(0.2))
                .frame(width: 50, height: 50)
                .overlay(
                    Text(String(contact.name.prefix(1)).uppercased())
                        .font(.headline)
                        .foregroundColor(.appAccent)
                )

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
