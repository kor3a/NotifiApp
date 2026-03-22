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
            ScrollView {
                VStack(spacing: 24) {
                    // Store Info
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Sharing Store")
                            .font(.headline)
                            .foregroundStyle(.secondary)

                        HStack {
                            Image(systemName: "cart.fill")
                                .foregroundStyle(.blue)
                                .font(.title2)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(userStoreItem.store.name)
                                    .font(.title3)
                                    .bold()

                                Text("All locations")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                )
                        )
                    }

                    // Show who shared the store with the current user (if applicable)
                    if let sharedByName = userStoreItem.sharedFromName {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Shared By")
                                .font(.headline)

                            HStack {
                                Image(systemName: "person.fill.badge.plus")
                                    .foregroundStyle(.blue)
                                    .frame(width: 24)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(sharedByName)
                                        .font(.subheadline)
                                        .bold()

                                    Text(userStoreItem.permission == .edit ? "Can Edit" : "View Only")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.blue.opacity(0.1))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                                    )
                            )
                        }
                    }

                    // Shared Users List
                    if !sharedUsers.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Shared With")
                                .font(.headline)

                            VStack(spacing: 8) {
                                ForEach(sharedUsers) { sharedUser in
                                    HStack {
                                        Image(systemName: sharedUser.permission == .edit ? "person.fill.checkmark" : "eye.fill")
                                            .foregroundStyle(sharedUser.permission == .edit ? .green : .orange)
                                            .frame(width: 24)

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(sharedUser.userEmail)
                                                .font(.subheadline)
                                                .bold()

                                            Text(sharedUser.permission == .edit ? "Can Edit" : "View Only")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }

                                        Spacer()

                                        Button(action: {
                                            unshareWithUser(sharedUser)
                                        }) {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundStyle(.red)
                                        }
                                    }
                                    .padding()
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(colorScheme == .dark ? Color(white: 0.15) : Color.white)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 10)
                                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                            )
                                    )
                                }
                            }
                        }
                    }

                    // Only show sharing UI if user is the owner (not a recipient)
                    if userStoreItem.sharedFromName == nil {
                        Divider()

                        // Family Section
                    if !friendsViewModel.familyMembers.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 6) {
                                Image(systemName: "house.fill")
                                    .foregroundColor(.purple)
                                Text("Share with Family")
                                    .font(.headline)
                            }

                            if isSharingWithAllFamily {
                                HStack(spacing: 8) {
                                    ProgressView()
                                    Text(familyShareProgress)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                .padding(12)
                                .frame(maxWidth: .infinity)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color.purple.opacity(0.1))
                                )
                            }

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    // Share with all family button
                                    Button(action: {
                                        shareWithAllFamily()
                                    }) {
                                        VStack(spacing: 8) {
                                            Circle()
                                                .fill(allFamilyAlreadyShared ? Color.appSuccess.opacity(0.2) : Color.purple.opacity(0.2))
                                                .frame(width: 50, height: 50)
                                                .overlay(
                                                    Group {
                                                        if allFamilyAlreadyShared {
                                                            Image(systemName: "checkmark")
                                                                .font(.system(size: 16))
                                                                .foregroundColor(.appSuccess)
                                                        } else {
                                                            Image(systemName: "person.3.fill")
                                                                .font(.system(size: 16))
                                                                .foregroundColor(.purple)
                                                        }
                                                    }
                                                )

                                            Text("All Family")
                                                .font(.caption)
                                                .foregroundColor(allFamilyAlreadyShared ? .secondary : .primary)
                                                .lineLimit(1)
                                                .frame(width: 60)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(isSharingWithAllFamily || isSharing || allFamilyAlreadyShared)

                                    ForEach(friendsViewModel.familyMembers) { friendship in
                                        let contact = friendship.toContact(currentUserId: viewModel.sessionManager.currentUser?.userId ?? "")
                                        let isAlreadyShared = sharedUsers.contains { $0.userEmail.lowercased() == contact.email.lowercased() }

                                        Button(action: {
                                            if !isAlreadyShared {
                                                selectedFriend = contact
                                                recipientEmail = contact.email
                                            }
                                        }) {
                                            VStack(spacing: 8) {
                                                ZStack(alignment: .bottomTrailing) {
                                                    Circle()
                                                        .fill(isAlreadyShared ? Color.appSuccess.opacity(0.2) : Color.purple.opacity(0.2))
                                                        .frame(width: 50, height: 50)
                                                        .overlay(
                                                            Group {
                                                                if isAlreadyShared {
                                                                    Image(systemName: "checkmark")
                                                                        .foregroundColor(.appSuccess)
                                                                } else {
                                                                    Text(String(contact.name.prefix(1)).uppercased())
                                                                        .font(.headline)
                                                                        .foregroundColor(.purple)
                                                                }
                                                            }
                                                        )

                                                    Image(systemName: "house.fill")
                                                        .font(.system(size: 8))
                                                        .foregroundColor(.white)
                                                        .padding(3)
                                                        .background(Color.purple)
                                                        .clipShape(Circle())
                                                        .offset(x: 2, y: 2)
                                                }

                                                Text(contact.name)
                                                    .font(.caption)
                                                    .foregroundColor(isAlreadyShared ? .secondary : .primary)
                                                    .lineLimit(1)
                                                    .frame(width: 60)
                                            }
                                        }
                                        .buttonStyle(.plain)
                                        .disabled(isAlreadyShared)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }

                        // Friends Section
                    if !friendsViewModel.friends.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Share with Friends")
                                .font(.headline)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(friendsViewModel.friends) { friendship in
                                        let contact = friendship.toContact(currentUserId: viewModel.sessionManager.currentUser?.userId ?? "")
                                        // Check if already shared with this friend
                                        let isAlreadyShared = sharedUsers.contains { $0.userEmail.lowercased() == contact.email.lowercased() }

                                        Button(action: {
                                            if !isAlreadyShared {
                                                selectedFriend = contact
                                                recipientEmail = contact.email
                                            }
                                        }) {
                                            VStack(spacing: 8) {
                                                Circle()
                                                    .fill(isAlreadyShared ? Color.appSuccess.opacity(0.2) : Color.appAccent.opacity(0.2))
                                                    .frame(width: 50, height: 50)
                                                    .overlay(
                                                        Group {
                                                            if isAlreadyShared {
                                                                Image(systemName: "checkmark")
                                                                    .foregroundColor(.appSuccess)
                                                            } else {
                                                                Text(String(contact.name.prefix(1)).uppercased())
                                                                    .font(.headline)
                                                                    .foregroundColor(.appAccent)
                                                            }
                                                        }
                                                    )

                                                Text(contact.name)
                                                    .font(.caption)
                                                    .foregroundColor(isAlreadyShared ? .secondary : .primary)
                                                    .lineLimit(1)
                                                    .frame(width: 60)
                                            }
                                        }
                                        .buttonStyle(.plain)
                                        .disabled(isAlreadyShared)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }

                            if selectedFriend != nil {
                                HStack {
                                    Image(systemName: "person.fill.checkmark")
                                        .foregroundColor(.appAccent)
                                    Text("Selected: \(selectedFriend?.name ?? "")")
                                        .font(.subheadline)
                                    Spacer()
                                    Button(action: {
                                        selectedFriend = nil
                                        recipientEmail = ""
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color.appAccent.opacity(0.1))
                                )
                            }

                    if !friendsViewModel.friends.isEmpty || !friendsViewModel.familyMembers.isEmpty {
                        Text("Or enter email manually")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 8)
                    }

                    // Email Input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Recipient's Email")
                        .font(.headline)

                    TextField("Enter email address", text: $recipientEmail)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(colorScheme == .dark ? Color(white: 0.15) : Color.white)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                )
                        )
                        .onChange(of: recipientEmail) { _, newValue in
                            // Clear selected friend if email changes
                            if selectedFriend != nil && newValue != selectedFriend?.email {
                                selectedFriend = nil
                            }
                        }
                }

                // Permission Selection
                VStack(alignment: .leading, spacing: 8) {
                    Text("Permission")
                        .font(.headline)

                    Picker("Permission", selection: $selectedPermission) {
                        Text("Can Edit").tag(StorePermission.edit)
                        Text("View Only").tag(StorePermission.view)
                    }
                    .pickerStyle(.segmented)

                    // Permission description
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: selectedPermission == .edit ? "pencil.circle.fill" : "eye.circle.fill")
                            .foregroundStyle(selectedPermission == .edit ? .green : .orange)

                        Text(selectedPermission == .edit
                            ? "Can Edit: Recipient gets full ownership. Changes and deletions sync between both users."
                            : "View Only: Recipient can view reminders but cannot edit, share, delete, or check them off.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill((selectedPermission == .edit ? Color.green : Color.orange).opacity(0.1))
                    )
                }

                // Info Text
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "info.circle.fill")
                        .foregroundStyle(.blue)

                    Text("A share request will be sent to the recipient's messages. They must accept before the store appears in their list. The recipient must have an account with the email address you provide.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.blue.opacity(0.1))
                )

                // Show reminder count
                if !reminderTitles.isEmpty {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "list.bullet")
                            .foregroundStyle(.green)

                        Text("\(reminderTitles.count) active reminder(s) will be included with this store.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.green.opacity(0.1))
                    )
                }

                    } // End of owner-only sharing UI
                }
                .padding()
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
                    if isSharing {
                        ProgressView()
                    } else {
                        Button("Share") {
                            shareStore()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.blue)
                        .foregroundColor(.white)
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

    // MARK: - Computed Properties

    private var allFamilyAlreadyShared: Bool {
        let userId = viewModel.sessionManager.currentUser?.userId ?? ""
        return friendsViewModel.familyMembers.allSatisfy { friendship in
            let contact = friendship.toContact(currentUserId: userId)
            return sharedUsers.contains { $0.userEmail.lowercased() == contact.email.lowercased() }
        }
    }

    // MARK: - FUNCTIONS

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
                          let userEmail = data["userEmail"] as? String,
                          let permissionString = data["permission"] as? String,
                          let permission = StorePermission(rawValue: permissionString) else {
                        return nil
                    }

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

            // Delete the shared user's user_store document
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

                    var needsUpdate = false
                    var clearSharedStatus = false

                    // Case 1: Reminder created by owner, shared with recipient
                    // Remove the recipient from sharedWith
                    if sharedWith.contains(recipientName) {
                        sharedWith.removeAll { $0 == recipientName }
                        needsUpdate = true

                        if sharedWith.isEmpty {
                            clearSharedStatus = true
                        }
                    }

                    // Case 2: Reminder created by recipient (sharedFrom = recipient's name)
                    // Clear the shared status entirely since the creator is being removed
                    if sharedFrom == recipientName {
                        clearSharedStatus = true
                        needsUpdate = true
                    }

                    if needsUpdate {
                        updatedCount += 1

                        if clearSharedStatus {
                            // No more sharing, remove shared status completely
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
