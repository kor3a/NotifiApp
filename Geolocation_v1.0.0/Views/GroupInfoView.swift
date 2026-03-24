//
//  GroupInfoView.swift
//  Geolocation_v1.0.0
//
//  Created by Claude Code
//

import SwiftUI

struct GroupInfoView: View {
    let conversation: Conversation
    @ObservedObject var viewModel: MessagesViewModel
    @ObservedObject private var sessionManager = UserSessionManager.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme

    @State private var editingName = false
    @State private var draftName = ""
    @State private var showAddMember = false
    @State private var showLeaveAlert = false
    @State private var showDeleteAlert = false
    @State private var searchQuery = ""
    @State private var searchedContact: Contact?
    @State private var isSearching = false

    private var currentUserId: String { sessionManager.currentUser?.userId ?? "" }
    private var isCreator: Bool { conversation.groupCreatorId == currentUserId }

    var body: some View {
        NavigationStack {
            List {
                // Group name header
                Section {
                    HStack {
                        ZStack {
                            Circle()
                                .fill(Color.purple.opacity(0.18))
                                .frame(width: 60, height: 60)
                            Image(systemName: "person.3.fill")
                                .font(.system(size: 26))
                                .foregroundColor(.purple)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            if editingName {
                                TextField("Group name", text: $draftName)
                                    .font(.title3.bold())
                                    .onSubmit { saveGroupName() }
                            } else {
                                Text(conversation.groupName ?? "Group")
                                    .font(.title3.bold())
                            }

                            Text("\(conversation.participantIds.count) members")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.leading, 8)

                        Spacer()

                        if isCreator {
                            if editingName {
                                Button("Save") { saveGroupName() }
                                    .fontWeight(.semibold)
                            } else {
                                Button(action: { startEditingName() }) {
                                    Image(systemName: "pencil")
                                        .foregroundColor(.appAccent)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }

                // Members list
                Section("Members") {
                    ForEach(sortedParticipants, id: \.self) { userId in
                        HStack(spacing: 12) {
                            Circle()
                                .fill(Color.appAccent.opacity(0.2))
                                .frame(width: 36, height: 36)
                                .overlay(
                                    Text(String(memberName(for: userId).prefix(1)).uppercased())
                                        .font(.subheadline)
                                        .foregroundColor(.appAccent)
                                )

                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(memberName(for: userId))
                                        .font(.body)

                                    if userId == conversation.groupCreatorId {
                                        Text("Creator")
                                            .font(.caption2)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.appAccent.opacity(0.15))
                                            .foregroundColor(.appAccent)
                                            .clipShape(Capsule())
                                    }

                                    if userId == currentUserId {
                                        Text("You")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }

                                Text("@\(userId)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }

                // Add members (creator only)
                if isCreator {
                    Section("Add Members") {
                        HStack {
                            TextField("Email or username", text: $searchQuery)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()

                            if isSearching {
                                ProgressView()
                            } else {
                                Button("Search") { searchForMember() }
                                    .disabled(searchQuery.isEmpty)
                            }
                        }

                        if let contact = searchedContact {
                            let alreadyMember = conversation.participantIds.contains(contact.id)
                            Button(action: { addMember(contact) }) {
                                HStack {
                                    ContactRow(contact: contact)
                                    Spacer()
                                    if alreadyMember {
                                        Text("Already in group")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    } else {
                                        Image(systemName: "plus.circle")
                                            .foregroundColor(.appAccent)
                                    }
                                }
                            }
                            .disabled(alreadyMember)
                        } else if !searchQuery.isEmpty && !isSearching {
                            Text("No user found")
                                .foregroundColor(.secondary)
                                .font(.subheadline)
                        }
                    }
                }

                // Actions
                Section {
                    Button(role: .destructive, action: { showLeaveAlert = true }) {
                        Label("Leave Group", systemImage: "rectangle.portrait.and.arrow.right")
                    }

                    if isCreator {
                        Button(role: .destructive, action: { showDeleteAlert = true }) {
                            Label("Delete Group", systemImage: "trash")
                        }
                    }
                }
            }
            .navigationTitle("Group Info")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Leave Group", isPresented: $showLeaveAlert) {
                Button("Leave", role: .destructive) { leaveGroup() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("You will no longer receive messages from this group.")
            }
            .alert("Delete Group", isPresented: $showDeleteAlert) {
                Button("Delete", role: .destructive) { deleteGroup() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete the group and all its messages for everyone.")
            }
        }
    }

    // MARK: - Helpers

    private var sortedParticipants: [String] {
        // Creator first, then alphabetical by name
        conversation.participantIds.sorted { a, b in
            if a == conversation.groupCreatorId { return true }
            if b == conversation.groupCreatorId { return false }
            return memberName(for: a) < memberName(for: b)
        }
    }

    private func memberName(for userId: String) -> String {
        conversation.participantNames[userId] ?? userId
    }

    private func startEditingName() {
        draftName = conversation.groupName ?? ""
        editingName = true
    }

    private func saveGroupName() {
        let name = draftName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { editingName = false; return }
        viewModel.updateGroupName(conversationId: conversation.id, newName: name)
        editingName = false
    }

    private func searchForMember() {
        guard !searchQuery.isEmpty else { return }
        isSearching = true
        searchedContact = nil

        let handle: (Result<Contact?, Error>) -> Void = { result in
            DispatchQueue.main.async {
                isSearching = false
                if case .success(let contact) = result {
                    searchedContact = contact
                }
            }
        }

        if searchQuery.contains("@") {
            viewModel.messagingServiceSearch(byEmail: searchQuery, completion: handle)
        } else {
            viewModel.messagingServiceSearch(byUsername: searchQuery, completion: handle)
        }
    }

    private func addMember(_ contact: Contact) {
        viewModel.addGroupMember(conversationId: conversation.id, contact: contact)
        searchQuery = ""
        searchedContact = nil
    }

    private func leaveGroup() {
        viewModel.leaveGroup(conversationId: conversation.id) { _ in
            dismiss()
        }
    }

    private func deleteGroup() {
        viewModel.deleteConversation(conversation)
        dismiss()
    }
}
