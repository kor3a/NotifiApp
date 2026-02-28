//
//  ReminderSummaryView.swift
//  Geolocation_v1.0.0
//
//  Created by James Jeon on 10/8/24.
//

import SwiftUI

struct ReminderView: View {
    let userStoreItem: UserStoreItem
    var availableStores: [UserStoreItem] = []
    @StateObject private var viewModel = ReminderViewModel()
    @State private var isAddingNewReminder = false
    @State private var newReminderText = ""
    @FocusState private var isNewReminderFocused: Bool
    @AppStorage("autoDeleteReminders") private var autoDeleteEnabled = false
    @State private var fadingReminderIds: Set<String> = []
    @State private var reminderToShare: Reminder?
    @State private var reminderToDelete: Reminder?
    @State private var showingSharedInfo: Reminder?
    @State private var reminderForPhoto: Reminder?
    @State private var selectedImage: UIImage?
    @State private var enlargedPhotoURL: String?
    @State private var enlargedPhotoReminder: Reminder?
    @State private var showDeletePhotoConfirm = false
    @State private var editingReminderId: String?
    @State private var editingQuantityReminderId: String?
    @State private var isReorderMode = false
    @State private var showDuplicateAlert = false
    @State private var duplicateTitle = ""
    @State private var reminderForQuantity: Reminder?
    @State private var quantityText = ""
    @State private var reminderForCategory: Reminder?
    @State private var customCategoryText = ""
    @State private var collapsedCategories: Set<String> = []
    @State private var autosaveWorkItem: DispatchWorkItem?
    @State private var showRemoveAllFavoritesConfirmation = false
    @State private var checkboxFrames: [String: CGRect] = [:]
    @State private var swipedIds: Set<String> = []
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.scenePhase) var scenePhase

    private var editMode: Binding<EditMode> {
        Binding(
            get: { isReorderMode ? .active : .inactive },
            set: { newValue in
                isReorderMode = (newValue == .active)
            }
        )
    }

    var body: some View {
        ZStack {
            if viewModel.isLoading {
                ProgressView("Loading reminders...")
            } else if viewModel.displayedReminders.isEmpty && !isAddingNewReminder {
                emptyStateView
            } else {
                reminderListView
            }

            if enlargedPhotoURL != nil {
                photoOverlayView
            }

            // Auto-delete swipe rail — lives OUTSIDE the List so its
            // UIPanGestureRecognizer never competes with UITableView's scroll.
            // The rail's custom hitTest only claims touches starting in the
            // left handle strip (x < 40 pt), so checkboxes and all other row
            // interactions remain fully functional.
            if autoDeleteEnabled && userStoreItem.permission != .view {
                AutoDeleteSwipeRail(
                    captureWidth: 40,
                    isEnabled: autoDeleteEnabled,
                    onDragChanged: { location in
                        for (id, frame) in checkboxFrames {
                            guard !swipedIds.contains(id) else { continue }
                            if location.y >= (frame.minY - 20) && location.y <= (frame.maxY + 20),
                               let target = viewModel.reminders.first(where: { $0.id == id }) {
                                swipedIds.insert(id)
                                handleReminderTap(target)
                            }
                        }
                    },
                    onDragEnded: {
                        swipedIds.removeAll()
                    }
                )
                .ignoresSafeArea()
            }
        }
        .navigationTitle(userStoreItem.store.name)
        .toolbar { toolbarContent }
        .onAppear {
            viewModel.fetchReminders(for: userStoreItem.reminderStoreId, sharedFromName: userStoreItem.sharedFromName)
            viewModel.fetchFavoriteTags(for: userStoreItem.reminderStoreId)
        }
        .onChange(of: autoDeleteEnabled) { oldValue, newValue in
            if newValue && !oldValue {
                deleteCompletedReminders()
            }
        }
        .onChange(of: isNewReminderFocused) { _, focused in
            if !focused && isAddingNewReminder {
                let title = newReminderText.trimmingCharacters(in: .whitespaces)
                if title.isEmpty {
                    isAddingNewReminder = false
                }
            }
        }
        .onChange(of: newReminderText) { _, newValue in
            autosaveWorkItem?.cancel()

            let trimmed = newValue.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                viewModel.discardAutosave()
                return
            }

            guard isAddingNewReminder else { return }

            let vm = viewModel
            let storeId = userStoreItem.reminderStoreId
            let shared = userStoreItem.sharedWith
            let sharedFrom = userStoreItem.sharedFromName
            let userName = UserSessionManager.shared.currentUser?.name

            let workItem = DispatchWorkItem {
                vm.autosaveReminder(
                    userStoreId: storeId,
                    title: newValue,
                    sharedWith: shared,
                    sharedFromName: sharedFrom,
                    currentUserName: userName
                )
            }
            autosaveWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: workItem)
        }
        .onDisappear {
            autosaveWorkItem?.cancel()
            let title = newReminderText.trimmingCharacters(in: .whitespaces)
            if !title.isEmpty && isAddingNewReminder {
                if viewModel.autosavedReminderId == nil {
                    // No autosave yet (debounce hadn't fired) — create it immediately
                    viewModel.autosaveReminder(
                        userStoreId: userStoreItem.reminderStoreId,
                        title: title,
                        sharedWith: userStoreItem.sharedWith,
                        sharedFromName: userStoreItem.sharedFromName,
                        currentUserName: UserSessionManager.shared.currentUser?.name
                    )
                }
                // Finalize with fire-and-forget categorization that survives ViewModel deallocation
                viewModel.finalizeAutosave(
                    userStoreId: userStoreItem.reminderStoreId,
                    finalTitle: title
                )
            }

            sendPendingSharedNotificationsIfNeeded()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background {
                sendPendingSharedNotificationsIfNeeded()
            }
        }
        .sheet(item: $reminderToShare) { reminder in
            ShareReminderView(reminder: reminder, store: userStoreItem.store)
        }
        .sheet(item: $reminderForPhoto) { reminder in
            ImagePicker(selectedImage: $selectedImage) { image in
                viewModel.uploadPhoto(for: reminder, image: image)
            }
        }
        .alert("Delete Shared Reminder", isPresented: .init(
            get: { reminderToDelete != nil },
            set: { if !$0 { reminderToDelete = nil } }
        )) {
            Button("Delete for Everyone", role: .destructive) {
                if let reminder = reminderToDelete {
                    viewModel.deleteReminder(reminder)
                    reminderToDelete = nil
                }
            }
            Button("Cancel", role: .cancel) {
                reminderToDelete = nil
            }
        } message: {
            deleteSharedReminderMessage
        }
        .alert("Shared Reminder", isPresented: .init(
            get: { showingSharedInfo != nil },
            set: { if !$0 { showingSharedInfo = nil } }
        )) {
            Button("OK", role: .cancel) {
                showingSharedInfo = nil
            }
        } message: {
            sharedReminderInfoMessage
        }
        .alert("Duplicate Reminder", isPresented: $showDuplicateAlert) {
            Button("OK", role: .cancel) {
                newReminderText = ""
            }
        } message: {
            Text("'\(duplicateTitle)' already exists in this store.")
        }
        .alert("Add Quantity", isPresented: .init(
            get: { reminderForQuantity != nil },
            set: { if !$0 { reminderForQuantity = nil } }
        )) {
            TextField("Quantity", text: $quantityText)
                .keyboardType(.numberPad)
            Button("Save") {
                if let reminder = reminderForQuantity {
                    let qty = Int(quantityText)
                    viewModel.updateReminderQuantity(reminder, newQuantity: qty)
                }
                reminderForQuantity = nil
                quantityText = ""
            }
            Button("Remove", role: .destructive) {
                if let reminder = reminderForQuantity {
                    viewModel.updateReminderQuantity(reminder, newQuantity: nil)
                }
                reminderForQuantity = nil
                quantityText = ""
            }
            Button("Cancel", role: .cancel) {
                reminderForQuantity = nil
                quantityText = ""
            }
        } message: {
            Text("Enter quantity for this reminder item.")
        }
        .alert("Set Category", isPresented: .init(
            get: { reminderForCategory != nil },
            set: { if !$0 { reminderForCategory = nil } }
        )) {
            TextField("Category name", text: $customCategoryText)
                .textInputAutocapitalization(.words)
            Button("Save") {
                if let reminder = reminderForCategory {
                    let cat = customCategoryText.trimmingCharacters(in: .whitespaces)
                    viewModel.updateReminderCategory(reminder, newCategory: cat.isEmpty ? nil : cat)
                }
                reminderForCategory = nil
                customCategoryText = ""
            }
            Button("Remove Category", role: .destructive) {
                if let reminder = reminderForCategory {
                    viewModel.updateReminderCategory(reminder, newCategory: nil)
                }
                reminderForCategory = nil
                customCategoryText = ""
            }
            Button("Cancel", role: .cancel) {
                reminderForCategory = nil
                customCategoryText = ""
            }
        } message: {
            Text("Enter a custom category for this item.")
        }
    }

    // MARK: - Extracted Sub-Views

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "list.bullet.clipboard")
                .resizable()
                .frame(width: 60, height: 60)
                .foregroundStyle(.gray)

            Text("No Reminders")
                .font(.title2)
                .bold()

            Text("Add reminders for this store")
                .foregroundStyle(.gray)

            if userStoreItem.permission != .view {
                Button {
                    isAddingNewReminder = true
                } label: {
                    Label("Add Reminder", systemImage: "plus")
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal)
            } else {
                Text("View only - cannot add reminders")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }

    private var reminderListView: some View {
        ScrollViewReader { proxy in
            List {
                // Favorite tags section
                if !viewModel.favoriteTags.isEmpty {
                    favoriteTagsSection
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                }

                if viewModel.hasDisplayedCategorizedReminders && !isReorderMode {
                    // Grouped by category
                    ForEach(viewModel.displayedCategoryOrder, id: \.self) { category in
                        Section {
                            if !collapsedCategories.contains(category) {
                                ForEach(viewModel.displayedReminders(for: category)) { reminder in
                                    reminderRow(for: reminder)
                                }
                            }
                        } header: {
                            categoryHeader(for: category)
                        }
                    }
                } else {
                    // Flat list (no categories yet, or reorder mode)
                    ForEach(viewModel.displayedReminders) { reminder in
                        reminderRow(for: reminder)
                    }
                    .onMove(perform: isReorderMode ? { source, destination in
                        viewModel.moveReminder(from: source, to: destination)
                    } : nil)
                    .deleteDisabled(true)
                }

                // Inline add reminder row (hidden during reorder mode)
                if userStoreItem.permission != .view && !isReorderMode {
                    inlineAddSection
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .environment(\.editMode, editMode)
            .background(
                Color.backgroundGradient(for: colorScheme)
                    .ignoresSafeArea()
            )
            .onChange(of: isAddingNewReminder) { _, newValue in
                if newValue {
                    withAnimation {
                        proxy.scrollTo("inlineAddRow", anchor: .bottom)
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        isNewReminderFocused = true
                    }
                }
            }
        }
    }

    private func categoryHeader(for category: String) -> some View {
        Button {
            withAnimation {
                if collapsedCategories.contains(category) {
                    collapsedCategories.remove(category)
                } else {
                    collapsedCategories.insert(category)
                }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: categoryIcon(for: category))
                    .font(.caption)
                    .foregroundColor(Color.appAccent)
                    .frame(width: 20)

                Text(category)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)

                Text("\(viewModel.displayedReminders(for: category).count)")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.appAccent.opacity(0.7)))

                Spacer()

                Image(systemName: collapsedCategories.contains(category) ? "chevron.right" : "chevron.down")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }

    private func categoryIcon(for category: String) -> String {
        switch category.lowercased() {
        case "produce": return "leaf"
        case "dairy": return "cup.and.saucer"
        case "meat & seafood": return "fish"
        case "bakery": return "birthday.cake"
        case "beverages": return "waterbottle"
        case "snacks": return "popcorn"
        case "frozen": return "snowflake"
        case "canned goods": return "cylinder"
        case "condiments & sauces": return "flask"
        case "grains & pasta": return "takeoutbag.and.cup.and.straw"
        case "household": return "house"
        case "personal care": return "hands.sparkles"
        case "baby": return "stroller"
        case "pet": return "pawprint"
        case "health": return "cross.case"
        case "electronics": return "bolt"
        case "clothing": return "tshirt"
        case "uncategorized": return "questionmark.folder"
        default: return "tag"
        }
    }

    private func reminderRow(for reminder: Reminder) -> some View {
        ReminderItemView(
            item: reminder,
            isEditing: editingReminderId == reminder.id,
            isReorderMode: isReorderMode,
            onPhotoTap: { photoURL in
                enlargedPhotoURL = photoURL
                enlargedPhotoReminder = reminder
            },
            onCheckboxTap: userStoreItem.permission != .view ? {
                handleReminderTap(reminder)
            } : nil,
            onCheckboxLongPress: userStoreItem.permission != .view ? {
                viewModel.toggleOutOfStock(reminder)
            } : nil,
            onTextTap: userStoreItem.permission != .view ? {
                editingReminderId = reminder.id
            } : nil,
            onTitleCommit: { newTitle in
                if newTitle != reminder.title {
                    viewModel.updateReminderTitle(reminder, newTitle: newTitle)
                }
                editingReminderId = nil
            },
            onReorderTap: userStoreItem.permission != .view ? {
                withAnimation {
                    isReorderMode = true
                    isAddingNewReminder = false
                    editingReminderId = nil
                }
            } : nil,
            onAddToFavorites: userStoreItem.permission != .view ? {
                if viewModel.isFavoriteTag(title: reminder.title) {
                    if let tag = viewModel.favoriteTags.first(where: {
                        $0.title.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) == reminder.title.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                    }) {
                        viewModel.removeFavoriteTag(tag)
                    }
                } else {
                    viewModel.addFavoriteTag(userStoreId: userStoreItem.reminderStoreId, title: reminder.title)
                }
            } : nil,
            isFavorited: viewModel.isFavoriteTag(title: reminder.title),
            availableStores: availableStores,
            onMoveToStore: userStoreItem.permission != .view ? { targetStore in
                viewModel.moveReminderToStore(reminder, targetUserStoreId: targetStore.reminderStoreId)
            } : nil,
            onAddPhoto: userStoreItem.permission != .view ? {
                reminderForPhoto = reminder
            } : nil,
            onAddQuantity: userStoreItem.permission != .view ? {
                quantityText = reminder.quantity.map(String.init) ?? ""
                reminderForQuantity = reminder
            } : nil,
            isEditingQuantity: editingQuantityReminderId == reminder.id,
            onQuantityTap: userStoreItem.permission != .view ? {
                editingQuantityReminderId = reminder.id
            } : nil,
            onQuantityCommit: { newQuantity in
                if newQuantity != reminder.quantity {
                    viewModel.updateReminderQuantity(reminder, newQuantity: newQuantity)
                }
                editingQuantityReminderId = nil
            },
            category: reminder.category,
            onSetCategory: userStoreItem.permission != .view ? {
                customCategoryText = reminder.category ?? ""
                reminderForCategory = reminder
            } : nil,
            onCheckboxFrameChanged: { frame in
                checkboxFrames[reminder.id] = frame
            },
            onDragChanged: nil,
            onDragEnded: nil,
            autoDeleteEnabled: autoDeleteEnabled
        )
        .contentShape(Rectangle())
        .listRowBackground(cardRowBackground)
        .listRowSeparator(.hidden)
        .opacity(fadingReminderIds.contains(reminder.id) ? 0 : 1)
        .scaleEffect(fadingReminderIds.contains(reminder.id) ? 0.8 : 1.0)
        .animation(.easeOut(duration: 0.5), value: fadingReminderIds)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if userStoreItem.permission != .view {
                Button(role: .destructive) {
                    if reminder.isShared == true && reminder.sharedReminderId != nil {
                        reminderToDelete = reminder
                    } else {
                        viewModel.deleteReminder(reminder)
                    }
                } label: {
                    Image(systemName: "trash")
                }
            }

            Button {
                reminderToShare = reminder
            } label: {
                Image(systemName: "square.and.arrow.up")
            }
            .tint(.blue)

            if reminder.isShared == true {
                Button {
                    showingSharedInfo = reminder
                } label: {
                    Image(systemName: "person.2.fill")
                }
                .tint(.appAccent)
            }
        }
    }

    private var cardRowBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        Color.cardBorder(for: colorScheme),
                        lineWidth: 1.5
                    )
            )
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.1), radius: 8, x: 0, y: 4)
            .shadow(color: Color.white.opacity(colorScheme == .dark ? 0.05 : 0.5), radius: 2, x: 0, y: -2)
            .padding(.vertical, 4)
    }

    // MARK: - Favorite Tags

    private var favoriteTagsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Favorites")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(viewModel.favoriteTags) { tag in
                        let alreadyExists = viewModel.isDuplicateReminder(title: tag.title)
                        FavoriteTagView(title: tag.title, isActive: !alreadyExists)
                            .onTapGesture {
                                viewModel.addReminderFromFavorite(
                                    tag: tag,
                                    sharedWith: userStoreItem.sharedWith,
                                    sharedFromName: userStoreItem.sharedFromName,
                                    currentUserName: UserSessionManager.shared.currentUser?.name
                                )
                            }
                            .contextMenu {
                                Button(role: .destructive) {
                                    showRemoveAllFavoritesConfirmation = true
                                } label: {
                                    Label("Remove All Favorites", systemImage: "star.slash.fill")
                                }
                            }
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .confirmationDialog(
            "Remove All Favorites",
            isPresented: $showRemoveAllFavoritesConfirmation,
            titleVisibility: .visible
        ) {
            Button("Remove All", role: .destructive) {
                viewModel.removeAllFavoriteTags()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove all \(viewModel.favoriteTags.count) favorite\(viewModel.favoriteTags.count == 1 ? "" : "s"). This cannot be undone.")
        }
    }

    @ViewBuilder
    private var inlineAddSection: some View {
        if isAddingNewReminder {
            HStack {
                Image(systemName: "square")
                    .foregroundStyle(.gray.opacity(0.4))
                TextField("What do you need?", text: $newReminderText)
                    .font(.headline)
                    .focused($isNewReminderFocused)
                    .onSubmit {
                        submitNewReminder()
                    }
                    .textInputAutocapitalization(.sentences)
            }
            .listRowBackground(cardRowBackground)
            .listRowSeparator(.hidden)
            .id("inlineAddRow")
        } else {
            Button {
                isAddingNewReminder = true
            } label: {
                HStack {
                    Image(systemName: "plus")
                        .foregroundStyle(.gray)
                    Text("Add item")
                        .font(.headline)
                        .foregroundStyle(.gray)
                    Spacer()
                }
            }
            .listRowBackground(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial.opacity(0.5))
                    .padding(.vertical, 4)
            )
            .listRowSeparator(.hidden)
            .id("inlineAddRow")
        }
    }

    @ViewBuilder
    private var photoOverlayView: some View {
        if let photoURL = enlargedPhotoURL {
            Color.black.opacity(0.85)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation {
                        enlargedPhotoURL = nil
                        enlargedPhotoReminder = nil
                    }
                }

            VStack(spacing: 24) {
                Spacer()

                AsyncImage(url: URL(string: photoURL)) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                            .cornerRadius(12)
                            .padding(.horizontal, 20)
                    case .failure:
                        Image(systemName: "photo")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                    case .empty:
                        ProgressView()
                            .tint(.white)
                    @unknown default:
                        EmptyView()
                    }
                }

                Spacer()

                HStack(spacing: 40) {
                    Button {
                        showDeletePhotoConfirm = true
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: "trash.fill")
                                .font(.title2)
                            Text("Delete")
                                .font(.caption)
                        }
                        .foregroundColor(.red)
                    }

                    Button {
                        withAnimation {
                            enlargedPhotoURL = nil
                            enlargedPhotoReminder = nil
                        }
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                            Text("Close")
                                .font(.caption)
                        }
                        .foregroundColor(.white)
                    }
                }
                .padding(.bottom, 40)
            }
            .transition(.opacity)
            .alert("Delete Photo", isPresented: $showDeletePhotoConfirm) {
                Button("Delete", role: .destructive) {
                    if let reminder = enlargedPhotoReminder, let url = enlargedPhotoURL {
                        viewModel.deletePhoto(for: reminder, photoURL: url)
                    }
                    withAnimation {
                        enlargedPhotoURL = nil
                        enlargedPhotoReminder = nil
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to delete this photo?")
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            if userStoreItem.permission != .view {
                Toggle(isOn: $autoDeleteEnabled) {
                    Label("Auto-delete", systemImage: autoDeleteEnabled ? "trash.fill" : "trash")
                }
                .toggleStyle(.button)
                .labelStyle(.iconOnly)
                .tint(autoDeleteEnabled ? .red : .gray)
            }
        }

        ToolbarItem(placement: .navigationBarTrailing) {
            if isReorderMode {
                Button("Done") {
                    withAnimation {
                        isReorderMode = false
                    }
                }
            } else if userStoreItem.permission != .view {
                Button(action: {
                    isAddingNewReminder = true
                }) {
                    Image(systemName: "plus")
                        .frame(width: 22, height: 22)
                }
                .frame(width: 44, height: 44)
            } else {
                Image(systemName: "eye.fill")
                    .foregroundStyle(.secondary)
                    .frame(width: 22, height: 22)
            }
        }
    }

    @ViewBuilder
    private var deleteSharedReminderMessage: some View {
        if let reminder = reminderToDelete {
            if let sharedWith = reminder.sharedWith, !sharedWith.isEmpty {
                Text("This reminder is shared with \(sharedWith.joined(separator: ", ")). Deleting it will remove it for everyone.")
            } else if let sharedFrom = reminder.sharedFrom {
                Text("This reminder was shared by \(sharedFrom). Deleting it will remove it for everyone.")
            } else {
                Text("This reminder is shared. Deleting it will remove it for everyone.")
            }
        }
    }

    @ViewBuilder
    private var sharedReminderInfoMessage: some View {
        if let reminder = showingSharedInfo {
            let currentUserName = UserSessionManager.shared.currentUser?.name
            let currentUserId = UserSessionManager.shared.currentUser?.userId
            // Prefer ID-based comparison (reliable after name changes), fall back to name
            let isCurrentUserTheSharer: Bool = {
                if let sharedFromId = reminder.sharedFromId, !sharedFromId.isEmpty,
                   let currentUserId = currentUserId {
                    return sharedFromId == currentUserId
                }
                return reminder.sharedFrom != nil &&
                    !reminder.sharedFrom!.isEmpty &&
                    reminder.sharedFrom == currentUserName
            }()

            if isCurrentUserTheSharer {
                if let sharedWith = reminder.sharedWith, !sharedWith.isEmpty {
                    Text("You shared this reminder with:\n\(sharedWith.joined(separator: "\n"))\n\nChanges sync automatically.")
                } else {
                    Text("You shared this reminder.\n\nChanges sync automatically.")
                }
            } else if let sharedFrom = reminder.sharedFrom, !sharedFrom.isEmpty {
                if let sharedWith = reminder.sharedWith, !sharedWith.isEmpty {
                    Text("Shared by: \(sharedFrom)\nAlso shared with: \(sharedWith.filter { $0 != sharedFrom }.joined(separator: ", "))\n\nChanges sync automatically.")
                } else {
                    Text("Shared by: \(sharedFrom)\n\nChanges sync automatically.")
                }
            } else if let sharedWith = reminder.sharedWith, !sharedWith.isEmpty {
                Text("You shared this reminder with:\n\(sharedWith.joined(separator: "\n"))\n\nChanges sync automatically.")
            } else {
                Text("This reminder is synced across users.")
            }
        }
    }

    private func submitNewReminder() {
        let title = newReminderText.trimmingCharacters(in: .whitespaces)

        // Cancel any pending autosave debounce
        autosaveWorkItem?.cancel()
        autosaveWorkItem = nil

        if title.isEmpty {
            // Nothing entered - discard any autosave and stop adding
            viewModel.discardAutosave()
            isAddingNewReminder = false
            newReminderText = ""
            return
        }

        // Check for duplicates, excluding the autosaved reminder itself
        if viewModel.isDuplicateReminder(title: title, excludingId: viewModel.autosavedReminderId) {
            duplicateTitle = title
            showDuplicateAlert = true
            return
        }

        if viewModel.autosavedReminderId != nil {
            // Finalize the autosaved reminder with the final title
            viewModel.finalizeAutosave(
                userStoreId: userStoreItem.reminderStoreId,
                finalTitle: title
            )
        } else {
            // No autosave yet (user pressed Return before debounce fired) - create normally
            viewModel.addReminder(
                userStoreId: userStoreItem.reminderStoreId,
                title: title,
                sharedWith: userStoreItem.sharedWith,
                sharedFromName: userStoreItem.sharedFromName,
                currentUserName: UserSessionManager.shared.currentUser?.name
            )
        }

        // Clear text and keep focus for next reminder
        newReminderText = ""
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            isNewReminderFocused = true
        }
    }

    private func handleReminderTap(_ reminder: Reminder) {
        // Check if we're marking as done and auto-delete is enabled
        let willMarkAsDone = !reminder.isDone

        if willMarkAsDone && autoDeleteEnabled {
            // Add to fading set for animation
            fadingReminderIds.insert(reminder.id)

            // Delay deletion to show fade animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                viewModel.deleteReminder(reminder)
                fadingReminderIds.remove(reminder.id)
            }
        } else {
            // Normal toggle behavior
            viewModel.toggleReminder(reminder)
        }
    }

    private func deleteCompletedReminders() {
        // Find all reminders that are already marked as done
        let completedReminders = viewModel.reminders.filter { $0.isDone }

        // Stagger the animations for a cascading effect
        for (index, reminder) in completedReminders.enumerated() {
            let delay = Double(index) * 0.1 // 100ms between each animation

            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                // Start fade animation
                fadingReminderIds.insert(reminder.id)

                // Delete after animation completes
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    viewModel.deleteReminder(reminder)
                    fadingReminderIds.remove(reminder.id)
                }
            }
        }
    }

    /// Send shared store notifications if the store is shared and changes were made.
    /// Resets the pending change counters after sending.
    private func sendPendingSharedNotificationsIfNeeded() {
        #if DEBUG
        print("📤 ReminderView: sendPendingSharedNotificationsIfNeeded called")
        print("📤   isShared: \(userStoreItem.isShared), hasPendingChanges: \(viewModel.hasPendingChanges)")
        print("📤   pendingAdditions: \(viewModel.pendingAdditions), pendingOtherChanges: \(viewModel.pendingOtherChanges)")
        print("📤   currentUserId: \(UserSessionManager.shared.currentUser?.userId ?? "nil")")
        print("📤   currentUserName: \(UserSessionManager.shared.currentUser?.name ?? "nil")")
        #endif

        guard userStoreItem.isShared else {
            #if DEBUG
            print("📤 ReminderView: Skipping — store is not shared")
            #endif
            return
        }

        guard viewModel.hasPendingChanges else {
            #if DEBUG
            print("📤 ReminderView: Skipping — no pending changes")
            #endif
            return
        }

        guard let currentUserId = UserSessionManager.shared.currentUser?.userId,
              let currentUserName = UserSessionManager.shared.currentUser?.name else {
            #if DEBUG
            print("📤 ReminderView: Skipping — current user data not available")
            #endif
            return
        }

        #if DEBUG
        print("📤 ReminderView: Sending notifications for \(viewModel.pendingAdditions) additions, \(viewModel.pendingOtherChanges) other changes")
        #endif

        SharedReminderNotificationService.shared.sendNotifications(
            for: userStoreItem,
            addedCount: viewModel.pendingAdditions,
            otherChangeCount: viewModel.pendingOtherChanges,
            currentUserId: currentUserId,
            currentUserName: currentUserName
        )
        viewModel.resetPendingChanges()
    }
}

// MARK: - Favorite Tag View

struct FavoriteTagView: View {
    let title: String
    var isActive: Bool = true

    var body: some View {
        Text(title)
            .font(.caption)
            .fontWeight(.medium)
            .lineLimit(1)
            .foregroundColor(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(Color.appAccent.opacity(isActive ? 1.0 : 0.4))
            )
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
    }
}

#Preview {
    ReminderView(userStoreItem: UserStoreItem(
        id: "preview_user_store",
        store: Store(name: "Trader Joe's"),
        permission: .owner,
        sharedStoreGroupId: nil,
        sourceUserStoreId: nil,
        sharedFromName: nil,
        sharedWith: nil,
        notificationsEnabled: true
    ))
}
