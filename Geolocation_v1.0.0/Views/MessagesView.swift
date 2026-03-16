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
    @ObservedObject private var sessionManager = UserSessionManager.shared
    @State private var showNewMessage = false
    @State private var notificationConversation: Conversation? = nil
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ZStack {
            Color.backgroundGradient(for: colorScheme)
                .ignoresSafeArea()

            if viewModel.isLoading && viewModel.conversations.isEmpty {
                ProgressView("Loading messages...")
            } else if viewModel.conversations.isEmpty {
                emptyState
            } else {
                conversationsList
            }

            // Sticky banner ad above tab bar
            VStack(spacing: 0) {
                Spacer()
                BannerAdView(adUnitID: kBannerAdUnitID)
                    .frame(height: 50)
                    .background(Color(.systemBackground).opacity(0.95))
            }
        }
        .navigationTitle("Messages")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showNewMessage = true }) {
                    Image(systemName: "square.and.pencil")
                }
            }
        }
        .sheet(isPresented: $showNewMessage) {
            NewMessageView(viewModel: viewModel)
        }
        .navigationDestination(item: $notificationConversation) { conversation in
            ConversationView(conversation: conversation, viewModel: viewModel)
        }
        .onAppear {
            viewModel.fetchConversations()
            viewModel.fetchUnreadCount()
        }
        .onChange(of: pendingConversationId) { _, conversationId in
            guard let conversationId = conversationId else { return }
            if let conversation = viewModel.conversations.first(where: { $0.id == conversationId }) {
                notificationConversation = conversation
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
                notificationConversation = conversation
                pendingConversationId = nil
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "message")
                .resizable()
                .frame(width: 60, height: 60)
                .foregroundStyle(.gray)

            Text("No Messages")
                .font(.title2)
                .bold()

            Text("Start a conversation to share reminders")
                .foregroundStyle(.gray)
                .multilineTextAlignment(.center)

            Button(action: { showNewMessage = true }) {
                Label("New Message", systemImage: "plus")
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal, 40)
        }
        .padding()
    }

    private var conversationsList: some View {
        List {
            ForEach(viewModel.conversations) { conversation in
                NavigationLink(destination: ConversationView(
                    conversation: conversation,
                    viewModel: viewModel
                )) {
                    ConversationRow(
                        conversation: conversation,
                        currentUserId: sessionManager.currentUser?.userId ?? "",
                        profilePictureURL: viewModel.profilePictureURL(for: conversation)
                    )
                }
                .listRowBackground(
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
                )
                .listRowSeparator(.hidden)
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        viewModel.deleteConversation(conversation)
                    } label: {
                        Image(systemName: "trash")
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: 50)
        }
    }
}

// MARK: - Conversation Row

struct ConversationRow: View {
    let conversation: Conversation
    let currentUserId: String
    let profilePictureURL: String?

    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            ProfilePictureView(profilePictureURL: profilePictureURL, size: 50) {
                Circle()
                    .fill(Color.appAccent.opacity(0.2))
                    .frame(width: 50, height: 50)
                    .overlay(
                        Text(avatarInitial)
                            .font(.headline)
                            .foregroundColor(.appAccent)
                    )
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(conversation.otherParticipantName(currentUserId: currentUserId))
                        .font(.headline)
                        .lineLimit(1)

                    if let otherId = conversation.otherParticipantId(currentUserId: currentUserId) {
                        Text("@\(otherId)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    if let timestamp = conversation.lastMessageAt {
                        Text(formatTime(timestamp))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                HStack {
                    if let lastMessage = conversation.lastMessageContent {
                        Text(lastMessage)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    } else {
                        Text("No messages yet")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .italic()
                    }

                    Spacer()

                    if conversation.unreadCountFor(userId: currentUserId) > 0 {
                        Text("\(conversation.unreadCountFor(userId: currentUserId))")
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.appAccent)
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }

    private var avatarInitial: String {
        let name = conversation.otherParticipantName(currentUserId: currentUserId)
        return String(name.prefix(1)).uppercased()
    }

    private func formatTime(_ timestamp: TimeInterval) -> String {
        let date = Date(timeIntervalSince1970: timestamp)
        let now = Date()
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
    @State private var searchEmail = ""
    @State private var selectedConversation: Conversation?

    var body: some View {
        NavigationStack {
            List {
                Section("Find by Email") {
                    HStack {
                        TextField("Enter email address", text: $searchEmail)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.emailAddress)
                            .autocorrectionDisabled()

                        if viewModel.isSearching {
                            ProgressView()
                        } else {
                            Button("Search") {
                                viewModel.searchContact(email: searchEmail)
                            }
                            .disabled(searchEmail.isEmpty)
                        }
                    }

                    if let contact = viewModel.searchedContact {
                        Button(action: { startConversation(with: contact) }) {
                            ContactRow(contact: contact)
                        }
                    } else if !searchEmail.isEmpty && !viewModel.isSearching && viewModel.searchedContact == nil {
                        Text("No user found with that email")
                            .foregroundColor(.secondary)
                            .font(.subheadline)
                    }
                }

                if !viewModel.recentContacts.isEmpty {
                    Section("Recent Contacts") {
                        ForEach(viewModel.recentContacts) { contact in
                            Button(action: { startConversation(with: contact) }) {
                                ContactRow(contact: contact)
                            }
                        }
                    }
                }
            }
            .navigationTitle("New Message")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                viewModel.fetchRecentContacts()
            }
            .navigationDestination(item: $selectedConversation) { conversation in
                ConversationView(conversation: conversation, viewModel: viewModel)
            }
        }
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
            ProfilePictureView(profilePictureURL: contact.profilePictureURL, size: 40) {
                Circle()
                    .fill(Color.appAccent.opacity(0.2))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text(String(contact.name.prefix(1)).uppercased())
                            .font(.subheadline)
                            .foregroundColor(.appAccent)
                    )
            }

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
