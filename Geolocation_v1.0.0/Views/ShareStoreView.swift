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
    /// True when this user owned the same store and merged it into ours. Their store is
    /// theirs — revoking access has to hand it back, not delete it.
    let mergedFromOwnStore: Bool
}

/// A row that reveals a Remove action when swiped left.
///
/// `List`'s `.swipeActions` needs a `List`, and the share sheet lays its recipients
/// out in a `VStack` inside a `ScrollView`, so the gesture is done by hand. The
/// action sits behind the row's trailing edge and is only drawn once the row has
/// started moving, which keeps it from showing through the row's own background.
private struct SwipeToRemoveRow<Content: View>: View {
    let isEnabled: Bool
    let onRemove: () -> Void
    @ViewBuilder var content: Content

    @State private var offset: CGFloat = 0
    @State private var isOpen = false

    private let actionWidth: CGFloat = 88

    var body: some View {
        ZStack(alignment: .trailing) {
            if offset < 0 {
                Button {
                    close()
                    onRemove()
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: "person.badge.minus")
                            .font(.subheadline)
                        Text("Remove")
                            .font(.caption2)
                            .fontWeight(.semibold)
                    }
                    .foregroundStyle(Color.white.opacity(0.85))
                    .frame(width: actionWidth)
                    .frame(maxHeight: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.appError.opacity(0.45))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.appError.opacity(0.35), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }

            content
                .offset(x: offset)
                // Simultaneous so a vertical drag still scrolls the sheet; the
                // handler ignores anything that isn't mostly horizontal.
                .simultaneousGesture(
                    DragGesture(minimumDistance: 12)
                        .onChanged { value in
                            guard isEnabled else { return }
                            guard abs(value.translation.width) > abs(value.translation.height) else { return }
                            let base: CGFloat = isOpen ? -actionWidth : 0
                            offset = min(0, max(-actionWidth, base + value.translation.width))
                        }
                        .onEnded { _ in
                            guard isEnabled else { return }
                            withAnimation(.easeOut(duration: 0.2)) {
                                if offset < -actionWidth / 2 {
                                    offset = -actionWidth
                                    isOpen = true
                                } else {
                                    offset = 0
                                    isOpen = false
                                }
                            }
                        }
                )
        }
        // A row that stops being removable must not stay stuck open.
        .onChange(of: isEnabled) { _, enabled in
            if !enabled { close() }
        }
    }

    private func close() {
        withAnimation(.easeOut(duration: 0.2)) {
            offset = 0
            isOpen = false
        }
    }
}

struct ShareStoreView: View {
    /// Which recipient list the sheet is currently showing.
    private enum RecipientTab {
        case family
        case friends

        var title: String { self == .family ? "Family" : "Friends" }
        var icon: String { self == .family ? "house.fill" : "person.2.fill" }
        var tint: Color { self == .family ? .purple : .appAccent }
        var emptyMessage: String {
            self == .family ? "No family members yet." : "No friends yet."
        }
    }

    // MARK: - PROPERTIES

    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject var viewModel: StoresViewModel
    @ObservedObject var messagesViewModel: MessagesViewModel
    let userStoreItem: UserStoreItem

    @StateObject private var friendsViewModel = FriendsViewModel()
    /// Observed so the header refreshes once a logo finishes downloading.
    @ObservedObject private var logoProvider = StoreLogoProvider.shared
    @State private var selectedPermission: StorePermission = .edit
    @State private var isSharing: Bool = false
    @State private var showAlert: Bool = false
    @State private var alertMessage: String = ""
    @State private var alertTitle: String = ""
    @State private var sharedUsers: [SharedUser] = []
    @State private var isLoadingSharedUsers: Bool = false
    @State private var reminderTitles: [String] = []
    /// Every recipient ticked in the list, across both tabs.
    @State private var selectedContactIDs: Set<String> = []
    @State private var showShareInfo: Bool = false
    /// Nil until the user picks a tab, so the sheet can open on whichever list
    /// actually has people in it.
    @State private var recipientTab: RecipientTab?
    @State private var shareProgress: String = ""
    /// The sharer's profile picture, looked up from their user document.
    @State private var sharedByPictureURL: String?

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
                        // Store Info — hero header, with the info bubble on the
                        // same row and its explainer expanding underneath.
                        storeHeader

                        if showShareInfo {
                            shareInfoBubble
                        }

                        // Show who shared the store with the current user (if applicable)
                        if let sharedByName = userStoreItem.sharedFromName {
                            sharedBySection(sharedByName: sharedByName)
                        }

                        // Only show sharing UI if user is the owner (not a recipient)
                        if userStoreItem.sharedFromName == nil {
                            // Family / Friends picker and the matching list
                            if !friendsViewModel.familyMembers.isEmpty || !friendsViewModel.friends.isEmpty {
                                recipientSection
                            }

                            // Sharing is friends/family only, so say what to do when
                            // there is nobody to share with yet.
                            if friendsViewModel.friends.isEmpty && friendsViewModel.familyMembers.isEmpty {
                                infoCallout(
                                    icon: "person.crop.circle.badge.plus",
                                    tint: .appAccent,
                                    text: "Add friends or family in the Friends tab to share this store with them."
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
                    if isSharing {
                        ProgressView()
                    } else {
                        Button("Share") {
                            shareStore()
                        }
                        .fontWeight(.semibold)
                        .disabled(selectedContacts.isEmpty)
                    }
                }
            }
            .alert(alertTitle, isPresented: $showAlert) {
                Button("OK") {
                    if alertTitle == "Success" {
                        fetchSharedUsers()
                        selectedContactIDs.removeAll()
                        dismiss()
                    }
                }
            } message: {
                Text(alertMessage)
            }
            .onAppear {
                fetchSharedUsers()
                fetchReminderTitles()
                fetchSharedByPicture()
                friendsViewModel.fetchFriendships()
            }
            .onDisappear {
                friendsViewModel.stopListening()
            }
        }
    }

    // MARK: - SUBVIEWS

    /// Hero header showing the store being shared, with the info toggle pinned
    /// to the trailing edge of the same row.
    private var storeHeader: some View {
        HStack(spacing: 16) {
            storeLogoTile

            Text(userStoreItem.store.name)
                .font(.title2)
                .fontWeight(.bold)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Spacer(minLength: 8)

            shareInfoButton
        }
    }

    /// Toggles the share explainer. An inline bubble rather than a popover, which
    /// the sheet's edge clipped.
    private var shareInfoButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                showShareInfo.toggle()
            }
        } label: {
            Image(systemName: showShareInfo ? "info.circle.fill" : "info.circle")
                .font(.title3)
                .foregroundStyle(Color.appAccent)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("About sharing")
    }

    /// The share explainer, shown directly below the info button.
    private var shareInfoBubble: some View {
        Text("A share request will be sent to the recipient's messages. They must accept before the store is shared successfully for both users.")
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.appAccent.opacity(0.1))
            )
            .transition(.opacity.combined(with: .move(edge: .top)))
    }

    /// Store logo shown in the hero header, matching the logos used in `StoresView`.
    /// Falls back to the generic cart tile while a logo downloads, or permanently when
    /// no logo can be retrieved for this store.
    private var storeLogoTile: some View {
        Group {
            if let logo = logoProvider.cachedImage(for: userStoreItem.store.name) {
                Image(uiImage: logo)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: .black.opacity(0.18), radius: 8, x: 0, y: 4)
            } else {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.iconGradient)
                    .frame(width: 60, height: 60)
                    .overlay(
                        Image(systemName: "cart.fill")
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundStyle(.white)
                    )
                    .shadow(color: Color.appAccent.opacity(0.35), radius: 8, x: 0, y: 4)
            }
        }
    }

    /// Section shown to a recipient describing who shared the store with them.
    private func sharedBySection(sharedByName: String) -> some View {
        sectionContainer(title: "Shared By", icon: "person.fill.badge.plus", tint: .appAccent) {
            HStack(spacing: 12) {
                ProfilePictureView(profilePictureURL: sharedByPictureURL, size: 44) {
                    Circle()
                        .fill(Color.appAccent.opacity(0.15))
                        .overlay(
                            Text(String(sharedByName.prefix(1)).uppercased())
                                .font(.headline)
                                .foregroundStyle(Color.appAccent)
                        )
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(sharedByName)
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    // `.owner` — which is what a store carries after it was merged with
                    // an incoming share — is an editing permission, so it must not fall
                    // through to "View Only". See `StorePermission.canEdit`.
                    Text(userStoreItem.permission.displayLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                permissionBadge(userStoreItem.permission)
            }
        }
    }

    /// Family / Friends picker, the permission chips, and the matching contacts.
    private var recipientSection: some View {
        VStack(spacing: 14) {
            HStack(spacing: 10) {
                recipientTabChip(.family)
                recipientTabChip(.friends)
            }
            .frame(maxWidth: .infinity)

            permissionSection

            if isSharing && !shareProgress.isEmpty {
                HStack(spacing: 8) {
                    ProgressView()
                    Text(shareProgress)
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

            recipientList
        }
        .animation(.easeInOut(duration: 0.15), value: activeRecipientTab)
    }

    /// The active tab's contacts, separated by hairlines rather than cards.
    private var recipientList: some View {
        VStack(spacing: 0) {
            if activeRecipientTab == .family && !friendsViewModel.familyMembers.isEmpty {
                allFamilyRow

                if !activeRecipientContacts.isEmpty {
                    Divider()
                }
            }

            ForEach(Array(activeRecipientContacts.enumerated()), id: \.element.id) { item in
                contactRow(contact: item.element, tint: activeRecipientTab.tint)

                if item.offset < activeRecipientContacts.count - 1 {
                    Divider()
                }
            }

            if activeRecipientContacts.isEmpty {
                Text(activeRecipientTab.emptyMessage)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 12)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 4)
        // Off-white for both tabs, so the list reads as a sheet of its own
        // against the gradient background.
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(recipientListBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
        )
    }

    /// One tab of the Family / Friends picker.
    private func recipientTabChip(_ tab: RecipientTab) -> some View {
        selectionChip(
            title: tab.title,
            icon: tab.icon,
            tint: tab.tint,
            isSelected: activeRecipientTab == tab
        ) {
            recipientTab = tab
        }
    }

    /// Ticks (or unticks) every family member who hasn't been shared with yet.
    /// It only changes the selection — Share is what sends the requests.
    private var allFamilyRow: some View {
        Button {
            toggleAllFamily()
        } label: {
            recipientRowLayout(
                avatar: AnyView(
                    Circle()
                        .fill(Color.purple.opacity(0.15))
                        .frame(width: 44, height: 44)
                        .overlay(
                            Image(systemName: "person.3.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(.purple)
                        )
                ),
                name: "All Family",
                isShared: allFamilyAlreadyShared,
                isSelected: allFamilySelected,
                tint: .purple
            )
        }
        .buttonStyle(.plain)
        .disabled(isSharing || allFamilyAlreadyShared)
    }

    /// One recipient in the list. Tapping it ticks or unticks them; once the store
    /// is shared with them, swiping left reveals Remove instead.
    private func contactRow(contact: Contact, tint: Color) -> some View {
        let isShared = isAlreadyShared(contact)

        return SwipeToRemoveRow(
            isEnabled: isShared,
            onRemove: { unshare(contact) }
        ) {
            contactRowButton(contact: contact, tint: tint, isShared: isShared)
        }
    }

    /// The tappable body of a recipient row.
    private func contactRowButton(contact: Contact, tint: Color, isShared: Bool) -> some View {
        Button {
            guard !isShared else { return }
            toggleSelection(of: contact)
        } label: {
            recipientRowLayout(
                avatar: AnyView(
                    ProfilePictureView(profilePictureURL: contact.profilePictureURL, size: 44) {
                        Circle()
                            .fill(tint.opacity(0.15))
                            .overlay(
                                Text(String(contact.name.prefix(1)).uppercased())
                                    .font(.headline)
                                    .foregroundStyle(tint)
                            )
                    }
                ),
                name: contact.name,
                isShared: isShared,
                isSelected: selectedContactIDs.contains(contact.id),
                tint: tint
            )
        }
        .buttonStyle(.plain)
    }

    /// The name colour for a recipient row across its three states.
    private func rowNameColor(isShared: Bool, isSelected: Bool, tint: Color) -> Color {
        if isShared { return .secondary }
        return isSelected ? tint : .primary
    }

    /// The row chrome shared by the contact rows and the All Family shortcut.
    /// `avatar` is type-erased to keep the call sites' type-checking cheap.
    private func recipientRowLayout(
        avatar: AnyView,
        name: String,
        isShared: Bool,
        isSelected: Bool,
        tint: Color
    ) -> some View {
        HStack(spacing: 12) {
            avatar

            Text(name)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .medium)
                .foregroundStyle(rowNameColor(isShared: isShared, isSelected: isSelected, tint: tint))
                .lineLimit(1)

            Spacer(minLength: 0)

            if isShared {
                Text("Shared")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.appSuccess)
            } else if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(tint)
            }
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .opacity(isShared ? 0.6 : 1)
    }

    /// The recipient's access level, as one segmented control so it reads as a
    /// single smaller control beneath the Family / Friends tabs.
    private var permissionSection: some View {
        HStack(spacing: 4) {
            permissionSegment(.edit, title: "Can Edit", icon: "pencil", tint: .appSuccess)
            permissionSegment(.view, title: "View Only", icon: "eye", tint: .appWarning)
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.primary.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
        )
        .frame(maxWidth: .infinity)
        .animation(.easeInOut(duration: 0.15), value: selectedPermission)
    }

    /// One segment of the permission control.
    private func permissionSegment(
        _ permission: StorePermission,
        title: String,
        icon: String,
        tint: Color
    ) -> some View {
        let isSelected = selectedPermission == permission

        return Button {
            selectedPermission = permission
        } label: {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                    .fontWeight(.semibold)
                Text(title)
                    .font(.caption)
                    .fontWeight(.semibold)
            }
            .foregroundStyle(isSelected ? Color.white : Color.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(isSelected ? tint : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    /// The capsule used by the Family / Friends tabs.
    private func selectionChip(
        title: String,
        icon: String,
        tint: Color,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                    .fontWeight(.semibold)
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            .foregroundStyle(isSelected ? Color.white : Color.secondary)
            .padding(.horizontal, 18)
            .padding(.vertical, 11)
            .background(
                Capsule()
                    .fill(isSelected ? tint : Color.primary.opacity(0.06))
            )
            .overlay(
                Capsule()
                    .stroke(isSelected ? Color.clear : Color.secondary.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    // MARK: - Reusable building blocks

    /// A titled card container used by the Shared By / Shared With sections.
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
        // `.owner` is an editing permission too — see `StorePermission.canEdit`.
        let isEdit = permission.canEdit
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

    /// The tab in effect. Until the user taps one, open on Friends when there is
    /// no family to show, so the sheet never lands on an empty list.
    private var activeRecipientTab: RecipientTab {
        if let recipientTab {
            return recipientTab
        }
        return friendsViewModel.familyMembers.isEmpty && !friendsViewModel.friends.isEmpty
            ? .friends
            : .family
    }

    private func isAlreadyShared(_ contact: Contact) -> Bool {
        sharedUser(for: contact) != nil
    }

    /// The share record for a contact, when the store is shared with them.
    private func sharedUser(for contact: Contact) -> SharedUser? {
        sharedUsers.first { $0.userEmail.lowercased() == contact.email.lowercased() }
    }

    /// The recipient list's panel colour. Off-white in light mode; dark mode gets
    /// the system's equivalent so the row text stays legible.
    private var recipientListBackground: Color {
        colorScheme == .dark
            ? Color(.secondarySystemBackground)
            : Color(red: 0.98, green: 0.98, blue: 0.97)
    }

    /// Every contact the sheet can share with, across both tabs.
    private var allSelectableContacts: [Contact] {
        (friendsViewModel.familyMembers + friendsViewModel.friends)
            .map { $0.toContact(currentUserId: currentUserId) }
    }

    /// The ticked contacts, minus anyone the store is already shared with.
    private var selectedContacts: [Contact] {
        allSelectableContacts.filter {
            selectedContactIDs.contains($0.id) && !isAlreadyShared($0)
        }
    }

    /// Family members still available to share with.
    private var unsharedFamilyContacts: [Contact] {
        friendsViewModel.familyMembers
            .map { $0.toContact(currentUserId: currentUserId) }
            .filter { !isAlreadyShared($0) }
    }

    /// True once every shareable family member is ticked.
    private var allFamilySelected: Bool {
        !unsharedFamilyContacts.isEmpty
            && unsharedFamilyContacts.allSatisfy { selectedContactIDs.contains($0.id) }
    }

    /// The contacts listed under the active tab.
    private var activeRecipientContacts: [Contact] {
        let friendships = activeRecipientTab == .family
            ? friendsViewModel.familyMembers
            : friendsViewModel.friends
        return friendships.map { $0.toContact(currentUserId: currentUserId) }
    }

    private var allFamilyAlreadyShared: Bool {
        unsharedFamilyContacts.isEmpty
    }

    // MARK: - FUNCTIONS

    /// Revokes a recipient's access from their row.
    private func unshare(_ contact: Contact) {
        guard let sharedUser = sharedUser(for: contact) else { return }
        unshareWithUser(sharedUser)
    }

    /// Looks up the sharer's profile picture so their avatar matches the rest of
    /// the app rather than falling back to an initial.
    private func fetchSharedByPicture() {
        guard let sharerId = userStoreItem.sharedFromId, !sharerId.isEmpty else { return }

        db.collection("users").document(sharerId).getDocument { snapshot, error in
            if let error = error {
                #if DEBUG
                print("ShareStoreView: Error fetching sharer profile: \(error.localizedDescription)")
                #endif
                return
            }
            guard let url = snapshot?.data()?["profilePictureURL"] as? String, !url.isEmpty else {
                return
            }
            self.sharedByPictureURL = url
        }
    }

    private func toggleSelection(of contact: Contact) {
        if selectedContactIDs.contains(contact.id) {
            selectedContactIDs.remove(contact.id)
        } else {
            selectedContactIDs.insert(contact.id)
        }
    }

    /// Ticks every shareable family member, or clears them if all are already ticked.
    private func toggleAllFamily() {
        let ids = unsharedFamilyContacts.map(\.id)
        if allFamilySelected {
            selectedContactIDs.subtract(ids)
        } else {
            selectedContactIDs.formUnion(ids)
        }
    }

    /// Sends a share request to every ticked recipient.
    private func shareStore() {
        guard let currentUserName = viewModel.sessionManager.currentUser?.name else {
            alertTitle = "Error"
            alertMessage = "No user data available."
            showAlert = true
            return
        }

        let recipients = selectedContacts

        guard !recipients.isEmpty else {
            alertTitle = "No Recipients"
            alertMessage = "Select at least one family member or friend to share with."
            showAlert = true
            return
        }

        let permissionString = selectedPermission == .edit ? "edit" : "view"
        let total = recipients.count

        isSharing = true
        shareProgress = "Sharing with 0/\(total)..."

        var successCount = 0
        var failCount = 0
        let group = DispatchGroup()

        for contact in recipients {
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
                DispatchQueue.main.async {
                    if success {
                        successCount += 1
                    } else {
                        failCount += 1
                    }
                    shareProgress = "Sharing with \(successCount + failCount)/\(total)..."
                    group.leave()
                }
            }
        }

        group.notify(queue: .main) {
            isSharing = false
            shareProgress = ""
            fetchSharedUsers()

            if successCount == total {
                alertTitle = "Success"
                alertMessage = total == 1
                    ? "Share request sent! The recipient will see it in their messages and can accept or decline."
                    : "Share requests sent to \(total) people! They will see it in their messages."
            } else if successCount > 0 {
                alertTitle = "Partially Shared"
                alertMessage = "Shared with \(successCount) of \(total) recipients. \(failCount) could not be shared (they may already have this store)."
            } else {
                alertTitle = "Error"
                alertMessage = "Failed to send the share requests. Please try again."
            }
            showAlert = true
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
                        sharedAt: sharedAt,
                        mergedFromOwnStore: data["mergedFromOwnStore"] as? Bool ?? false
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

            // This recipient owned the same store and merged it into ours, so the items
            // they brought with them live on OUR store now. Deleting their user_store
            // would take the whole list — including everything they had before the
            // merge — away from them. Hand the store back instead.
            if sharedUser.mergedFromOwnStore,
               let currentUserName = viewModel.sessionManager.currentUser?.name {
                self.sharedUsers.removeAll { $0.id == sharedUser.id }
                viewModel.restoreMergedStoreToOwnStore(
                    userStoreId: sharedUser.id,
                    sourceUserStoreId: userStoreItem.id,
                    departingOwnerName: currentUserName
                ) {
                    // Only strip them from our side once they have their copy.
                    self.updateRemindersAfterUnshare(recipientName: recipientName)
                    self.updateOwnerUserStoreAfterUnshare(recipientName: recipientName)
                }
                self.sendUnshareMessage(to: sharedUser, recipientName: recipientName)
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
