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

    @State private var recipientEmail: String = ""
    @State private var selectedPermission: StorePermission = .edit
    @State private var isSharing: Bool = false
    @State private var showAlert: Bool = false
    @State private var alertMessage: String = ""
    @State private var alertTitle: String = ""
    @State private var sharedUsers: [SharedUser] = []
    @State private var isLoadingSharedUsers: Bool = false
    @State private var reminderTitles: [String] = []

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

                                Text(userStoreItem.store.address)
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

                    Divider()

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

                // Share Button
                Button(action: shareStore) {
                    if isSharing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .frame(maxWidth: .infinity)
                            .padding()
                    } else {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("Share Store")
                                .bold()
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                    }
                }
                .disabled(recipientEmail.isEmpty || isSharing)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(recipientEmail.isEmpty || isSharing ? Color.gray : Color.blue)
                )
                .foregroundColor(.white)
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
            }
            .alert(alertTitle, isPresented: $showAlert) {
                Button("OK") {
                    if alertTitle == "Success" {
                        fetchSharedUsers()
                        recipientEmail = ""
                    }
                }
            } message: {
                Text(alertMessage)
            }
            .onAppear {
                fetchSharedUsers()
                fetchReminderTitles()
            }
        }
    }

    // MARK: - FUNCTIONS

    private func shareStore() {
        print("ShareStoreView: shareStore() called - NEW MESSAGE-BASED FLOW")

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
        print("ShareStoreView: Looking up user by email: \(cleanedEmail)")

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

                print("ShareStoreView: Found contact: \(contact.name) (\(contact.id))")

                // Check if recipient already has this store
                self.db.collection("user_stores")
                    .whereField("userId", isEqualTo: contact.id)
                    .whereField("storeId", isEqualTo: self.userStoreItem.store.id)
                    .getDocuments { snapshot, error in
                        if let documents = snapshot?.documents, !documents.isEmpty {
                            DispatchQueue.main.async {
                                self.isSharing = false
                                self.alertTitle = "Error"
                                self.alertMessage = "This user already has this store."
                                self.showAlert = true
                            }
                            return
                        }

                        print("ShareStoreView: Recipient doesn't have store yet, sending share request via messaging...")

                        // Send the store share request via messaging
                        let permissionString = self.selectedPermission == .edit ? "edit" : "view"
                        self.messagesViewModel.shareStore(
                            userStoreItem: self.userStoreItem,
                            to: contact,
                            permission: permissionString,
                            currentUserName: currentUserName,
                            reminderTitles: self.reminderTitles
                        ) { success in
                            print("ShareStoreView: messagesViewModel.shareStore completed with success=\(success)")
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
                    print("ShareStoreView: Error fetching reminder titles: \(error.localizedDescription)")
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

        // Get current user's ID to exclude from results
        guard let currentUserId = viewModel.sessionManager.currentUser?.userId else {
            return
        }

        // Query all user_stores with the same storeId but different userId
        db.collection("user_stores")
            .whereField("storeId", isEqualTo: userStoreItem.store.id)
            .getDocuments { snapshot, error in
                self.isLoadingSharedUsers = false

                if let error = error {
                    print("ShareStoreView: Error fetching shared users: \(error.localizedDescription)")
                    return
                }

                guard let documents = snapshot?.documents else {
                    return
                }

                // Filter out current user and map to SharedUser
                self.sharedUsers = documents.compactMap { doc in
                    let data = doc.data()
                    guard let userId = data["userId"] as? String,
                          userId != currentUserId, // Exclude current user
                          let userEmail = data["userEmail"] as? String,
                          let permissionString = data["permission"] as? String,
                          let permission = StorePermission(rawValue: permissionString) else {
                        return nil
                    }

                    let sharedAt = data["sharedAt"] as? TimeInterval

                    return SharedUser(
                        id: doc.documentID,
                        userEmail: userEmail,
                        permission: permission,
                        sharedAt: sharedAt
                    )
                }
                .sorted { ($0.sharedAt ?? 0) > ($1.sharedAt ?? 0) } // Most recent first
            }
    }

    private func unshareWithUser(_ sharedUser: SharedUser) {
        // Delete the shared user's user_store document
        db.collection("user_stores").document(sharedUser.id).delete { error in
            if let error = error {
                self.alertTitle = "Error"
                self.alertMessage = "Failed to remove access: \(error.localizedDescription)"
                self.showAlert = true
            } else {
                // Remove from local array
                self.sharedUsers.removeAll { $0.id == sharedUser.id }

                // For View Only users, also delete their reminders if they exist
                // (though they shouldn't exist if we implemented it correctly)
                if sharedUser.permission == .view {
                    // No reminders to delete for view-only
                    print("ShareStoreView: Removed view-only access for \(sharedUser.userEmail)")
                }
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
            store: Store(
                id: "store-id",
                name: "Target",
                address: "123 Main St, City, ST 12345",
                reminderCount: 3
            ),
            permission: .owner,
            sharedStoreGroupId: nil,
            sourceUserStoreId: nil,
            sharedFromName: nil,
            sharedWith: nil,
            notificationsEnabled: true
        )
    )
}
