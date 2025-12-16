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
    @State private var messageText = ""
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
                        ForEach(viewModel.messages) { message in
                            MessageBubble(
                                message: message,
                                isFromCurrentUser: viewModel.isCurrentUser(message.senderId)
                            )
                            .id(message.id)
                        }
                    }
                    .padding()
                }
                .onChange(of: viewModel.messages.count) { _, _ in
                    if let lastMessage = viewModel.messages.last {
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

            // Input bar
            inputBar
        }
        .background(Color.backgroundGradient(for: colorScheme))
        .navigationTitle(conversation.otherParticipantName(currentUserId: currentUserId))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.fetchMessages(for: conversation.id)
            viewModel.markAsRead(conversationId: conversation.id)
        }
        .onDisappear {
            viewModel.markAsRead(conversationId: conversation.id)
        }
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
    }
}

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: Message
    let isFromCurrentUser: Bool
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack {
            if isFromCurrentUser { Spacer(minLength: 60) }

            VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 4) {
                // Linked reminder card if present
                if let reminder = message.linkedReminder {
                    ReminderCard(reminder: reminder, isFromCurrentUser: isFromCurrentUser)
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
    let reminder: LinkedReminder
    let isFromCurrentUser: Bool
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "list.bullet.clipboard")
                    .foregroundColor(.appAccent)
                Text("Shared Reminder")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.appAccent)
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
