//
//  MessagesView.swift
//  Geolocation_v1.0.0
//
//  Created by Claude Code
//

import SwiftUI

struct MessagesView: View {
    @ObservedObject var viewModel: MessagesViewModel
    @Binding var pendingConversationId: String?
    /// Bumped when the user taps the Messages tab while already on it. The open
    /// conversation is the only screen this one pushes, so dropping it is the
    /// whole pop-to-root.
    var popToRootSignal: Int = 0
    @ObservedObject private var sessionManager = UserSessionManager.shared
    @ObservedObject private var subscriptionManager = SubscriptionManager.shared
    @State private var showNewMessage = false
    @State private var showNewGroup = false
    /// The chat being pushed — set by tapping a row, and by a notification
    /// tap arriving through `pendingConversationId`.
    @State private var selectedConversation: Conversation? = nil
    @State private var showDeleteGroupAlert = false
    @State private var pendingDeleteConversation: Conversation? = nil
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ZStack {
            OrganicPalette.canvas(colorScheme)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header

                if viewModel.isLoading && viewModel.conversations.isEmpty {
                    Spacer()
                    ProgressView("Loading messages...")
                        .tint(OrganicPalette.terracotta(colorScheme))
                        .foregroundColor(OrganicPalette.inkSoft(colorScheme))
                    Spacer()
                } else if viewModel.conversations.isEmpty {
                    Spacer()
                    emptyState
                    Spacer()
                } else {
                    conversationsList
                }
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
        // The screen draws its own oversized display title, so the system bar
        // would only stack a second "Messages" above it.
        .toolbar(.hidden, for: .navigationBar)
        .tint(OrganicPalette.terracotta(colorScheme))
        .sheet(isPresented: $showNewGroup) {
            NewGroupView(viewModel: viewModel)
        }
        .sheet(isPresented: $showNewMessage) {
            NewMessageView(viewModel: viewModel)
        }
        .navigationDestination(item: $selectedConversation) { conversation in
            ConversationView(conversation: conversation, viewModel: viewModel)
                // The bar floats over a conversation too, and the message
                // field is pinned to the bottom edge under it.
                .organicTabBarInset()
        }
        .onAppear {
            viewModel.fetchConversations()
            viewModel.fetchUnreadCount()
        }
        .onChange(of: pendingConversationId) { _, conversationId in
            guard let conversationId = conversationId else { return }
            if let conversation = viewModel.conversations.first(where: { $0.id == conversationId }) {
                selectedConversation = conversation
                pendingConversationId = nil
            } else {
                // Conversations not loaded yet — fetch and navigate when they load
                viewModel.fetchConversations()
            }
        }
        .onChange(of: viewModel.conversations) { _, conversations in
            // Once conversations load, complete any pending notification navigation
            guard let conversationId = pendingConversationId else { return }
            if let conversation = conversations.first(where: { $0.id == conversationId }) {
                selectedConversation = conversation
                pendingConversationId = nil
            }
        }
        .onChange(of: popToRootSignal) { _, _ in
            // A pending deep link goes with it: the tab tap is the more recent
            // of the two instructions.
            if selectedConversation != nil { selectedConversation = nil }
            if pendingConversationId != nil { pendingConversationId = nil }
        }
    }

    /// Title and actions, drawn in the content rather than the navigation bar.
    /// Compose is the primary action and gets the terracotta disc; the group
    /// button sits beside it in the quieter blush treatment.
    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            Text("Messages")
                .font(OrganicPalette.display(40))
                .foregroundColor(OrganicPalette.ink(colorScheme))

            Spacer()

            Button(action: { showNewGroup = true }) {
                Image(systemName: "person.3")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundColor(OrganicPalette.terracotta(colorScheme))
                    .frame(width: 54, height: 54)
                    .background(Circle().fill(OrganicPalette.blush(colorScheme)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("New group chat")

            Button(action: { showNewMessage = true }) {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 54, height: 54)
                    .background(Circle().fill(OrganicPalette.terracotta(colorScheme)))
                    .shadow(color: OrganicPalette.terracotta(colorScheme).opacity(0.35), radius: 10, x: 0, y: 5)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("New message")
            .tutorialHighlight(id: "tutorial_compose")
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 14)
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "message")
                .font(.system(size: 44, weight: .light))
                .foregroundColor(OrganicPalette.terracotta(colorScheme).opacity(0.55))
                .frame(width: 96, height: 96)
                .background(Circle().fill(OrganicPalette.blush(colorScheme)))

            Text("No messages yet")
                .font(OrganicPalette.display(26))
                .foregroundColor(OrganicPalette.ink(colorScheme))

            Text("Start a conversation to share stores and reminders with a friend.")
                .font(.system(size: 16))
                .foregroundColor(OrganicPalette.inkSoft(colorScheme))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button(action: { showNewMessage = true }) {
                Text("New message")
                    .font(OrganicPalette.title(17))
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .frame(height: 52)
                    .background(Capsule().fill(OrganicPalette.terracotta(colorScheme)))
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .padding()
    }

    private var conversationsList: some View {
        List {
            ForEach(viewModel.conversations) { conversation in
                // Rows push through `navigationDestination` rather than being
                // NavigationLinks: a link inside a List draws its own chevron
                // and press highlight, both of which cut across the card shape.
                Button {
                    selectedConversation = conversation
                } label: {
                    ConversationRow(
                        conversation: conversation,
                        currentUserId: sessionManager.currentUser?.userId ?? "",
                        profilePictureURL: viewModel.profilePictureURL(for: conversation)
                    )
                }
                .buttonStyle(.plain)
                .organicRow()
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        handleDelete(conversation)
                    } label: {
                        Image(systemName: "trash")
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: subscriptionManager.isSubscribed ? 0 : 50)
        }
        .organicAlert(
            "Delete Group Chat?",
            isPresented: $showDeleteGroupAlert,
            icon: "trash.fill",
            tone: .destructive,
            message: "This will permanently delete the group chat and all its messages for every member.",
            actions: [
                .destructive("Delete for Everyone") {
                    if let conversation = pendingDeleteConversation {
                        viewModel.deleteConversation(conversation)
                    }
                    pendingDeleteConversation = nil
                },
                .cancel { pendingDeleteConversation = nil }
            ]
        )
    }

    private func handleDelete(_ conversation: Conversation) {
        let currentUserId = sessionManager.currentUser?.userId ?? ""
        guard conversation.isGroupConversation else {
            // 1:1 conversation — delete as normal
            viewModel.deleteConversation(conversation)
            return
        }
        if conversation.groupCreatorId == currentUserId {
            // Owner swipe-deleting a group — confirm first
            pendingDeleteConversation = conversation
            showDeleteGroupAlert = true
        } else {
            // Non-owner — leave the group instead of deleting
            viewModel.leaveGroup(conversationId: conversation.id) { _ in }
        }
    }
}

// MARK: - Conversation Row

struct ConversationRow: View {
    let conversation: Conversation
    let currentUserId: String
    let profilePictureURL: String?

    @Environment(\.colorScheme) private var colorScheme

    private var unreadCount: Int {
        conversation.unreadCountFor(userId: currentUserId)
    }

    private var isUnread: Bool { unreadCount > 0 }

    private var displayName: String {
        conversation.displayName(currentUserId: currentUserId)
    }

    /// The one line of context under the name: the last message when there is
    /// one, the member list for a group that hasn't been used yet, otherwise a
    /// nudge that the chat is empty.
    private var preview: String {
        if let lastMessage = conversation.lastMessageContent, !lastMessage.isEmpty {
            return lastMessage
        }
        if conversation.isGroupConversation {
            return conversation.memberNamesSubtitle(currentUserId: currentUserId)
        }
        return "No messages yet"
    }

    private var hasMessages: Bool {
        !(conversation.lastMessageContent?.isEmpty ?? true)
    }

    var body: some View {
        HStack(spacing: 14) {
            OrganicAvatar(
                name: displayName,
                profilePictureURL: conversation.isGroupConversation ? nil : profilePictureURL,
                systemImage: conversation.isGroupConversation ? "person.3.fill" : nil
            )

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(displayName)
                        .font(.system(size: 18, weight: isUnread ? .bold : .semibold))
                        .foregroundColor(OrganicPalette.ink(colorScheme))
                        .lineLimit(1)

                    Spacer(minLength: 4)

                    if let timestamp = conversation.lastMessageAt {
                        Text(formatTime(timestamp))
                            .font(.system(size: 13))
                            .foregroundColor(OrganicPalette.inkSoft(colorScheme))
                            .lineLimit(1)
                    }
                }

                HStack(spacing: 8) {
                    Text(preview)
                        .font(.system(size: 15))
                        .foregroundColor(
                            isUnread
                                ? OrganicPalette.ink(colorScheme)
                                : OrganicPalette.inkSoft(colorScheme)
                        )
                        .italic(!hasMessages && !conversation.isGroupConversation)
                        .lineLimit(1)

                    Spacer(minLength: 4)

                    if isUnread {
                        Text("\(unreadCount)")
                            .font(OrganicPalette.title(13))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(OrganicPalette.terracotta(colorScheme)))
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(OrganicCardBackground(colorScheme: colorScheme))
    }

    private func formatTime(_ timestamp: TimeInterval) -> String {
        let date = Date(timeIntervalSince1970: timestamp)
        let calendar = Calendar.current

        if calendar.isDateInToday(date) {
            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm a"
            return formatter.string(from: date)
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MM/dd/yy"
            return formatter.string(from: date)
        }
    }
}

// MARK: - New Message View

struct NewMessageView: View {
    @ObservedObject var viewModel: MessagesViewModel
    @ObservedObject private var sessionManager = UserSessionManager.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var searchQuery = ""
    @State private var selectedConversation: Conversation?
    @FocusState private var isQueryFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                OrganicPalette.canvas(colorScheme)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("New message")
                            .font(OrganicPalette.display(32))
                            .foregroundColor(OrganicPalette.ink(colorScheme))
                            .padding(.top, 8)

                        Text("Search by email address or username, or pick someone you've messaged before.")
                            .font(.system(size: 16))
                            .foregroundColor(OrganicPalette.inkSoft(colorScheme))

                        queryField

                        if let contact = viewModel.searchedContact {
                            Button {
                                startConversation(with: contact)
                            } label: {
                                OrganicContactRow(contact: contact)
                            }
                            .buttonStyle(.plain)
                        } else if !searchQuery.isEmpty && !viewModel.isSearching {
                            Text("No user found")
                                .font(.system(size: 15))
                                .foregroundColor(OrganicPalette.inkSoft(colorScheme))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 20)
                        }

                        if !viewModel.recentContacts.isEmpty {
                            Text("Recent")
                                .font(OrganicPalette.display(22))
                                .foregroundColor(OrganicPalette.ink(colorScheme))
                                .padding(.top, 4)

                            VStack(spacing: 10) {
                                ForEach(viewModel.recentContacts) { contact in
                                    Button {
                                        startConversation(with: contact)
                                    } label: {
                                        OrganicContactRow(contact: contact)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
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
            .onAppear {
                viewModel.fetchRecentContacts()
            }
            .navigationDestination(item: $selectedConversation) { conversation in
                ConversationView(conversation: conversation, viewModel: viewModel)
                    .organicTabBarInset()
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
                        .font(OrganicPalette.title(15))
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
        viewModel.searchContact(query: searchQuery)
    }

    private func startConversation(with contact: Contact) {
        guard let userName = sessionManager.currentUser?.name else { return }

        viewModel.startConversation(with: contact, currentUserName: userName) { conversation in
            if let conversation = conversation {
                selectedConversation = conversation
            }
        }
    }
}

// MARK: - Contact Row

struct ContactRow: View {
    let contact: Contact

    var body: some View {
        HStack(spacing: 12) {
            OrganicAvatar(
                name: contact.name,
                profilePictureURL: contact.profilePictureURL,
                size: 40
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(contact.name)
                    .font(.body)
                    .foregroundColor(.primary)

                Text(contact.email)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .contentShape(Rectangle())
    }
}

#Preview {
    NavigationStack {
        MessagesView(viewModel: MessagesViewModel(), pendingConversationId: .constant(nil))
    }
}
