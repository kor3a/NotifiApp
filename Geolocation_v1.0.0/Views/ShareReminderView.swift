//
//  ShareReminderView.swift
//  Geolocation_v1.0.0
//
//  Created by Claude Code
//

import SwiftUI

struct ShareReminderView: View {
    let reminder: Reminder
    let store: Store
    @StateObject private var viewModel = MessagesViewModel()
    @StateObject private var friendsViewModel = FriendsViewModel()
    @ObservedObject private var sessionManager = UserSessionManager.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var searchEmail = ""
    @State private var selectedContact: Contact?
    @State private var customMessage = ""
    @State private var isSending = false
    @State private var showSuccess = false

    var body: some View {
        NavigationStack {
            Form {
                // Reminder preview
                Section("Sharing") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "list.bullet.clipboard")
                                .foregroundColor(.appAccent)
                            Text(reminder.title)
                                .fontWeight(.medium)
                        }

                        HStack {
                            Image(systemName: "storefront")
                                .foregroundColor(.secondaryText)
                            Text(store.name)
                                .foregroundColor(.secondaryText)
                        }
                        .font(.subheadline)
                    }
                    .padding(.vertical, 4)
                }

                // Contact selection
                Section("Send To") {
                    if let contact = selectedContact {
                        HStack {
                            ContactRow(contact: contact)
                            Spacer()
                            Button(action: { selectedContact = nil }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondaryText)
                            }
                        }
                    } else {
                        HStack {
                            TextField("Enter email address", text: $searchEmail)
                                .textInputAutocapitalization(.never)
                                .keyboardType(.emailAddress)
                                .autocorrectionDisabled()

                            if viewModel.isSearching {
                                ProgressView()
                            } else {
                                Button("Find") {
                                    viewModel.searchContact(query: searchEmail)
                                }
                                .disabled(searchEmail.isEmpty)
                            }
                        }

                        if let contact = viewModel.searchedContact {
                            Button(action: {
                                selectedContact = contact
                                searchEmail = ""
                                viewModel.searchedContact = nil
                            }) {
                                ContactRow(contact: contact)
                            }
                        }
                    }
                }

                // Family list
                if selectedContact == nil && !friendsViewModel.familyMembers.isEmpty {
                    Section {
                        ForEach(friendsViewModel.familyMembers) { friendship in
                            let contact = friendship.toContact(currentUserId: sessionManager.currentUser?.userId ?? "")
                            Button(action: { selectedContact = contact }) {
                                HStack {
                                    ContactRow(contact: contact)
                                    Spacer()
                                    Image(systemName: "house.fill")
                                        .font(.caption)
                                        .foregroundColor(OrganicPalette.sageInk(colorScheme))
                                }
                            }
                        }
                    } header: {
                        HStack(spacing: 4) {
                            Image(systemName: "house.fill")
                                .foregroundColor(OrganicPalette.sageInk(colorScheme))
                            Text("Family")
                        }
                    }
                }

                // Friends list
                if selectedContact == nil && !friendsViewModel.friends.isEmpty {
                    Section("Friends") {
                        ForEach(friendsViewModel.friends) { friendship in
                            let contact = friendship.toContact(currentUserId: sessionManager.currentUser?.userId ?? "")
                            Button(action: { selectedContact = contact }) {
                                ContactRow(contact: contact)
                            }
                        }
                    }
                }

                // Recent contacts
                if selectedContact == nil && !viewModel.recentContacts.isEmpty {
                    Section("Recent Contacts") {
                        ForEach(viewModel.recentContacts.prefix(5)) { contact in
                            Button(action: { selectedContact = contact }) {
                                ContactRow(contact: contact)
                            }
                        }
                    }
                }

                // Custom message
                Section("Message (Optional)") {
                    TextField("Add a message...", text: $customMessage, axis: .vertical)
                        .lineLimit(3...6)
                }

                // Preview
                Section("Preview") {
                    Text(messagePreview)
                        .foregroundColor(.secondaryText)
                        .font(.subheadline)
                }
            }
            .navigationTitle("Share Reminder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Send") {
                        sendReminder()
                    }
                    .fontWeight(.semibold)
                    .disabled(selectedContact == nil || isSending)
                }
            }
            .onAppear {
                viewModel.fetchRecentContacts()
                friendsViewModel.fetchFriendships()
            }
            .onDisappear {
                friendsViewModel.stopListening()
            }
            .organicAlert(
                "Reminder Shared!",
                isPresented: $showSuccess,
                icon: "checkmark",
                tone: .success,
                message: "Your reminder has been sent to \(selectedContact?.name ?? "the contact").",
                actions: [.ok { dismiss() }]
            )
            .overlay {
                if isSending {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .overlay(
                            ProgressView("Sending...")
                                .padding()
                                .background(.regularMaterial)
                                .cornerRadius(10)
                        )
                }
            }
        }
    }

    private var messagePreview: String {
        if customMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Can you pick up \(reminder.title) at \(store.name)?"
        } else {
            return customMessage
        }
    }

    private func sendReminder() {
        guard let contact = selectedContact,
              let userName = sessionManager.currentUser?.name else { return }

        isSending = true

        let message = customMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? nil
            : customMessage

        viewModel.shareReminder(
            reminder: reminder,
            store: store,
            to: contact,
            currentUserName: userName,
            customMessage: message
        ) { success in
            isSending = false
            if success {
                showSuccess = true
            }
        }
    }
}

#Preview {
    ShareReminderView(
        reminder: Reminder(
            id: "preview",
            userStoreId: "store1",
            title: "Buy milk",
            isDone: false,
            createdAt: Date().timeIntervalSince1970
        ),
        store: Store(name: "Trader Joe's")
    )
}
