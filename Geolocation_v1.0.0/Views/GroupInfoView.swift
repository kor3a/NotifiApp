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
    var onLeaveGroup: (() -> Void)? = nil
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

    @FocusState private var isQueryFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                OrganicPalette.canvas(colorScheme)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        groupHeader
                        memberList

                        if isCreator {
                            addMemberSection
                        }

                        actions
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 28)
                }
                .scrollDismissesKeyboard(.immediately)
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(OrganicPalette.canvas(colorScheme), for: .navigationBar)
            .tint(OrganicPalette.terracotta(colorScheme))
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 16, weight: .bold, design: .serif))
                        .foregroundColor(OrganicPalette.terracotta(colorScheme))
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

    // MARK: - Sections

    private var groupHeader: some View {
        HStack(spacing: 14) {
            OrganicAvatar(
                name: conversation.groupName ?? "Group",
                profilePictureURL: nil,
                size: 62,
                systemImage: "person.3.fill"
            )

            VStack(alignment: .leading, spacing: 4) {
                if editingName {
                    TextField(
                        "",
                        text: $draftName,
                        prompt: Text("Group name")
                            .foregroundColor(OrganicPalette.inkSoft(colorScheme).opacity(0.8))
                    )
                    .font(OrganicPalette.display(24))
                    .foregroundColor(OrganicPalette.ink(colorScheme))
                    .onSubmit { saveGroupName() }
                } else {
                    Text(conversation.groupName ?? "Group")
                        .font(OrganicPalette.display(24))
                        .foregroundColor(OrganicPalette.ink(colorScheme))
                        .lineLimit(2)
                }

                Text("\(conversation.participantIds.count) members")
                    .font(.system(size: 14))
                    .foregroundColor(OrganicPalette.inkSoft(colorScheme))
            }

            Spacer(minLength: 8)

            if isCreator {
                Button {
                    if editingName { saveGroupName() } else { startEditingName() }
                } label: {
                    Image(systemName: editingName ? "checkmark" : "pencil")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(OrganicPalette.terracotta(colorScheme))
                        .frame(width: 42, height: 42)
                        .background(Circle().fill(OrganicPalette.blush(colorScheme)))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(editingName ? "Save group name" : "Rename group")
            }
        }
        .padding(16)
        .background(OrganicCardBackground(colorScheme: colorScheme, cornerRadius: 28))
    }

    private var memberList: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Members", count: conversation.participantIds.count)

            ForEach(sortedParticipants, id: \.self) { userId in
                memberRow(for: userId)
            }
        }
    }

    private func memberRow(for userId: String) -> some View {
        let name = memberName(for: userId)

        return HStack(spacing: 14) {
            OrganicAvatar(
                name: name,
                profilePictureURL: viewModel.participantProfilePictures[userId],
                size: 46
            )

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(name)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(OrganicPalette.ink(colorScheme))
                        .lineLimit(1)

                    if userId == conversation.groupCreatorId {
                        Text("CREATOR")
                            .font(.system(size: 10, weight: .bold))
                            .kerning(0.6)
                            .foregroundColor(OrganicPalette.sageInk(colorScheme))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(OrganicPalette.sage(colorScheme)))
                    }

                    if userId == currentUserId {
                        Text("You")
                            .font(.system(size: 13))
                            .foregroundColor(OrganicPalette.inkSoft(colorScheme))
                    }
                }

                Text("@\(userId)")
                    .font(.system(size: 14))
                    .foregroundColor(OrganicPalette.inkSoft(colorScheme))
                    .lineLimit(1)
            }

            Spacer(minLength: 8)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(OrganicCardBackground(colorScheme: colorScheme))
    }

    private var addMemberSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Add members")

            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(OrganicPalette.inkSoft(colorScheme))

                TextField(
                    "",
                    text: $searchQuery,
                    prompt: Text("Email or username")
                        .foregroundColor(OrganicPalette.inkSoft(colorScheme).opacity(0.8))
                )
                .font(.system(size: 17))
                .foregroundColor(OrganicPalette.ink(colorScheme))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .focused($isQueryFocused)
                .onSubmit { searchForMember() }

                if isSearching {
                    ProgressView()
                        .tint(OrganicPalette.terracotta(colorScheme))
                } else {
                    Button(action: searchForMember) {
                        Text("Search")
                            .font(.system(size: 15, weight: .bold, design: .serif))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .frame(height: 38)
                            .background(Capsule().fill(OrganicPalette.terracotta(colorScheme)))
                    }
                    .buttonStyle(.plain)
                    .disabled(searchQuery.isEmpty)
                    .opacity(searchQuery.isEmpty ? 0.4 : 1)
                }
            }
            .padding(.leading, 18)
            .padding(.trailing, 8)
            .frame(height: 56)
            .background(Capsule().fill(OrganicPalette.field(colorScheme)))

            if let contact = searchedContact {
                let alreadyMember = conversation.participantIds.contains(contact.id)

                Button {
                    addMember(contact)
                } label: {
                    OrganicContactRow(
                        contact: contact,
                        isSelected: alreadyMember,
                        showsSelection: true
                    )
                }
                .buttonStyle(.plain)
                .disabled(alreadyMember)

                if alreadyMember {
                    Text("\(contact.name) is already in this group.")
                        .font(.system(size: 14))
                        .foregroundColor(OrganicPalette.inkSoft(colorScheme))
                        .padding(.horizontal, 4)
                }
            } else if !searchQuery.isEmpty && !isSearching {
                Text("No user found")
                    .font(.system(size: 15))
                    .foregroundColor(OrganicPalette.inkSoft(colorScheme))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
        }
    }

    private var actions: some View {
        VStack(spacing: 10) {
            destructiveButton(
                "Leave group",
                systemImage: "rectangle.portrait.and.arrow.right"
            ) {
                showLeaveAlert = true
            }

            if isCreator {
                destructiveButton("Delete group", systemImage: "trash") {
                    showDeleteAlert = true
                }
            }
        }
        .padding(.top, 4)
    }

    /// Leaving and deleting stay outlined rather than filled — they're the last
    /// things on the screen and neither should read as the obvious next tap.
    private func destructiveButton(
        _ title: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .semibold))
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(OrganicPalette.terracotta(colorScheme))
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                Capsule().stroke(OrganicPalette.terracotta(colorScheme).opacity(0.4), lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }

    private func sectionLabel(_ title: String, count: Int? = nil) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(OrganicPalette.display(22))
                .foregroundColor(OrganicPalette.ink(colorScheme))

            if let count {
                Text("\(count)")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(OrganicPalette.inkSoft(colorScheme))
            }

            Spacer()
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
        isQueryFocused = false
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
        viewModel.leaveGroup(conversationId: conversation.id) { success in
            guard success else { return }
            dismiss()
            onLeaveGroup?()
        }
    }

    private func deleteGroup() {
        viewModel.deleteConversation(conversation)
        dismiss()
    }
}
