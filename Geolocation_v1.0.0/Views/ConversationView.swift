//
//  ConversationView.swift
//  Geolocation_v1.0.0
//
//  Created by Claude Code
//

import SwiftUI

struct ConversationView: View {
    let conversation: Conversation
    @ObservedObject var viewModel: MessagesViewModel
    @ObservedObject private var sessionManager = UserSessionManager.shared
    @ObservedObject private var subscriptionManager = SubscriptionManager.shared
    @State private var messageText = ""
    @State private var scrolledToTopMessageId: String?
    @FocusState private var isInputFocused: Bool
    @Environment(\.colorScheme) var colorScheme

    private var currentUserId: String {
        sessionManager.currentUser?.userId ?? ""
    }

    var body: some View {
        VStack(spacing: 0) {
            // Messages list
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        // Load more indicator at top
                        if viewModel.hasMoreMessages {
                            loadMoreButton
                                .id("loadMore")
                        }

                        ForEach(Array(viewModel.messages.enumerated()), id: \.element.id) { index, message in
                            MessageBubble(
                                message: message,
                                isFromCurrentUser: viewModel.isCurrentUser(message.senderId),
                                viewModel: viewModel
                            )
                            .id(message.id)

                            // Insert a banner ad after every 5th message (hidden for subscribers)
                            if (index + 1) % 5 == 0 && !subscriptionManager.isSubscribed {
                                BannerAdView(adUnitID: kBannerAdUnitID)
                                    .frame(height: 50)
                                    .background(Color(.systemBackground).opacity(0.95))
                                    .cornerRadius(8)
                                    .padding(.vertical, 4)
                            }
                        }
                    }
                    .padding()
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: viewModel.messages.count) { oldCount, newCount in
                    // Only auto-scroll if new messages were added (not when loading older)
                    if newCount > oldCount, let lastMessage = viewModel.messages.last {
                        // Check if the new message is at the end (new message) vs beginning (older messages)
                        if scrolledToTopMessageId == nil {
                            withAnimation {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                    // Reset the scroll tracking after processing
                    scrolledToTopMessageId = nil
                }
                .onChange(of: isInputFocused) { _, focused in
                    // When keyboard appears, scroll to the latest message
                    if focused, let lastMessage = viewModel.messages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
                .onAppear {
                    if let lastMessage = viewModel.messages.last {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }

            // Banner ad above input bar (hidden for subscribers)
            if !subscriptionManager.isSubscribed {
                BannerAdView(adUnitID: kBannerAdUnitID)
                    .frame(height: 50)
                    .background(Color(.systemBackground).opacity(0.95))
            }

            // Input bar
            inputBar
        }
        .background(Color.backgroundGradient(for: colorScheme))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 1) {
                    Text(conversation.otherParticipantName(currentUserId: currentUserId))
                        .font(.headline)

                    if let otherId = conversation.otherParticipantId(currentUserId: currentUserId) {
                        Text("@\(otherId)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .onAppear {
            messageText = viewModel.draftMessages[conversation.id] ?? ""
            viewModel.fetchMessages(for: conversation.id)
            viewModel.markAsRead(conversationId: conversation.id)
        }
        .onChange(of: messageText) { _, newValue in
            viewModel.draftMessages[conversation.id] = newValue
        }
        .onDisappear {
            viewModel.markAsRead(conversationId: conversation.id)
            viewModel.stopListeningForMessages()
        }
    }

    private var loadMoreButton: some View {
        Button {
            // Remember the first message to maintain scroll position
            scrolledToTopMessageId = viewModel.messages.first?.id
            viewModel.loadMoreMessages()
        } label: {
            HStack(spacing: 8) {
                if viewModel.isLoadingMore {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "arrow.up.circle")
                }
                Text(viewModel.isLoadingMore ? "Loading..." : "Load earlier messages")
                    .font(.subheadline)
            }
            .foregroundColor(.secondary)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
        }
        .disabled(viewModel.isLoadingMore)
    }

    private var inputBar: some View {
        HStack(spacing: 12) {
            TextField("Type a message...", text: $messageText, axis: .vertical)
                .textFieldStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(colorScheme == .dark ? Color.white.opacity(0.1) : Color.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                )
                .focused($isInputFocused)
                .lineLimit(1...5)

            Button(action: sendMessage) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .gray : .appAccent)
            }
            .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.1), radius: 5, y: -2)
        )
    }

    private func sendMessage() {
        let content = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }
        guard let senderName = sessionManager.currentUser?.name else { return }

        viewModel.sendMessage(
            conversationId: conversation.id,
            content: content,
            senderName: senderName
        )

        messageText = ""
        viewModel.draftMessages[conversation.id] = nil
    }
}

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: Message
    let isFromCurrentUser: Bool
    @ObservedObject var viewModel: MessagesViewModel
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack {
            if isFromCurrentUser { Spacer(minLength: 60) }

            VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 4) {
                // Linked reminder card if present
                if let reminder = message.linkedReminder {
                    ReminderCard(
                        message: message,
                        reminder: reminder,
                        isFromCurrentUser: isFromCurrentUser,
                        viewModel: viewModel
                    )
                }

                // Linked store card if present
                if let store = message.linkedStore {
                    StoreCard(
                        message: message,
                        store: store,
                        isFromCurrentUser: isFromCurrentUser,
                        viewModel: viewModel
                    )
                }

                // Message content
                Text(message.content)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(isFromCurrentUser ? Color.appAccent : (colorScheme == .dark ? Color.white.opacity(0.15) : Color.white))
                    )
                    .foregroundColor(isFromCurrentUser ? .white : .primary)

                // Timestamp
                Text(formatTime(message.createdAt))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            if !isFromCurrentUser { Spacer(minLength: 60) }
        }
    }

    private func formatTime(_ timestamp: TimeInterval) -> String {
        let date = Date(timeIntervalSince1970: timestamp)
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
}

// MARK: - Reminder Card

struct ReminderCard: View {
    let message: Message
    let reminder: LinkedReminder
    let isFromCurrentUser: Bool
    @ObservedObject var viewModel: MessagesViewModel
    @Environment(\.colorScheme) var colorScheme
    @State private var isProcessing = false

    // Determine if accept/reject buttons should be shown
    private var showActionButtons: Bool {
        // Only show for messages not from current user with pending status
        // Also require that the reminder has the necessary fields for acceptance
        guard !isFromCurrentUser,
              reminder.storeId != nil,
              let status = reminder.status else {
            // For older messages without status, treat as pending if not from current user
            return !isFromCurrentUser && reminder.storeId != nil
        }
        return status == .pending
    }

    private var statusText: String? {
        guard let status = reminder.status else { return nil }
        switch status {
        case .accepted:
            return "Accepted"
        case .rejected:
            return "Declined"
        case .pending:
            return nil
        }
    }

    private var statusColor: Color {
        guard let status = reminder.status else { return .gray }
        switch status {
        case .accepted:
            return .green
        case .rejected:
            return .red
        case .pending:
            return .gray
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "list.bullet.clipboard")
                    .foregroundColor(.appAccent)
                Text("Shared Reminder")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.appAccent)

                Spacer()

                // Show status badge if not pending
                if let status = statusText {
                    Text(status)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(statusColor)
                        )
                }
            }

            Text(reminder.reminderTitle)
                .font(.subheadline)
                .fontWeight(.medium)

            HStack {
                Image(systemName: "storefront")
                    .font(.caption)
                Text(reminder.storeName)
                    .font(.caption)
            }
            .foregroundColor(.secondary)

            if let address = reminder.storeAddress, !address.isEmpty {
                HStack {
                    Image(systemName: "mappin")
                        .font(.caption)
                    Text(address)
                        .font(.caption)
                        .lineLimit(1)
                }
                .foregroundColor(.secondary)
            }

            // Accept/Reject buttons for pending shared reminders
            if showActionButtons {
                HStack(spacing: 12) {
                    Button {
                        acceptReminder()
                    } label: {
                        HStack {
                            if isProcessing {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "checkmark")
                            }
                            Text("Accept")
                        }
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.green)
                        )
                    }
                    .disabled(isProcessing)

                    Button {
                        rejectReminder()
                    } label: {
                        HStack {
                            Image(systemName: "xmark")
                            Text("Decline")
                        }
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.red.opacity(0.8))
                        )
                    }
                    .disabled(isProcessing)
                }
                .padding(.top, 4)
            }
        }
        .padding(12)
        .frame(maxWidth: 250, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(colorScheme == .dark ? Color.white.opacity(0.1) : Color.gray.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.appAccent.opacity(0.3), lineWidth: 1)
                )
        )
    }

    private func acceptReminder() {
        isProcessing = true
        viewModel.acceptSharedReminder(message: message) { success in
            isProcessing = false
            if success {
                #if DEBUG
                print("ReminderCard: Successfully accepted reminder")
                #endif
            } else {
                #if DEBUG
                print("ReminderCard: Failed to accept reminder")
                #endif
            }
        }
    }

    private func rejectReminder() {
        isProcessing = true
        viewModel.rejectSharedReminder(message: message) { success in
            isProcessing = false
            if success {
                #if DEBUG
                print("ReminderCard: Successfully rejected reminder")
                #endif
            } else {
                #if DEBUG
                print("ReminderCard: Failed to reject reminder")
                #endif
            }
        }
    }
}

// MARK: - Store Card

struct StoreCard: View {
    let message: Message
    let store: LinkedStore
    let isFromCurrentUser: Bool
    @ObservedObject var viewModel: MessagesViewModel
    @Environment(\.colorScheme) var colorScheme
    @State private var isProcessing = false

    // Determine if accept/reject buttons should be shown
    private var showActionButtons: Bool {
        guard !isFromCurrentUser,
              let status = store.status else {
            return !isFromCurrentUser
        }
        return status == .pending
    }

    private var statusText: String? {
        guard let status = store.status else { return nil }
        switch status {
        case .accepted:
            return "Accepted"
        case .rejected:
            return "Declined"
        case .pending:
            return nil
        }
    }

    private var statusColor: Color {
        guard let status = store.status else { return .gray }
        switch status {
        case .accepted:
            return .green
        case .rejected:
            return .red
        case .pending:
            return .gray
        }
    }

    private var permissionText: String {
        store.permission == "edit" ? "Can Edit" : "View Only"
    }

    private var permissionColor: Color {
        store.permission == "edit" ? .green : .orange
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "storefront.fill")
                    .foregroundColor(.blue)
                Text("Shared Store")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)

                Spacer()

                // Show status badge if not pending
                if let status = statusText {
                    Text(status)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(statusColor)
                        )
                }
            }

            Text(store.storeName)
                .font(.subheadline)
                .fontWeight(.medium)

            if let address = store.storeAddress, !address.isEmpty {
                HStack {
                    Image(systemName: "mappin")
                        .font(.caption)
                    Text(address)
                        .font(.caption)
                        .lineLimit(1)
                }
                .foregroundColor(.secondary)
            }

            // Permission badge
            HStack {
                Image(systemName: store.permission == "edit" ? "pencil.circle.fill" : "eye.circle.fill")
                    .font(.caption)
                Text(permissionText)
                    .font(.caption)
            }
            .foregroundColor(permissionColor)

            // Show reminder count if available
            if let reminderTitles = store.reminderTitles, !reminderTitles.isEmpty {
                HStack {
                    Image(systemName: "list.bullet")
                        .font(.caption)
                    Text("\(reminderTitles.count) reminder(s)")
                        .font(.caption)
                }
                .foregroundColor(.secondary)
            }

            // Accept/Reject buttons for pending shared stores
            if showActionButtons {
                HStack(spacing: 12) {
                    Button {
                        acceptStore()
                    } label: {
                        HStack {
                            if isProcessing {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "checkmark")
                            }
                            Text("Accept")
                        }
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.green)
                        )
                    }
                    .disabled(isProcessing)

                    Button {
                        rejectStore()
                    } label: {
                        HStack {
                            Image(systemName: "xmark")
                            Text("Decline")
                        }
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.red.opacity(0.8))
                        )
                    }
                    .disabled(isProcessing)
                }
                .padding(.top, 4)
            }
        }
        .padding(12)
        .frame(maxWidth: 250, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(colorScheme == .dark ? Color.white.opacity(0.1) : Color.gray.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                )
        )
    }

    private func acceptStore() {
        isProcessing = true
        viewModel.acceptSharedStore(message: message) { success in
            isProcessing = false
            if success {
                #if DEBUG
                print("StoreCard: Successfully accepted store")
                #endif
            } else {
                #if DEBUG
                print("StoreCard: Failed to accept store")
                #endif
            }
        }
    }

    private func rejectStore() {
        isProcessing = true
        viewModel.rejectSharedStore(message: message) { success in
            isProcessing = false
            if success {
                #if DEBUG
                print("StoreCard: Successfully rejected store")
                #endif
            } else {
                #if DEBUG
                print("StoreCard: Failed to reject store")
                #endif
            }
        }
    }
}

#Preview {
    NavigationStack {
        ConversationView(
            conversation: Conversation(
                id: "preview",
                participantIds: ["user1", "user2"],
                participantNames: ["user1": "John", "user2": "Sarah"],
                createdAt: Date().timeIntervalSince1970,
                lastMessageContent: "Hello!",
                lastMessageAt: Date().timeIntervalSince1970,
                lastMessageSenderId: "user2",
                unreadCount: [:]
            ),
            viewModel: MessagesViewModel()
        )
    }
}
