//
//  NewGroupView.swift
//  Geolocation_v1.0.0
//
//  Created by Claude Code
//

import SwiftUI

struct NewGroupView: View {
    @ObservedObject var viewModel: MessagesViewModel
    @ObservedObject private var sessionManager = UserSessionManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var groupName = ""
    @State private var searchQuery = ""
    @State private var selectedMembers: [Contact] = []
    @State private var searchedContact: Contact?
    @State private var isSearching = false
    @State private var createdConversation: Conversation?
    @State private var isCreating = false

    var body: some View {
        NavigationStack {
            List {
                // Group name
                Section("Group Name") {
                    TextField("Family, Friends, Team…", text: $groupName)
                        .autocorrectionDisabled()
                }

                // Add members search
                Section {
                    HStack {
                        TextField("Enter email or username", text: $searchQuery)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()

                        if isSearching {
                            ProgressView()
                        } else {
                            Button("Search") { search() }
                                .disabled(searchQuery.isEmpty)
                        }
                    }

                    if let contact = searchedContact {
                        if selectedMembers.contains(where: { $0.id == contact.id }) {
                            HStack {
                                ContactRow(contact: contact)
                                Spacer()
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.appAccent)
                            }
                        } else {
                            Button(action: { addMember(contact) }) {
                                HStack {
                                    ContactRow(contact: contact)
                                    Spacer()
                                    Image(systemName: "plus.circle")
                                        .foregroundColor(.appAccent)
                                }
                            }
                        }
                    } else if !searchQuery.isEmpty && !isSearching {
                        Text("No user found")
                            .foregroundColor(.secondary)
                            .font(.subheadline)
                    }
                } header: {
                    Text("Add Members")
                } footer: {
                    Text("Search by email address or username")
                }

                // Selected members
                if !selectedMembers.isEmpty {
                    Section("Members (\(selectedMembers.count))") {
                        ForEach(selectedMembers) { member in
                            HStack {
                                ContactRow(contact: member)
                                Spacer()
                                Button(action: { removeMember(member) }) {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundColor(.red)
                                }
                            }
                        }
                    }
                }

                // Recent contacts for quick adding
                if !viewModel.recentContacts.isEmpty {
                    Section("Recent Contacts") {
                        ForEach(viewModel.recentContacts) { contact in
                            let isSelected = selectedMembers.contains(where: { $0.id == contact.id })
                            Button(action: {
                                if isSelected { removeMember(contact) } else { addMember(contact) }
                            }) {
                                HStack {
                                    ContactRow(contact: contact)
                                    Spacer()
                                    Image(systemName: isSelected ? "checkmark.circle.fill" : "plus.circle")
                                        .foregroundColor(isSelected ? .appAccent : .secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("New Group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if isCreating {
                        ProgressView()
                    } else {
                        Button("Create") { createGroup() }
                            .disabled(groupName.trimmingCharacters(in: .whitespaces).isEmpty || selectedMembers.isEmpty)
                            .fontWeight(.semibold)
                    }
                }
            }
            .onAppear {
                viewModel.fetchRecentContacts()
            }
            .navigationDestination(item: $createdConversation) { conversation in
                ConversationView(conversation: conversation, viewModel: viewModel)
            }
        }
    }

    private func search() {
        guard !searchQuery.isEmpty else { return }
        isSearching = true
        searchedContact = nil

        let handleResult: (Result<Contact?, Error>) -> Void = { result in
            DispatchQueue.main.async {
                isSearching = false
                if case .success(let contact) = result {
                    // Don't show the current user in results
                    if let contact, contact.id != sessionManager.currentUser?.userId {
                        searchedContact = contact
                    }
                }
            }
        }

        if searchQuery.contains("@") {
            viewModel.messagingServiceSearch(byEmail: searchQuery, completion: handleResult)
        } else {
            viewModel.messagingServiceSearch(byUsername: searchQuery, completion: handleResult)
        }
    }

    private func addMember(_ contact: Contact) {
        guard !selectedMembers.contains(where: { $0.id == contact.id }) else { return }
        selectedMembers.append(contact)
    }

    private func removeMember(_ contact: Contact) {
        selectedMembers.removeAll { $0.id == contact.id }
    }

    private func createGroup() {
        let name = groupName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty, !selectedMembers.isEmpty else { return }
        isCreating = true

        viewModel.createGroupConversation(groupName: name, members: selectedMembers) { conversation in
            isCreating = false
            if let conversation {
                createdConversation = conversation
            }
        }
    }
}
