//
//  ShareStoreView.swift
//  Geolocation_v1.0.0
//
//  Created by Claude on 11/21/24.
//

import SwiftUI
import FirebaseFirestore

struct SharedUser: Identifiable {
    let id: String // user_store document ID
    let userId: String // The user's ID for messaging
    let userEmail: String
    let permission: StorePermission
    let sharedAt: TimeInterval?
}

struct ShareStoreView: View {
    // MARK: - PROPERTIES

    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject var viewModel: StoresViewModel
    @ObservedObject var messagesViewModel: MessagesViewModel
    let userStoreItem: UserStoreItem

    @StateObject private var friendsViewModel = FriendsViewModel()
    @State private var recipientEmail: String = ""
    @State private var selectedPermission: StorePermission = .edit
    @State private var isSharing: Bool = false
    @State private var showAlert: Bool = false
    @State private var alertMessage: String = ""
    @State private var alertTitle: String = ""
    @State private var sharedUsers: [SharedUser] = []
    @State private var isLoadingSharedUsers: Bool = false
    @State private var reminderTitles: [String] = []
    @State private var selectedFriend: Contact?
    @State private var isSharingWithAllFamily: Bool = false
    @State private var familyShareProgress: String = ""

    private let db = Firestore.firestore()
    private let messagingService = MessagingService.shared

    // MARK: - BODY

    var body: some View {
        NavigationStack {
            ZStack {
                Color.backgroundGradient(for: colorScheme)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Store Info — hero header
                        storeHeader

                        // Show who shared the store with the current user (if applicable)
                        if let sharedByName = userStoreItem.sharedFromName {
                            sharedBySection(sharedByName: sharedByName)
                        }

                        // Shared Users List
                        if !sharedUsers.isEmpty {
                            sharedWithSection
                        }

                        // Only show sharing UI if user is the owner (not a recipient)
                        if userStoreItem.sharedFromName == nil {
                            // Family Section
                            if !friendsViewModel.familyMembers.isEmpty {
                                familySection
                            }

                            // Friends Section
                            if !friendsViewModel.friends.isEmpty {
                                friendsSection
                            }

                            if selectedFriend != nil {
                                selectedFriendChip
                            }

                            if !friendsViewModel.friends.isEmpty || !friendsViewModel.familyMembers.isEmpty {
                                HStack {
                                    Rectangle()
                                        .fill(Color.secondary.opacity(0.25))
                                        .frame(height: 1)
                                    Text("or enter email manually")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .fixedSize()
                                    Rectangle()
                                        .fill(Color.secondary.opacity(0.25))
                                        .frame(height: 1)
                                }
                                .padding(.vertical, 4)
                            }

                            // Email Input
                            emailInputSection

                            // Permission Selection
                            permissionSection

                            // Info Text
                            infoCallout(
                                icon: "info.circle.fill",
                                tint: .appAccent,
                                text: "A share request will be sent to the recipient's messages. They must accept before the store appears in their list. The recipient must have an account with the email address you provide."
                            )

                            // Show reminder count
                            if !reminderTitles.isEmpty {
                                infoCallout(
                                    icon: "checklist",
                                    tint: .appSuccess,
                                    text: "\(reminderTitles.count) active reminder\(reminderTitles.count == 1 ? "" : "s") will be included with this store."
                                )
                            }
                        } // End of owner-only sharing UI
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Share Store")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        inviteFriends()
                    }) {
                        Image(systemName: "square.and.arrow.up.badge.checkmark")
                    }
                    .accessibilityLabel("Invite Friends")
                }
                // Break the shared Liquid Glass capsule so the invite button
                // renders in its own circle, separate from the Share button.
                if #available(iOS 26.0, *) {
                    ToolbarSpacer(.fixed, placement: .navigationBarTrailing)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if isSharing {
                        ProgressView()
                    } else {
                        Button("Share") {
                            shareStore()
                        }
                        .fontWeight(.semibold)
                        .disabled(recipientEmail.trimmingCharacters(in: .whitespaces).isEmpty || isSharingWithAllFamily)
                    }
                }
            }
            .alert(alertTitle, isPresented: $showAlert) {
                Button("OK") {
                    if alertTitle == "Success" {
                        fetchSharedUsers()
                        recipientEmail = ""
                        dismiss()
                    }
                }
            } message: {
                Text(alertMessage)
            }
            .onAppear {
                fetchSharedUsers()
                fetchReminderTitles()
                friendsViewModel.fetchFriendships()
            }
            .onDisappear {
                friendsViewModel.stopListening()
            }
        }
    }

    // MARK: - SUBVIEWS

    /// Hero header showing the store being shared.
    private var storeHeader: some View {
        HStack(spacing: 16) {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.iconGradient)
                .frame(width: 60, height: 60)
                .overlay(
                    Image(systemName: "cart.fill")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(.white)
                )
                .shadow(color: Color.appAccent.opacity(0.35), radius: 8, x: 0, y: 4)

            VStack(alignment: .leading, spacing: 4) {
                Text("Sharing")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                Text(userStoreItem.store.name)
                    .font(.title2)
                    .fontWeight(.bold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Text("All locations")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(18)
        .cardStyle()
    }

    /// Section shown to a recipient describing who shared the store with them.
    private func sharedBySection(sharedByName: String) -> some View {
        sectionContainer(title: "Shared By", icon: "person.fill.badge.plus", tint: .appAccent) {
            HStack(spacing: 12) {
                Circle()
                    .fill(Color.appAccent.opacity(0.15))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Text(String(sharedByName.prefix(1)).uppercased())
                            .font(.headline)
                            .foregroundStyle(Color.appAccent)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(sharedByName)
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Text(userStoreItem.permission == .edit ? "Can Edit" : "View Only")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                permissionBadge(userStoreItem.permission)
            }
        }
    }

    /// List of users this store is currently shared with.
    private var sharedWithSection: some View {
        sectionContainer(title: "Shared With", icon: "person.2.fill", tint: .appSuccess) {
            VStack(spacing: 10) {
                ForEach(sharedUsers) { sharedUser in
                    sharedUserRow(sharedUser)
                }
            }
        }
    }

    /// A single row in the "Shared With" list.
    private func sharedUserRow(_ sharedUser: SharedUser) -> some View {
        let isView = sharedUser.permission == .view
        let tint: Color = isView ? .appWarning : .appSuccess

        return HStack(spacing: 12) {
            Circle()
                .fill(tint.opacity(0.15))
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: isView ? "eye.fill" : "person.fill.checkmark")
                        .foregroundStyle(tint)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(sharedUser.userEmail)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)

                Text(isView ? "View Only" : "Can Edit")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            Button(action: {
                unshareWithUser(sharedUser)
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(Color.appError.opacity(0.8))
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.primary.opacity(colorScheme == .dark ? 0.06 : 0.03))
        )
    }

    /// Horizontally scrolling family member avatars.
    private var familySection: some View {
        sectionContainer(title: "Share with Family", icon: "house.fill", tint: .purple) {
            VStack(alignment: .leading, spacing: 12) {
                if isSharingWithAllFamily {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text(familyShareProgress)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.purple.opacity(0.1))
                    )
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        allFamilyButton

                        ForEach(friendsViewModel.familyMembers) { friendship in
                            contactAvatarButton(
                                contact: friendship.toContact(currentUserId: currentUserId),
                                tint: .purple,
                                badge: "house.fill"
                            )
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    /// The "All Family" quick-share chip.
    private var allFamilyButton: some View {
        Button(action: {
            shareWithAllFamily()
        }) {
            avatarChip(
                name: "All Family",
                isShared: allFamilyAlreadyShared,
                tint: .purple,
                avatar: AnyView(
                    Circle()
                        .fill(Color.purple.opacity(0.15))
                        .overlay(
                            Image(systemName: "person.3.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(.purple)
                        )
                )
            )
        }
        .buttonStyle(.plain)
        .disabled(isSharingWithAllFamily || isSharing || allFamilyAlreadyShared)
    }

    /// Horizontally scrolling friend avatars.
    private var friendsSection: some View {
        sectionContainer(title: "Share with Friends", icon: "person.2.fill", tint: .appAccent) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(friendsViewModel.friends) { friendship in
                        contactAvatarButton(
                            contact: friendship.toContact(currentUserId: currentUserId),
                            tint: .appAccent
                        )
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    /// A tappable avatar button for a single contact, used by the family and
    /// friends rows. Selecting it pre-fills the recipient email.
    private func contactAvatarButton(contact: Contact, tint: Color, badge: String? = nil) -> some View {
        let isAlreadyShared = sharedUsers.contains { $0.userEmail.lowercased() == contact.email.lowercased() }

        return Button(action: {
            if !isAlreadyShared {
                selectedFriend = contact
                recipientEmail = contact.email
            }
        }) {
            avatarChip(
                name: contact.name,
                isShared: isAlreadyShared,
                tint: tint,
                badge: badge,
                badgeTint: tint,
                avatar: AnyView(
                    ProfilePictureView(profilePictureURL: contact.profilePictureURL, size: 56) {
                        Circle()
                            .fill(tint.opacity(0.15))
                            .overlay(
                                Text(String(contact.name.prefix(1)).uppercased())
                                    .font(.headline)
                                    .foregroundStyle(tint)
                            )
                    }
                )
            )
        }
        .buttonStyle(.plain)
        .disabled(isAlreadyShared)
    }

    /// Chip confirming the currently selected friend/family recipient.
    private var selectedFriendChip: some View {
        HStack(spacing: 10) {
            Image(systemName: "person.fill.checkmark")
                .foregroundStyle(Color.appAccent)
            Text("Selected: \(selectedFriend?.name ?? "")")
                .font(.subheadline)
                .fontWeight(.medium)
            Spacer(minLength: 0)
            Button(action: {
                selectedFriend = nil
                recipientEmail = ""
            }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.appAccent.opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.appAccent.opacity(0.3), lineWidth: 1)
                )
        )
    }

    /// Manual email entry.
    private var emailInputSection: some View {
        sectionContainer(title: "Recipient's Email", icon: "envelope.fill", tint: .appAccent) {
            TextField("Enter email address", text: $recipientEmail)
                .textInputAutocapitalization(.never)
                .keyboardType(.emailAddress)
                .autocorrectionDisabled()
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.primary.opacity(colorScheme == .dark ? 0.08 : 0.04))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                        )
                )
                .onChange(of: recipientEmail) { _, newValue in
                    // Clear selected friend if email changes
                    if selectedFriend != nil && newValue != selectedFriend?.email {
                        selectedFriend = nil
                    }
                }
        }
    }

    /// Permission picker plus an explanation of the selected mode.
    private var permissionSection: some View {
        sectionContainer(title: "Permission", icon: "lock.shield.fill", tint: .appAccent) {
            VStack(alignment: .leading, spacing: 12) {
                Picker("Permission", selection: $selectedPermission) {
                    Text("Can Edit").tag(StorePermission.edit)
                    Text("View Only").tag(StorePermission.view)
                }
                .pickerStyle(.segmented)

                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: selectedPermission == .edit ? "pencil.circle.fill" : "eye.circle.fill")
                        .foregroundStyle(selectedPermission == .edit ? Color.appSuccess : Color.appWarning)

                    Text(selectedPermission == .edit
                        ? "Can Edit: Recipient gets full ownership. Changes and deletions sync between both users."
                        : "View Only: Recipient can view reminders but cannot edit, share, delete, or check them off.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill((selectedPermission == .edit ? Color.appSuccess : Color.appWarning).opacity(0.1))
                )
            }
        }
    }

    // MARK: - Reusable building blocks

    /// A titled card container used by most sections.
    private func sectionContainer<Content: View>(
        title: String,
        icon: String,
        tint: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.subheadline)
                    .foregroundStyle(tint)
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }

            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .cardStyle()
    }

    /// A small pill describing a permission level.
    private func permissionBadge(_ permission: StorePermission) -> some View {
        let isEdit = permission == .edit
        return Text(isEdit ? "Edit" : "View")
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundStyle(isEdit ? Color.appSuccess : Color.appWarning)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill((isEdit ? Color.appSuccess : Color.appWarning).opacity(0.15))
            )
    }

    /// A circular avatar chip with a name label and a shared/selectable state.
    /// `avatar` is type-erased to keep the call sites' type-checking cheap.
    private func avatarChip(
        name: String,
        isShared: Bool,
        tint: Color,
        badge: String? = nil,
        badgeTint: Color = .purple,
        avatar: AnyView
    ) -> some View {
        VStack(spacing: 8) {
            ZStack(alignment: .bottomTrailing) {
                avatarCircle(isShared: isShared, avatar: avatar)

                if let badge, !isShared {
                    Image(systemName: badge)
                        .font(.system(size: 9))
                        .foregroundStyle(.white)
                        .padding(4)
                        .background(badgeTint)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 1.5))
                        .offset(x: 2, y: 2)
                }
            }

            Text(name)
                .font(.caption)
                .foregroundStyle(isShared ? Color.secondary : Color.primary)
                .lineLimit(1)
                .frame(width: 64)
        }
        .opacity(isShared ? 0.7 : 1.0)
    }

    /// The 56pt circular avatar, showing a checkmark when already shared.
    @ViewBuilder
    private func avatarCircle(isShared: Bool, avatar: AnyView) -> some View {
        Group {
            if isShared {
                Circle()
                    .fill(Color.appSuccess.opacity(0.18))
                    .overlay(
                        Image(systemName: "checkmark")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(Color.appSuccess)
                    )
            } else {
                avatar
            }
        }
        .frame(width: 56, height: 56)
        .clipShape(Circle())
    }

    /// A tinted informational callout row.
    private func infoCallout(icon: String, tint: Color, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(tint)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(tint.opacity(0.1))
        )
    }

    // MARK: - Computed Properties

    private var currentUserId: String {
        viewModel.sessionManager.currentUser?.userId ?? ""
    }

    private var allFamilyAlreadyShared: Bool {
        friendsViewModel.familyMembers.allSatisfy { friendship in
            let contact = friendship.toContact(currentUserId: currentUserId)
            return sharedUsers.contains { $0.userEmail.lowercased() == contact.email.lowercased() }
        }
    }

    // MARK: - FUNCTIONS

    /// Copies Allim's App Store link so the user can invite friends who don't have the app yet.
    private func inviteFriends() {
        AppInvite.copyLinkToClipboard()
        alertTitle = "Invite Friends"
        alertMessage = AppInvite.linkCopiedMessage
        showAlert = true
    }

    private func shareWithAllFamily() {
        guard let currentUserName = viewModel.sessionManager.currentUser?.name else {
            alertTitle = "Error"
            alertMessage = "No user data available."
            showAlert = true
            return
        }

        let userId = viewModel.sessionManager.currentUser?.userId ?? ""
        let permissionString = selectedPermission == .edit ? "edit" : "view"

        // Get all family members who haven't been shared with yet
        let unsahredFamily = friendsViewModel.familyMembers.compactMap { friendship -> Contact? in
            let contact = friendship.toContact(currentUserId: userId)
            let isAlreadyShared = sharedUsers.contains { $0.userEmail.lowercased() == contact.email.lowercased() }
            return isAlreadyShared ? nil : contact
        }

        guard !unsahredFamily.isEmpty else {
            alertTitle = "Already Shared"
            alertMessage = "This store is already shared with all family members."
            showAlert = true
            return
        }

        isSharingWithAllFamily = true
        familyShareProgress = "Sharing with 0/\(unsahredFamily.count) family members..."

        var successCount = 0
        var failCount = 0
        let total = unsahredFamily.count
        let group = DispatchGroup()

        for contact in unsahredFamily {
            group.enter()

            // Send the share regardless of whether the recipient already has the store —
            // if they do, they will be prompted to merge their reminder lists on acceptance.
            messagesViewModel.shareStore(
                userStoreItem: userStoreItem,
                to: contact,
                permission: permissionString,
                currentUserName: currentUserName,
                reminderTitles: reminderTitles
            ) { success in
                if success {
                    successCount += 1
                } else {
                    failCount += 1
                }
                DispatchQueue.main.async {
                    familyShareProgress = "Sharing with \(successCount + failCount)/\(total) family members..."
                }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            isSharingWithAllFamily = false
            familyShareProgress = ""
            fetchSharedUsers()
            selectedFriend = nil
            recipientEmail = ""

            if successCount == total {
                alertTitle = "Success"
                alertMessage = "Share requests sent to all \(total) family member(s)! They will see it in their messages."
            } else if successCount > 0 {
                alertTitle = "Partially Shared"
                alertMessage = "Shared with \(successCount) of \(total) family members. \(failCount) could not be shared (may already have this store)."
            } else {
                alertTitle = "Error"
                alertMessage = "Failed to share with family members. They may already have this store."
            }
            showAlert = true
        }
    }

    private func shareStore() {
        #if DEBUG
        print("ShareStoreView: shareStore() called - NEW MESSAGE-BASED FLOW")
        #endif

        // Validate email format
        guard isValidEmail(recipientEmail) else {
            alertTitle = "Invalid Email"
            alertMessage = "Please enter a valid email address."
            showAlert = true
            return
        }

        guard let currentUserId = viewModel.sessionManager.currentUser?.userId,
              let currentUserName = viewModel.sessionManager.currentUser?.name else {
            alertTitle = "Error"
            alertMessage = "No user data available."
            showAlert = true
            return
        }

        let cleanedEmail = recipientEmail.lowercased().trimmingCharacters(in: .whitespaces)

        // Check if trying to share with self
        if cleanedEmail == viewModel.sessionManager.currentUser?.email.lowercased() {
            alertTitle = "Error"
            alertMessage = "You cannot share a store with yourself."
            showAlert = true
            return
        }

        isSharing = true
        #if DEBUG
        print("ShareStoreView: Looking up user by email: \(cleanedEmail)")
        #endif

        // First, find the recipient user by email
        messagingService.searchUserByEmail(cleanedEmail) { [self] result in
            switch result {
            case .success(let contact):
                guard let contact = contact else {
                    DispatchQueue.main.async {
                        self.isSharing = false
                        self.alertTitle = "Error"
                        self.alertMessage = "No user found with this email address. Make sure the recipient has an account."
                        self.showAlert = true
                    }
                    return
                }

                #if DEBUG
                print("ShareStoreView: Found contact: \(contact.name) (\(contact.id))")
                #endif

                // Send the store share request via messaging.
                // Even if the recipient already has this store we allow the share —
                // they will be prompted to merge their reminder lists on acceptance.
                let permissionString = self.selectedPermission == .edit ? "edit" : "view"
                self.messagesViewModel.shareStore(
                    userStoreItem: self.userStoreItem,
                    to: contact,
                    permission: permissionString,
                    currentUserName: currentUserName,
                    reminderTitles: self.reminderTitles
                ) { success in
                    #if DEBUG
                    print("ShareStoreView: messagesViewModel.shareStore completed with success=\(success)")
                    #endif
                    DispatchQueue.main.async {
                        self.isSharing = false

                        if success {
                            self.alertTitle = "Success"
                            self.alertMessage = "Share request sent! The recipient will see it in their messages and can accept or decline."
                        } else {
                            self.alertTitle = "Error"
                            self.alertMessage = "Failed to send share request. Please try again."
                        }

                        self.showAlert = true
                    }
                }

            case .failure(let error):
                DispatchQueue.main.async {
                    self.isSharing = false
                    self.alertTitle = "Error"
                    self.alertMessage = "Error finding recipient: \(error.localizedDescription)"
                    self.showAlert = true
                }
            }
        }
    }

    private func fetchReminderTitles() {
        // Determine which ID to use for fetching reminders
        let reminderStoreId = userStoreItem.sourceUserStoreId ?? userStoreItem.sharedStoreGroupId ?? userStoreItem.id

        db.collection("reminders")
            .whereField("userStoreId", isEqualTo: reminderStoreId)
            .whereField("isDone", isEqualTo: false)
            .getDocuments { snapshot, error in
                if let error = error {
                    #if DEBUG
                    print("ShareStoreView: Error fetching reminder titles: \(error.localizedDescription)")
                    #endif
                    return
                }

                let titles = snapshot?.documents.compactMap { doc -> String? in
                    doc.data()["title"] as? String
                } ?? []

                DispatchQueue.main.async {
                    self.reminderTitles = titles
                }
            }
    }

    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }

    private func fetchSharedUsers() {
        isLoadingSharedUsers = true

        // Query only recipient user_stores that were shared from THIS owner's
        // specific user_store document. Using sourceUserStoreId scopes results
        // to the current user's sharing relationships, preventing unrelated
        // users who independently added the same store from appearing.
        db.collection("user_stores")
            .whereField("sourceUserStoreId", isEqualTo: userStoreItem.id)
            .getDocuments { snapshot, error in
                self.isLoadingSharedUsers = false

                if let error = error {
                    #if DEBUG
                    print("ShareStoreView: Error fetching shared users: \(error.localizedDescription)")
                    #endif
                    return
                }

                guard let documents = snapshot?.documents else {
                    return
                }

                self.sharedUsers = documents.compactMap { doc in
                    let data = doc.data()
                    guard let userId = data["userId"] as? String,
                          let userEmail = data["userEmail"] as? String else {
                        return nil
                    }
                    // Self-created (owner) stores have no `permission` field, so a missing
                    // value means the recipient owns their store (a merged store), NOT an
                    // edit recipient. Defaulting to "edit" here would misroute unsharing to
                    // the regular delete path and wrongly delete the recipient's own store.
                    // This mirrors the main store parser, which also defaults to "owner".
                    let permissionString = data["permission"] as? String ?? "owner"
                    let permission = StorePermission(rawValue: permissionString) ?? .edit

                    let sharedAt = data["sharedAt"] as? TimeInterval

                    return SharedUser(
                        id: doc.documentID,
                        userId: userId,
                        userEmail: userEmail,
                        permission: permission,
                        sharedAt: sharedAt
                    )
                }
                .sorted { ($0.sharedAt ?? 0) > ($1.sharedAt ?? 0) }
            }
    }

    private func unshareWithUser(_ sharedUser: SharedUser) {
        // First, look up the recipient's name for updating reminders
        db.collection("users").document(sharedUser.userId).getDocument { [self] snapshot, error in
            let recipientName = snapshot?.data()?["name"] as? String ?? sharedUser.userEmail

            // Merged-store case: the recipient owns their store (permission == .owner) and merged
            // their existing store with the shared one. Don't delete their store — just unlink
            // the sharing relationship and clean up reminder items on both sides.
            if sharedUser.permission == .owner {
                unshareWithMergedUser(sharedUser: sharedUser, recipientName: recipientName)
                return
            }

            // Regular shared store: delete the recipient's user_store document
            db.collection("user_stores").document(sharedUser.id).delete { error in
                if let error = error {
                    self.alertTitle = "Error"
                    self.alertMessage = "Failed to remove access: \(error.localizedDescription)"
                    self.showAlert = true
                } else {
                    // Remove from local array
                    self.sharedUsers.removeAll { $0.id == sharedUser.id }

                    // Update reminders to remove the recipient from sharedWith
                    self.updateRemindersAfterUnshare(recipientName: recipientName)

                    // Update owner's user_store to remove the recipient from sharedWith
                    self.updateOwnerUserStoreAfterUnshare(recipientName: recipientName)

                    // Send a message notifying the user that the store is no longer shared
                    self.sendUnshareMessage(to: sharedUser, recipientName: recipientName)

                    #if DEBUG
                    if sharedUser.permission == .view {
                        print("ShareStoreView: Removed view-only access for \(sharedUser.userEmail)")
                    } else {
                        print("ShareStoreView: Removed edit access for \(sharedUser.userEmail)")
                    }
                    #endif
                }
            }
        }
    }

    /// Unshare from a recipient whose store was merged (they own their own store; permission == .owner).
    /// Clears the sharing link on both sides and deletes reminder items that crossed the boundary.
    private func unshareWithMergedUser(sharedUser: SharedUser, recipientName: String) {
        guard let currentUserId = viewModel.sessionManager.currentUser?.userId,
              let currentUserName = viewModel.sessionManager.currentUser?.name else { return }

        // Remove from local UI immediately
        sharedUsers.removeAll { $0.id == sharedUser.id }

        // 1. Sever ONLY the link between this owner (the unsharer) and the recipient.
        //    The recipient owns their store and may be sharing it with other people of
        //    their own (e.g. user A shares with user B before merging with user C). We must
        //    NOT wipe their entire `sharedWith` — that would erase those independent shares.
        //    Remove just this owner's name from `sharedWith` so the recipient stays the
        //    primary owner of their store, still sharing with everyone else.
        db.collection("user_stores").document(sharedUser.id).updateData([
            "sourceUserStoreId": FieldValue.delete(),
            "sharedFrom":        FieldValue.delete(),
            "sharedFromName":    FieldValue.delete(),
            "sharedFromEmail":   FieldValue.delete(),
            "sharedWith":        FieldValue.arrayRemove([currentUserName])
        ])

        // 2. Remove the owner's reminder items from the recipient's merged store
        //    and clear the owner from sharedWith on the recipient's own reminders.
        removeOwnerRemindersFromMergedStore(
            mergedStoreId: sharedUser.id,
            ownerUserId: currentUserId,
            ownerName: currentUserName
        )

        // 3. Remove the recipient's reminder items from the owner's store
        //    and clear the recipient from sharedWith on the owner's own reminders.
        let ownerStoreId = userStoreItem.sharedStoreGroupId ?? userStoreItem.id
        removeRecipientRemindersFromOwnerStore(
            ownerStoreId: ownerStoreId,
            recipientUserId: sharedUser.userId,
            recipientName: recipientName
        )

        // 4. Update the owner's user_store to remove the recipient from sharedWith
        updateOwnerUserStoreAfterUnshare(recipientName: recipientName)

        // 5. Notify the recipient
        sendUnshareMessage(to: sharedUser, recipientName: recipientName)

        #if DEBUG
        print("ShareStoreView: Unlinked merged store \(sharedUser.id) for \(recipientName)")
        #endif
    }

    /// Severs this owner's attribution from the recipient's merged store WITHOUT deleting
    /// the recipient's reminders. The merge re-attributes the recipient's own duplicate
    /// items to this owner (`sharedFromId == ownerUserId`), so deleting on that basis would
    /// destroy the recipient's own data. Instead, items attributed to this owner are
    /// un-attributed (they become the recipient's own items), and the owner's name is
    /// removed from any `sharedWith`.
    private func removeOwnerRemindersFromMergedStore(mergedStoreId: String, ownerUserId: String, ownerName: String) {
        db.collection("reminders")
            .whereField("userStoreId", isEqualTo: mergedStoreId)
            .whereField("isShared", isEqualTo: true)
            .getDocuments { [self] snapshot, error in
                guard let documents = snapshot?.documents, !documents.isEmpty else { return }

                let batch = db.batch()
                for doc in documents {
                    let data = doc.data()
                    let sharedFromId = data["sharedFromId"] as? String
                    let sharedFromName = data["sharedFrom"] as? String
                    var sharedWith = data["sharedWith"] as? [String] ?? []

                    let attributedToOwner = (sharedFromId == ownerUserId && !ownerUserId.isEmpty)
                        || (sharedFromId == nil && sharedFromName == ownerName && !ownerName.isEmpty)

                    var updates: [String: Any] = [:]

                    if attributedToOwner {
                        // Item attributed to this owner — keep it as the recipient's own item
                        updates["sharedFrom"] = FieldValue.delete()
                        updates["sharedFromId"] = FieldValue.delete()
                    }

                    if sharedWith.contains(ownerName) {
                        sharedWith.removeAll { $0 == ownerName }
                        updates["sharedWith"] = sharedWith.isEmpty ? FieldValue.delete() : sharedWith
                    }

                    let stillSharedWithOthers = !sharedWith.isEmpty
                    let stillSharedFromOther = !attributedToOwner && (sharedFromName != nil)
                    if !stillSharedWithOthers && !stillSharedFromOther {
                        updates["isShared"] = false
                    }

                    if !updates.isEmpty {
                        batch.updateData(updates, forDocument: doc.reference)
                    }
                }
                batch.commit { error in
                    #if DEBUG
                    if let error = error {
                        print("ShareStoreView: Error clearing owner attribution from merged store: \(error.localizedDescription)")
                    }
                    #endif
                }
            }
    }

    /// Deletes reminder items the recipient added to the owner's store during merge,
    /// and removes the recipient from sharedWith on the owner's own reminders.
    private func removeRecipientRemindersFromOwnerStore(ownerStoreId: String, recipientUserId: String, recipientName: String) {
        db.collection("reminders")
            .whereField("userStoreId", isEqualTo: ownerStoreId)
            .whereField("isShared", isEqualTo: true)
            .getDocuments { [self] snapshot, error in
                guard let documents = snapshot?.documents, !documents.isEmpty else { return }

                let batch = db.batch()
                for doc in documents {
                    let data = doc.data()
                    let sharedFromId = data["sharedFromId"] as? String
                    var sharedWith = data["sharedWith"] as? [String] ?? []

                    if sharedFromId == recipientUserId {
                        // Came from the recipient during merge — delete it from owner's store
                        batch.deleteDocument(doc.reference)
                    } else if sharedWith.contains(recipientName) {
                        // Owner's own item shared WITH the recipient — remove recipient from sharedWith
                        sharedWith.removeAll { $0 == recipientName }
                        if sharedWith.isEmpty {
                            batch.updateData([
                                "isShared": false,
                                "sharedWith": FieldValue.delete()
                            ], forDocument: doc.reference)
                        } else {
                            batch.updateData(["sharedWith": sharedWith], forDocument: doc.reference)
                        }
                    }
                }
                batch.commit { error in
                    #if DEBUG
                    if let error = error {
                        print("ShareStoreView: Error removing recipient reminders from owner store: \(error.localizedDescription)")
                    }
                    #endif
                }
            }
    }

    private func updateRemindersAfterUnshare(recipientName: String) {
        // Get the userStoreId to find reminders (could be the direct ID or a sharedStoreGroupId)
        let reminderStoreId = userStoreItem.sharedStoreGroupId ?? userStoreItem.id

        // Find all shared reminders for this store
        db.collection("reminders")
            .whereField("userStoreId", isEqualTo: reminderStoreId)
            .whereField("isShared", isEqualTo: true)
            .getDocuments { snapshot, error in
                if let error = error {
                    #if DEBUG
                    print("ShareStoreView: Error fetching reminders to update: \(error.localizedDescription)")
                    #endif
                    return
                }

                guard let documents = snapshot?.documents, !documents.isEmpty else {
                    #if DEBUG
                    print("ShareStoreView: No shared reminders to update")
                    #endif
                    return
                }

                let batch = self.db.batch()
                var updatedCount = 0

                for doc in documents {
                    let data = doc.data()
                    var sharedWith = data["sharedWith"] as? [String] ?? []
                    let sharedFrom = data["sharedFrom"] as? String

                    // Case 2: Reminder was created by the recipient and added to the owner's store.
                    // Delete it entirely — it was their item and they are being removed.
                    if sharedFrom == recipientName {
                        batch.deleteDocument(doc.reference)
                        updatedCount += 1
                        continue
                    }

                    // Case 1: Reminder created by owner, shared with recipient
                    // Remove the recipient from sharedWith
                    if sharedWith.contains(recipientName) {
                        sharedWith.removeAll { $0 == recipientName }
                        updatedCount += 1

                        if sharedWith.isEmpty {
                            // No more sharing recipients, clear shared status completely
                            batch.updateData([
                                "isShared": false,
                                "sharedWith": FieldValue.delete(),
                                "sharedFrom": FieldValue.delete()
                            ], forDocument: doc.reference)
                        } else {
                            // Update with remaining shared users
                            batch.updateData([
                                "sharedWith": sharedWith
                            ], forDocument: doc.reference)
                        }
                    }
                }

                if updatedCount > 0 {
                    batch.commit { error in
                        #if DEBUG
                        if let error = error {
                            print("ShareStoreView: Error updating reminders after unshare: \(error.localizedDescription)")
                        } else {
                            print("ShareStoreView: Updated \(updatedCount) reminders after unsharing with \(recipientName)")
                        }
                        #endif
                    }
                }
            }
    }

    private func updateOwnerUserStoreAfterUnshare(recipientName: String) {
        let ownerUserStoreId = userStoreItem.id

        #if DEBUG
        print("ShareStoreView: Updating owner's user_store \(ownerUserStoreId) to remove \(recipientName) from sharedWith")
        #endif

        let ownerDocRef = db.collection("user_stores").document(ownerUserStoreId)
        ownerDocRef.getDocument { snapshot, error in
            if let error = error {
                #if DEBUG
                print("ShareStoreView: Error fetching owner's user_store: \(error.localizedDescription)")
                #endif
                return
            }

            guard let data = snapshot?.data() else {
                #if DEBUG
                print("ShareStoreView: Owner's user_store not found")
                #endif
                return
            }

            var sharedWith = data["sharedWith"] as? [String] ?? []
            sharedWith.removeAll { $0 == recipientName }

            if sharedWith.isEmpty {
                ownerDocRef.updateData([
                    "sharedWith": FieldValue.delete(),
                    "isSharedStore": FieldValue.delete()
                ]) { error in
                    #if DEBUG
                    if let error = error {
                        print("ShareStoreView: Error clearing owner's sharedWith: \(error.localizedDescription)")
                    } else {
                        print("ShareStoreView: Cleared owner's sharedWith (no more recipients)")
                    }
                    #endif
                }
            } else {
                ownerDocRef.updateData([
                    "sharedWith": sharedWith
                ]) { error in
                    #if DEBUG
                    if let error = error {
                        print("ShareStoreView: Error updating owner's sharedWith: \(error.localizedDescription)")
                    } else {
                        print("ShareStoreView: Updated owner's sharedWith to \(sharedWith)")
                    }
                    #endif
                }
            }
        }
    }

    private func sendUnshareMessage(to sharedUser: SharedUser, recipientName: String) {
        guard let currentUserId = viewModel.sessionManager.currentUser?.userId,
              let currentUserName = viewModel.sessionManager.currentUser?.name else {
            #if DEBUG
            print("ShareStoreView: Cannot send unshare message - no current user data")
            #endif
            return
        }

        // Find or create conversation and send message
        self.messagingService.findOrCreateConversation(
                currentUserId: currentUserId,
                currentUserName: currentUserName,
                otherUserId: sharedUser.userId,
                otherUserName: recipientName
            ) { result in
                switch result {
                case .success(let conversation):
                    let messageContent = "I've stopped sharing \(self.userStoreItem.store.name) with you."

                    self.messagingService.sendMessage(
                        conversationId: conversation.id,
                        senderId: currentUserId,
                        senderName: currentUserName,
                        content: messageContent,
                        linkedStore: nil
                    ) { messageResult in
                        switch messageResult {
                        case .success:
                            #if DEBUG
                            print("ShareStoreView: Sent unshare notification message to \(recipientName)")
                            #endif
                        case .failure(let error):
                            #if DEBUG
                            print("ShareStoreView: Failed to send unshare message: \(error.localizedDescription)")
                            #endif
                        }
                    }
                case .failure(let error):
                    #if DEBUG
                    print("ShareStoreView: Failed to find/create conversation for unshare message: \(error.localizedDescription)")
                    #endif
                }
            }
    }
}

#Preview {
    ShareStoreView(
        viewModel: StoresViewModel(),
        messagesViewModel: MessagesViewModel(),
        userStoreItem: UserStoreItem(
            id: "preview-id",
            store: Store(name: "Target", reminderCount: 3),
            permission: .owner,
            sharedStoreGroupId: nil,
            sourceUserStoreId: nil,
            sharedFromName: nil,
            sharedFromId: nil,
            sharedWith: nil,
            notificationsEnabled: true
        )
    )
}
