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

    @Environment(\.colorScheme) private var colorScheme
    @FocusState private var isQueryFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                OrganicPalette.canvas(colorScheme)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("New group")
                            .font(OrganicPalette.display(32))
                            .foregroundColor(OrganicPalette.ink(colorScheme))
                            .padding(.top, 8)

                        nameField
                        memberSearch
                        selectedMemberList
                        recentContactList
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                }
                .scrollDismissesKeyboard(.immediately)
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(OrganicPalette.canvas(colorScheme), for: .navigationBar)
            .tint(OrganicPalette.terracotta(colorScheme))
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(OrganicPalette.terracotta(colorScheme))
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if isCreating {
                        ProgressView()
                            .tint(OrganicPalette.terracotta(colorScheme))
                    } else {
                        Button("Create") { createGroup() }
                            .font(.system(size: 16, weight: .bold, design: .serif))
                            .foregroundColor(OrganicPalette.terracotta(colorScheme))
                            .disabled(!canCreate)
                            .opacity(canCreate ? 1 : 0.4)
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

    private var canCreate: Bool {
        !groupName.trimmingCharacters(in: .whitespaces).isEmpty && !selectedMembers.isEmpty
    }

    // MARK: - Sections

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Name")

            TextField(
                "",
                text: $groupName,
                prompt: Text("Family, Friends, Team\u{2026}")
                    .foregroundColor(OrganicPalette.inkSoft(colorScheme).opacity(0.8))
            )
            .font(.system(size: 17))
            .foregroundColor(OrganicPalette.ink(colorScheme))
            .autocorrectionDisabled()
            .padding(.horizontal, 18)
            .frame(height: 54)
            .background(Capsule().fill(OrganicPalette.field(colorScheme)))
        }
    }

    private var memberSearch: some View {
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
                .onSubmit { search() }

                if isSearching {
                    ProgressView()
                        .tint(OrganicPalette.terracotta(colorScheme))
                } else {
                    Button(action: search) {
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
                let isSelected = selectedMembers.contains(where: { $0.id == contact.id })
                Button {
                    if isSelected { removeMember(contact) } else { addMember(contact) }
                } label: {
                    OrganicContactRow(contact: contact, isSelected: isSelected, showsSelection: true)
                }
                .buttonStyle(.plain)
            } else if !searchQuery.isEmpty && !isSearching {
                Text("No user found")
                    .font(.system(size: 15))
                    .foregroundColor(OrganicPalette.inkSoft(colorScheme))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
        }
    }

    @ViewBuilder
    private var selectedMemberList: some View {
        if !selectedMembers.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                sectionLabel("Members", count: selectedMembers.count)

                ForEach(selectedMembers) { member in
                    Button {
                        removeMember(member)
                    } label: {
                        OrganicContactRow(contact: member, isSelected: true, showsSelection: true)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Remove \(member.name) from the group")
                }
            }
        }
    }

    @ViewBuilder
    private var recentContactList: some View {
        // Anyone already picked shows in Members above, so listing them again
        // here would put the same person on screen twice.
        let unpicked = viewModel.recentContacts.filter { contact in
            !selectedMembers.contains(where: { $0.id == contact.id })
        }

        if !unpicked.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                sectionLabel("Recent")

                ForEach(unpicked) { contact in
                    Button {
                        addMember(contact)
                    } label: {
                        OrganicContactRow(contact: contact, showsSelection: true)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Add \(contact.name) to the group")
                }
            }
        }
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

    private func search() {
        guard !searchQuery.isEmpty else { return }
        isQueryFocused = false
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
