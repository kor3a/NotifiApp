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
    @Environment(\.dismiss) private var dismiss

    // Photo sharing state
    @State private var selectedImages: [UIImage] = []
    @State private var showImagePicker = false
    @State private var isSendingPhoto = false
    @State private var showGroupInfo = false
    @State private var showingBackgroundPicker = false

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
                                showSenderName: conversation.isGroupConversation,
                                viewModel: viewModel
                            )
                            .id(message.id)

                            // Insert a banner ad after every 5th message (hidden for subscribers)
                            if (index + 1) % 5 == 0 && !subscriptionManager.isSubscribed {
                                BannerAdView(adUnitID: kBannerAdUnitID)
                                    .frame(height: 50)
                                    .background(OrganicPalette.surface(colorScheme))
                                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
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
                    .background(OrganicPalette.canvas(colorScheme))
            }

            // Input bar
            inputBar
        }
        .background(SurfaceBackground(
            surface: .conversation(id: conversation.id),
            systemDefault: OrganicPalette.canvas(colorScheme)
        ))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(OrganicPalette.canvas(colorScheme), for: .navigationBar)
        .tint(OrganicPalette.terracotta(colorScheme))
        .toolbar {
            ToolbarItem(placement: .principal) {
                Button(action: {
                    if conversation.isGroupConversation { showGroupInfo = true }
                }) {
                    VStack(spacing: 1) {
                        Text(conversation.displayName(currentUserId: currentUserId))
                            .font(OrganicPalette.title(17))
                            .foregroundColor(OrganicPalette.ink(colorScheme))

                        if conversation.isGroupConversation {
                            Text("\(conversation.participantIds.count) members")
                                .font(.system(size: 12))
                                .foregroundColor(OrganicPalette.inkSoft(colorScheme))
                        } else if let otherId = conversation.otherParticipantId(currentUserId: currentUserId) {
                            Text("@\(otherId)")
                                .font(.system(size: 12))
                                .foregroundColor(OrganicPalette.inkSoft(colorScheme))
                        }
                    }
                }
                .disabled(!conversation.isGroupConversation)
            }

            if conversation.isGroupConversation {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showGroupInfo = true }) {
                        Image(systemName: "person.3")
                    }
                }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        showingBackgroundPicker = true
                    } label: {
                        Label("Change Background", systemImage: "photo.on.rectangle.angled")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("Chat options")
            }
        }
        .sheet(isPresented: $showingBackgroundPicker) {
            // Keyed to this conversation, so every chat keeps its own look.
            BackgroundPickerView(
                surface: .conversation(id: conversation.id),
                title: conversation.displayName(currentUserId: currentUserId),
                systemDefault: OrganicPalette.canvas(colorScheme)
            )
        }
        .sheet(isPresented: $showGroupInfo) {
            GroupInfoView(conversation: conversation, viewModel: viewModel, onLeaveGroup: {
                dismiss()
            })
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
            .foregroundColor(OrganicPalette.inkSoft(colorScheme))
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
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(OrganicPalette.surface(colorScheme))
                )
                .padding(.horizontal)
                .padding(.top, 8)
            }

            // Single rounded input field containing the photo, text and send controls
            HStack(alignment: .bottom, spacing: 8) {
                // Photo picker button (inside the field, on the left)
                Button {
                    showImagePicker = true
                } label: {
                    Image(systemName: "photo")
                        .font(.system(size: 21))
                        .foregroundColor(OrganicPalette.terracotta(colorScheme))
                        .frame(width: 32, height: 32)
                }
                .disabled(isSendingPhoto)

                TextField(
                    "",
                    text: $messageText,
                    prompt: Text("Type a message\u{2026}")
                        .foregroundColor(OrganicPalette.inkSoft(colorScheme).opacity(0.8)),
                    axis: .vertical
                )
                .textFieldStyle(.plain)
                .font(OrganicPalette.body(17))
                .foregroundColor(OrganicPalette.ink(colorScheme))
                .padding(.vertical, 6)
                .focused($isInputFocused)
                .lineLimit(1...5)

                // Send button (inside the field, on the right)
                if isSendingPhoto {
                    ProgressView()
                        .tint(OrganicPalette.terracotta(colorScheme))
                        .frame(width: 34, height: 34)
                } else {
                    Button(action: sendMessage) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 34, height: 34)
                            .background(
                                Circle().fill(
                                    canSend
                                        ? OrganicPalette.terracotta(colorScheme)
                                        : OrganicPalette.inkSoft(colorScheme).opacity(0.35)
                                )
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(!canSend)
                    .accessibilityLabel("Send")
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(OrganicPalette.surface(colorScheme))
                    .shadow(color: OrganicPalette.shadow(colorScheme), radius: 8, x: 0, y: 3)
            )
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(selectedImage: .constant(nil), allowsEditing: false) { image in
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
    var showSenderName: Bool = false
    @ObservedObject var viewModel: MessagesViewModel
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack {
            if isFromCurrentUser { Spacer(minLength: 60) }

            VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 4) {
                // Sender name label (group conversations only, incoming messages)
                if showSenderName && !isFromCurrentUser {
                    Text(message.senderName)
                        .font(OrganicPalette.title(12))
                        .foregroundColor(OrganicPalette.inkSoft(colorScheme))
                        .padding(.horizontal, 6)
                }

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
                        .font(OrganicPalette.body(16))
                        .textSelection(.enabled)
                        .padding(.horizontal, 15)
                        .padding(.vertical, 11)
                        .background(
                            // Bubbles carry their own fill because the chat
                            // backdrop is the user's to choose — it can be any
                            // palette color, or a photo.
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(
                                    isFromCurrentUser
                                        ? OrganicPalette.terracotta(colorScheme)
                                        : OrganicPalette.surface(colorScheme)
                                )
                                .shadow(color: OrganicPalette.shadow(colorScheme), radius: 6, x: 0, y: 2)
                        )
                        .foregroundColor(
                            isFromCurrentUser ? .white : OrganicPalette.ink(colorScheme)
                        )
                }

                // Timestamp
                Text(formatTime(message.createdAt))
                    .font(.system(size: 11))
                    .foregroundColor(OrganicPalette.inkSoft(colorScheme))
                    .padding(.horizontal, 6)
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

// MARK: - Shared Item Card Chrome

/// The Accepted / Declined badge on a shared reminder or store. Both outcomes
/// stay quiet — the card has already been dealt with, so neither needs the
/// weight of a saturated status color.
private struct ShareStatusBadge: View {
    let text: String
    let isAccepted: Bool

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(
                isAccepted
                    ? OrganicPalette.sageInk(colorScheme)
                    : OrganicPalette.inkSoft(colorScheme)
            )
            .padding(.horizontal, 9)
            .padding(.vertical, 3)
            .background(
                Capsule().fill(
                    isAccepted
                        ? OrganicPalette.sage(colorScheme)
                        : OrganicPalette.outline(colorScheme).opacity(0.4)
                )
            )
    }
}

/// The Accept / Decline pair shared by the reminder and store cards. Accept is
/// the solid one because it's the answer the sender is hoping for; declining
/// stays an outline so it never reads as the recommended move.
private struct ShareActionButtons: View {
    let isProcessing: Bool
    let onAccept: () -> Void
    let onDecline: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onAccept) {
                HStack(spacing: 5) {
                    if isProcessing {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(0.7)
                    } else {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                    }
                    Text("Accept")
                        .font(OrganicPalette.title(14))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 36)
                .background(Capsule().fill(OrganicPalette.sageInk(colorScheme)))
            }
            .buttonStyle(.plain)
            .disabled(isProcessing)

            Button(action: onDecline) {
                Text("Decline")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(OrganicPalette.inkSoft(colorScheme))
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
                    .overlay(
                        Capsule().stroke(OrganicPalette.outline(colorScheme), lineWidth: 1.5)
                    )
            }
            .buttonStyle(.plain)
            .disabled(isProcessing)
        }
        .padding(.top, 4)
    }
}

/// One "storefront · Trader Joe's" style detail line inside a shared card.
private struct ShareDetailRow: View {
    let systemImage: String
    let text: String
    var tint: Color?

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: systemImage)
                .font(.system(size: 11))
            Text(text)
                .font(.system(size: 13))
                .lineLimit(1)
        }
        .foregroundColor(tint ?? OrganicPalette.inkSoft(colorScheme))
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

    private var isAccepted: Bool {
        reminder.status == .accepted
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "list.bullet.clipboard")
                    .font(.system(size: 12, weight: .semibold))
                Text("Shared reminder")
                    .font(OrganicPalette.title(12))
                    .kerning(0.3)

                Spacer(minLength: 6)

                // Show status badge if not pending
                if let status = statusText {
                    ShareStatusBadge(text: status, isAccepted: isAccepted)
                }
            }
            .foregroundColor(OrganicPalette.terracotta(colorScheme))

            Text(reminder.reminderTitle)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(OrganicPalette.ink(colorScheme))

            ShareDetailRow(systemImage: "storefront", text: reminder.storeName)

            if let address = reminder.storeAddress, !address.isEmpty {
                ShareDetailRow(systemImage: "mappin", text: address)
            }

            // Accept/Reject buttons for pending shared reminders
            if showActionButtons {
                ShareActionButtons(
                    isProcessing: isProcessing,
                    onAccept: acceptReminder,
                    onDecline: rejectReminder
                )
            }
        }
        .padding(14)
        .frame(maxWidth: 250, alignment: .leading)
        .background(OrganicCardBackground(colorScheme: colorScheme, cornerRadius: 20))
    }

    private func acceptReminder() {
        isProcessing = true
        viewModel.acceptSharedReminder(message: message) { success in
            isProcessing = false
            #if DEBUG
            if success {
                print("ReminderCard: Successfully accepted reminder")
            } else {
                print("ReminderCard: Failed to accept reminder")
            }
            #endif
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

    private var isAccepted: Bool {
        store.status == .accepted
    }

    private var permissionText: String {
        store.permission == "edit" ? "Can edit" : "View only"
    }

    /// Edit access is the notable one — it says the recipient can change a list
    /// the sender also owns — so it carries the sage. View-only stays quiet.
    private var permissionColor: Color {
        store.permission == "edit"
            ? OrganicPalette.sageInk(colorScheme)
            : OrganicPalette.inkSoft(colorScheme)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "storefront.fill")
                    .font(.system(size: 12, weight: .semibold))
                Text("Shared store")
                    .font(OrganicPalette.title(12))
                    .kerning(0.3)

                Spacer(minLength: 6)

                // Show status badge if not pending
                if let status = statusText {
                    ShareStatusBadge(text: status, isAccepted: isAccepted)
                }
            }
            .foregroundColor(OrganicPalette.sageInk(colorScheme))

            Text(store.storeName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(OrganicPalette.ink(colorScheme))

            if let address = store.storeAddress, !address.isEmpty {
                ShareDetailRow(systemImage: "mappin", text: address)
            }

            // Permission badge
            ShareDetailRow(
                systemImage: store.permission == "edit" ? "pencil.circle.fill" : "eye.circle.fill",
                text: permissionText,
                tint: permissionColor
            )

            // Show reminder count if available
            if let reminderTitles = store.reminderTitles, !reminderTitles.isEmpty {
                ShareDetailRow(
                    systemImage: "list.bullet",
                    text: reminderTitles.count == 1 ? "1 reminder" : "\(reminderTitles.count) reminders"
                )
            }

            // Accept/Reject buttons for pending shared stores
            if showActionButtons {
                ShareActionButtons(
                    isProcessing: isProcessing,
                    onAccept: acceptStore,
                    onDecline: rejectStore
                )
            }
        }
        .padding(14)
        .frame(maxWidth: 250, alignment: .leading)
        .background(OrganicCardBackground(colorScheme: colorScheme, cornerRadius: 20))
        .alert("Merge Lists?", isPresented: $showMergeAlert) {
            Button("Merge", role: .none) {
                performAccept()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("You already have \(store.storeName) in your list. Accepting combines both lists into one shared list — everything either of you adds, checks off or removes from now on shows up for both of you.")
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
    @Environment(\.colorScheme) private var colorScheme

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
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .onTapGesture {
                                selectedPhotoURL = urlString
                            }
                    case .failure:
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(OrganicPalette.field(colorScheme))
                            .frame(height: 100)
                            .overlay(
                                Image(systemName: "photo")
                                    .foregroundColor(OrganicPalette.inkSoft(colorScheme))
                            )
                    case .empty:
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(OrganicPalette.field(colorScheme))
                            .frame(height: 100)
                            .overlay(ProgressView().tint(OrganicPalette.terracotta(colorScheme)))
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
