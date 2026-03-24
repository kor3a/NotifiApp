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

    // Photo sharing state
    @State private var selectedImages: [UIImage] = []
    @State private var showImagePicker = false
    @State private var isSendingPhoto = false

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
                .refreshable {
                    if viewModel.hasMoreMessages {
                        scrolledToTopMessageId = viewModel.messages.first?.id
                        viewModel.loadMoreMessages()
                    }
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: viewModel.messages.count) { oldCount, newCount in
                    if newCount > oldCount {
                        if let anchorId = scrolledToTopMessageId {
                            // Earlier messages were loaded — defer scroll so the new items are
                            // laid out first, then snap back to the previously-top message
                            scrolledToTopMessageId = nil
                            DispatchQueue.main.async {
                                proxy.scrollTo(anchorId, anchor: .top)
                            }
                        } else if let lastMessage = viewModel.messages.last {
                            // New message received — scroll to bottom
                            scrolledToTopMessageId = nil
                            withAnimation {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    } else {
                        scrolledToTopMessageId = nil
                    }
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
            MessagingService.shared.activeConversationId = conversation.id
        }
        .onChange(of: messageText) { _, newValue in
            viewModel.draftMessages[conversation.id] = newValue
        }
        .onDisappear {
            MessagingService.shared.activeConversationId = nil
            viewModel.markAsRead(conversationId: conversation.id)
            viewModel.stopListeningForMessages()
            // If the user navigated away without sending any messages, delete the empty
            // conversation so it doesn't linger in the conversation list.
            let latestConversation = viewModel.conversations.first(where: { $0.id == conversation.id }) ?? conversation
            if viewModel.messages.isEmpty && (latestConversation.lastMessageContent?.isEmpty ?? true) {
                viewModel.deleteConversation(latestConversation)
            }
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
        VStack(spacing: 0) {
            // Selected photos preview strip
            if !selectedImages.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(selectedImages.enumerated()), id: \.offset) { index, image in
                            ZStack(alignment: .topTrailing) {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxHeight: 80)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))

                                Button {
                                    selectedImages.remove(at: index)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 18))
                                        .foregroundColor(.white)
                                        .background(Color.black.opacity(0.6), in: Circle())
                                }
                                .offset(x: 6, y: -6)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
                .background(colorScheme == .dark ? Color.white.opacity(0.05) : Color.gray.opacity(0.07))

                Divider()
            }

            HStack(spacing: 12) {
                // Photo picker button
                Button {
                    showImagePicker = true
                } label: {
                    Image(systemName: "photo")
                        .font(.system(size: 22))
                        .foregroundColor(.appAccent)
                }
                .disabled(isSendingPhoto)

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

                if isSendingPhoto {
                    ProgressView()
                        .frame(width: 32, height: 32)
                } else {
                    Button(action: sendMessage) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(canSend ? .appAccent : .gray)
                    }
                    .disabled(!canSend)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.1), radius: 5, y: -2)
        )
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(selectedImage: .constant(nil)) { image in
                selectedImages.append(image)
            }
        }
    }

    private var canSend: Bool {
        !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !selectedImages.isEmpty
    }

    private func sendMessage() {
        let content = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard canSend else { return }
        guard let senderName = sessionManager.currentUser?.name else { return }

        let imagesToSend = selectedImages
        messageText = ""
        selectedImages = []
        viewModel.draftMessages[conversation.id] = nil

        if imagesToSend.isEmpty {
            viewModel.sendMessage(
                conversationId: conversation.id,
                content: content,
                senderName: senderName
            )
        } else {
            isSendingPhoto = true
            viewModel.sendMessageWithPhotos(
                conversationId: conversation.id,
                content: content,
                images: imagesToSend,
                senderName: senderName
            ) { _ in
                DispatchQueue.main.async {
                    isSendingPhoto = false
                }
            }
        }
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

                // Photo attachments
                if let photoURLs = message.photoURLs, !photoURLs.isEmpty {
                    PhotoAttachmentsView(photoURLs: photoURLs)
                }

                // Message content (only show if non-empty)
                if !message.content.isEmpty {
                    Text(message.content)
                        .textSelection(.enabled)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 18)
                                .fill(isFromCurrentUser ? Color.appAccent : (colorScheme == .dark ? Color.white.opacity(0.15) : Color.white))
                        )
                        .foregroundColor(isFromCurrentUser ? .white : .primary)
                }

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
    @State private var showMergeAlert = false

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
        .alert("Merge Lists?", isPresented: $showMergeAlert) {
            Button("Merge", role: .none) {
                performAccept()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("You already have \(store.storeName) in your list. Accepting will merge the reminder lists — items from \(message.senderName) that you don't have yet will be added with a shared indicator.")
        }
    }

    private func acceptStore() {
        isProcessing = true
        viewModel.checkIfUserHasStore(storeId: store.storeId) { hasDuplicate in
            if hasDuplicate {
                isProcessing = false
                showMergeAlert = true
            } else {
                performAccept()
            }
        }
    }

    private func performAccept() {
        isProcessing = true
        viewModel.acceptSharedStore(message: message) { success in
            isProcessing = false
            #if DEBUG
            if success {
                print("StoreCard: Successfully accepted store")
            } else {
                print("StoreCard: Failed to accept store")
            }
            #endif
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

// MARK: - Photo Attachments View

struct PhotoAttachmentsView: View {
    let photoURLs: [String]
    @State private var selectedPhotoURL: String?

    var body: some View {
        let columns = photoURLs.count == 1
            ? [GridItem(.flexible())]
            : [GridItem(.flexible()), GridItem(.flexible())]

        LazyVGrid(columns: columns, spacing: 4) {
            ForEach(photoURLs, id: \.self) { urlString in
                AsyncImage(url: URL(string: urlString)) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .onTapGesture {
                                selectedPhotoURL = urlString
                            }
                    case .failure:
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 100)
                            .overlay(Image(systemName: "photo").foregroundColor(.secondary))
                    case .empty:
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 100)
                            .overlay(ProgressView())
                    @unknown default:
                        EmptyView()
                    }
                }
            }
        }
        .frame(maxWidth: 220)
        .fullScreenCover(item: Binding(
            get: { selectedPhotoURL.map { IdentifiableURL(url: $0) } },
            set: { selectedPhotoURL = $0?.url }
        )) { item in
            PhotoFullScreenView(urlString: item.url)
        }
    }
}

private struct IdentifiableURL: Identifiable {
    let id = UUID()
    let url: String
}

struct PhotoFullScreenView: View {
    let urlString: String
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            AsyncImage(url: URL(string: urlString)) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                case .failure:
                    Image(systemName: "photo")
                        .foregroundColor(.white)
                case .empty:
                    ProgressView()
                        .tint(.white)
                @unknown default:
                    EmptyView()
                }
            }

            VStack {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.white)
                            .padding()
                    }
                }
                Spacer()
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
