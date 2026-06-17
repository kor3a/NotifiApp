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
    @State private var smartCategoryEnabled = true
    @State private var showInfoPanel = false
    @State private var showingRecipePicker = false
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
    @State private var lastSubmittedAt: Date?
    @State private var showRemoveAllFavoritesConfirmation = false
    @State private var checkboxFrames: [String: CGRect] = [:]
    @State private var swipedIds: Set<String> = []
    @State private var pendingDeleteReminder: Reminder?
    @State private var undoWorkItem: DispatchWorkItem?
    @State private var pendingDeletePhoto: (reminder: Reminder, url: String)?
    @State private var photoUndoWorkItem: DispatchWorkItem?
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

    @ObservedObject private var subscriptionManager = SubscriptionManager.shared

    private var isSubscribed: Bool {
        subscriptionManager.isSubscribed
    }

    /// Smart Category is active only when the user is subscribed AND has the toggle enabled.
    private var effectiveSmartCategoryEnabled: Bool {
        isSubscribed && smartCategoryEnabled
    }

    private var smartCategoryKey: String {
        "smartCategoryEnabled_\(userStoreItem.id)"
    }

    var body: some View {
        coreView
            .sheet(item: $reminderToShare) { reminder in
                ShareReminderView(reminder: reminder, store: userStoreItem.store)
            }
            .sheet(isPresented: $showingRecipePicker) {
                RecipePickerView(userStoreItem: userStoreItem)
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
                        stageReminderForDeletion(reminder)
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

    private var coreView: some View {
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

            // Undo toast — floats above all content after a deletion
            if pendingDeletePhoto != nil {
                undoToastView(message: "Photo deleted", onUndo: undoPendingPhotoDeletion)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(3)
            } else if let pending = pendingDeleteReminder {
                undoToastView(message: "\"\(pending.title)\" deleted", onUndo: undoPendingDeletion)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(3)
            }

            // Info panel — tap outside to dismiss
            if showInfoPanel {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            showInfoPanel = false
                        }
                    }
                    .ignoresSafeArea()
                    .zIndex(9)

                infoPanelOverlay
                    .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .topTrailing)))
                    .zIndex(10)
            }

            // Sticky banner ad above tab bar (hidden for subscribers)
            if !isSubscribed {
                VStack(spacing: 0) {
                    Spacer()
                    BannerAdView(adUnitID: kBannerAdUnitID)
                        .frame(height: 50)
                        .background(Color(.systemBackground).opacity(0.95))
                }
            }
        }
        .navigationTitle(userStoreItem.store.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .onAppear {
            viewModel.fetchReminders(for: userStoreItem.reminderStoreId, sharedFromName: userStoreItem.sharedFromName)
            viewModel.fetchFavoriteTags(for: userStoreItem.reminderStoreId)
            smartCategoryEnabled = UserDefaults.standard.object(forKey: smartCategoryKey) as? Bool ?? true
        }
        .onChange(of: smartCategoryEnabled) { oldValue, newValue in
            UserDefaults.standard.set(newValue, forKey: smartCategoryKey)
            #if DEBUG
            if !oldValue && newValue && isSubscribed {
                viewModel.categorizeUncategorizedReminders()
            }
            #endif
        }
        .onChange(of: autoDeleteEnabled) { oldValue, newValue in
            if newValue && !oldValue {
                deleteCompletedReminders()
            }
        }
        .onChange(of: isNewReminderFocused) { _, focused in
            if !focused && isAddingNewReminder {
                let title = newReminderText.trimmingCharacters(in: .whitespaces)
                // After a submission, the text is briefly empty before the user types
                // the next item. AI categorization for the just-submitted reminder can
                // land in that window and re-render the list, transiently dropping focus.
                // Treat focus losses inside this grace window as incidental and re-focus.
                let inSubmissionGrace = lastSubmittedAt.map { Date().timeIntervalSince($0) < 3.0 } ?? false
                if title.isEmpty && !inSubmissionGrace {
                    isAddingNewReminder = false
                } else {
                    // Focus was lost while actively typing (e.g. due to AI categorization
                    // triggering a Firestore update and SwiftUI re-render). Restore it.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        if isAddingNewReminder {
                            isNewReminderFocused = true
                        }
                    }
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
        .onChange(of: viewModel.displayedReminders.count) { _, count in
            if autoDeleteEnabled && count == 0 {
                autoDeleteEnabled = false
            }
        }
        .onDisappear {
            autoDeleteEnabled = false
            // Commit any pending deletion immediately when leaving the view
            if let pending = pendingDeletePhoto {
                photoUndoWorkItem?.cancel()
                photoUndoWorkItem = nil
                pendingDeletePhoto = nil
                viewModel.unstagePhotoUrl(pending.url)
                viewModel.deletePhoto(for: pending.reminder, photoURL: pending.url)
            }
            if let pending = pendingDeleteReminder {
                undoWorkItem?.cancel()
                undoWorkItem = nil
                pendingDeleteReminder = nil
                viewModel.commitStagedDeletion(pending)
            }

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
                    finalTitle: title,
                    useSmartCategory: effectiveSmartCategoryEnabled
                )
            }

            sendPendingSharedNotificationsIfNeeded()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background {
                // Commit any pending deletions before going to background
                if let pending = pendingDeletePhoto {
                    photoUndoWorkItem?.cancel()
                    photoUndoWorkItem = nil
                    pendingDeletePhoto = nil
                    viewModel.unstagePhotoUrl(pending.url)
                    viewModel.deletePhoto(for: pending.reminder, photoURL: pending.url)
                }
                if let pending = pendingDeleteReminder {
                    undoWorkItem?.cancel()
                    undoWorkItem = nil
                    pendingDeleteReminder = nil
                    viewModel.commitStagedDeletion(pending)
                }
                sendPendingSharedNotificationsIfNeeded()
            }
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

                if !isReorderMode {
                    // Always render the sectioned structure so that the List's
                    // direct children don't change shape when the first AI
                    // categorization arrives mid-typing — otherwise the List
                    // reconciles and the focused TextField in inlineAddSection
                    // gets torn down, dropping the keyboard.
                    ForEach(viewModel.displayedCategoryOrder, id: \.self) { category in
                        Section {
                            if !collapsedCategories.contains(category) {
                                ForEach(viewModel.displayedReminders(for: category)) { reminder in
                                    reminderRow(for: reminder)
                                }
                            }
                        } header: {
                            if viewModel.hasDisplayedCategorizedReminders {
                                categoryHeader(for: category)
                            }
                        }
                    }
                } else {
                    // Reorder mode requires a flat ForEach for .onMove to work.
                    ForEach(viewModel.displayedReminders) { reminder in
                        reminderRow(for: reminder)
                    }
                    .onMove(perform: { source, destination in
                        viewModel.moveReminder(from: source, to: destination)
                    })
                    .deleteDisabled(true)
                }

                // Inline add reminder row (hidden during reorder mode)
                if userStoreItem.permission != .view && !isReorderMode {
                    inlineAddSection
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: 50)
            }
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
            // Re-scroll after the keyboard has fully animated in so the
            // input row is visible above the keyboard (not hidden behind it).
            .onChange(of: isNewReminderFocused) { _, focused in
                if focused {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        withAnimation {
                            proxy.scrollTo("inlineAddRow", anchor: .bottom)
                        }
                    }
                }
            }
            // When AI categorization lands and reorders the list, keep the input row
            // visible so the focused TextField cell isn't pushed off-screen and recycled.
            .onChange(of: viewModel.displayedCategoryOrder) { _, _ in
                if isNewReminderFocused {
                    withAnimation {
                        proxy.scrollTo("inlineAddRow", anchor: .bottom)
                    }
                }
            }
            .onChange(of: viewModel.displayedReminders.count) { _, _ in
                if isNewReminderFocused {
                    withAnimation {
                        proxy.scrollTo("inlineAddRow", anchor: .bottom)
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
        // Filter out any photo URLs that are staged for deletion so they
        // disappear immediately while the undo window is open.
        let displayReminder: Reminder = {
            guard !viewModel.stagedPhotoUrls.isEmpty,
                  let urls = reminder.photoURLs,
                  urls.contains(where: { viewModel.stagedPhotoUrls.contains($0) }) else {
                return reminder
            }
            var r = reminder
            r.photoURLs = urls.filter { !viewModel.stagedPhotoUrls.contains($0) }
            return r
        }()
        return ReminderItemView(
            item: displayReminder,
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
                viewModel.moveReminderToStore(reminder, targetStore: targetStore)
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
                        stageReminderForDeletion(reminder)
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
                                    currentUserName: UserSessionManager.shared.currentUser?.name,
                                    useSmartCategory: effectiveSmartCategoryEnabled
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
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    isNewReminderFocused = true
                }
            }
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
                        withAnimation { enlargedPhotoURL = nil }
                        enlargedPhotoReminder = nil
                        stagePhotoForDeletion(reminder: reminder, url: url)
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
            if userStoreItem.permission != .view && !viewModel.displayedReminders.isEmpty {
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
            } else if userStoreItem.permission == .view {
                Image(systemName: "eye.fill")
                    .foregroundStyle(.secondary)
                    .frame(width: 22, height: 22)
            }
        }

        ToolbarItem(placement: .navigationBarTrailing) {
            if !isReorderMode {
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        showInfoPanel.toggle()
                    }
                } label: {
                    Image(systemName: showInfoPanel ? "info.circle.fill" : "info.circle")
                        .frame(width: 22, height: 22)
                }
                .frame(width: 44, height: 44)
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
                finalTitle: title,
                useSmartCategory: effectiveSmartCategoryEnabled
            )
        } else {
            // No autosave yet (user pressed Return before debounce fired) - create normally
            viewModel.addReminder(
                userStoreId: userStoreItem.reminderStoreId,
                title: title,
                sharedWith: userStoreItem.sharedWith,
                sharedFromName: userStoreItem.sharedFromName,
                currentUserName: UserSessionManager.shared.currentUser?.name,
                useSmartCategory: effectiveSmartCategoryEnabled
            )
        }

        // Clear text and keep focus for next reminder
        newReminderText = ""
        lastSubmittedAt = Date()
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

            // After fade animation, stage the deletion (undo still possible)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                fadingReminderIds.remove(reminder.id)
                stageReminderForDeletion(reminder)
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

    // MARK: - Photo Undo Deletion

    /// Stage a photo for deletion and open the 5-second undo window.
    /// The photo URL remains in Firestore until the window expires (or view disappears).
    private func stagePhotoForDeletion(reminder: Reminder, url: String) {
        // If a reminder deletion is pending, commit it first (only one toast at a time)
        if let pending = pendingDeleteReminder {
            undoWorkItem?.cancel()
            undoWorkItem = nil
            pendingDeleteReminder = nil
            viewModel.commitStagedDeletion(pending)
        }
        // If a different photo deletion is pending, commit it first
        if let existing = pendingDeletePhoto, existing.url != url {
            photoUndoWorkItem?.cancel()
            photoUndoWorkItem = nil
            viewModel.deletePhoto(for: existing.reminder, photoURL: existing.url)
        }

        photoUndoWorkItem?.cancel()
        viewModel.stagePhotoUrl(url)  // hide the photo immediately in the item list
        withAnimation(.spring(duration: 0.35)) {
            pendingDeletePhoto = (reminder: reminder, url: url)
        }

        let workItem = DispatchWorkItem {
            commitPendingPhotoDeletion()
        }
        photoUndoWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: workItem)
    }

    /// Permanently delete the staged photo (undo window expired or view closing).
    private func commitPendingPhotoDeletion() {
        guard let pending = pendingDeletePhoto else { return }
        photoUndoWorkItem?.cancel()
        photoUndoWorkItem = nil
        withAnimation(.spring(duration: 0.35)) {
            pendingDeletePhoto = nil
        }
        // stagedPhotoUrls entry is left in place; the snapshot listener cleans it
        // up automatically once Firestore confirms the URL is gone.
        viewModel.deletePhoto(for: pending.reminder, photoURL: pending.url)
    }

    /// Restore the staged photo — user tapped Undo.
    /// Photo URL is still in Firestore; un-staging makes it visible again.
    private func undoPendingPhotoDeletion() {
        guard let pending = pendingDeletePhoto else { return }
        photoUndoWorkItem?.cancel()
        photoUndoWorkItem = nil
        viewModel.unstagePhotoUrl(pending.url)  // restore photo in item list
        withAnimation(.spring(duration: 0.35)) {
            pendingDeletePhoto = nil
        }
    }

    // MARK: - Undo Deletion

    /// Stage a reminder for deletion and start the 5-second undo window.
    private func stageReminderForDeletion(_ reminder: Reminder) {
        // If a photo deletion is pending, commit it first (only one toast at a time)
        if let photo = pendingDeletePhoto {
            photoUndoWorkItem?.cancel()
            photoUndoWorkItem = nil
            pendingDeletePhoto = nil
            viewModel.deletePhoto(for: photo.reminder, photoURL: photo.url)
        }
        // If there's already a staged reminder deletion, commit it immediately
        if let previous = pendingDeleteReminder, previous.id != reminder.id {
            undoWorkItem?.cancel()
            undoWorkItem = nil
            viewModel.commitStagedDeletion(previous)
        }

        undoWorkItem?.cancel()
        viewModel.stageForDeletion(reminder)

        withAnimation(.spring(duration: 0.35)) {
            pendingDeleteReminder = reminder
        }

        let workItem = DispatchWorkItem {
            commitPendingDeletion()
        }
        undoWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: workItem)
    }

    /// Permanently delete the staged reminder (undo window expired or view closing).
    private func commitPendingDeletion() {
        guard let reminder = pendingDeleteReminder else { return }
        undoWorkItem?.cancel()
        undoWorkItem = nil
        withAnimation(.spring(duration: 0.35)) {
            pendingDeleteReminder = nil
        }
        viewModel.commitStagedDeletion(reminder)
    }

    /// Restore the staged reminder — user tapped Undo.
    private func undoPendingDeletion() {
        guard let reminder = pendingDeleteReminder else { return }
        undoWorkItem?.cancel()
        undoWorkItem = nil
        withAnimation(.spring(duration: 0.35)) {
            pendingDeleteReminder = nil
        }
        viewModel.undoStagedDeletion(reminder.id)
    }

    // MARK: - Undo Toast View

    private func undoToastView(message: String, onUndo: @escaping () -> Void) -> some View {
        VStack {
            Spacer()
            HStack(spacing: 12) {
                Image(systemName: "trash.fill")
                    .foregroundStyle(.white.opacity(0.75))
                    .font(.subheadline)

                Text(message)
                    .foregroundStyle(.white)
                    .font(.subheadline)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer()

                Button {
                    onUndo()
                } label: {
                    Text("Undo")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.yellow)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(
                Capsule()
                    .fill(Color(.systemGray2).opacity(colorScheme == .dark ? 0.95 : 0.85))
                    .shadow(color: .black.opacity(0.25), radius: 12, x: 0, y: 4)
            )
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .allowsHitTesting(true)
    }

    // MARK: - Info Panel

    private var infoPanelOverlay: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top) {
                Spacer()
                VStack(alignment: .leading, spacing: 0) {
                    // Auto Delete row
                    HStack(spacing: 12) {
                        Image(systemName: autoDeleteEnabled ? "trash.fill" : "trash")
                            .font(.body)
                            .foregroundColor(autoDeleteEnabled ? .red : .primary)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Auto Delete")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text("Delete checked items automatically")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: $autoDeleteEnabled)
                            .labelsHidden()
                            .disabled(userStoreItem.permission == .view)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                    Divider()
                        .padding(.horizontal, 16)

                    // Smart Category row
                    HStack(spacing: 12) {
                        Image(systemName: "sparkles")
                            .font(.body)
                            .foregroundColor(isSubscribed ? Color.appAccent : .secondary)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Smart Category")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(isSubscribed ? Color.primary : Color.secondary)
                            Text(isSubscribed ? "AI auto-categorizes new items" : "Available for subscribers")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if isSubscribed {
                            Toggle("", isOn: $smartCategoryEnabled)
                                .labelsHidden()
                        } else {
                            Image(systemName: "lock.fill")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                    if userStoreItem.permission != .view {
                        Divider()
                            .padding(.horizontal, 16)

                        // Recipes row
                        Button {
                            withAnimation(.easeInOut(duration: 0.18)) {
                                showInfoPanel = false
                            }
                            showingRecipePicker = true
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "fork.knife")
                                    .font(.body)
                                    .foregroundColor(Color.appAccent)
                                    .frame(width: 24)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Recipes")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundStyle(Color.primary)
                                    Text("Add ingredients from a saved recipe")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.regularMaterial)
                        .shadow(color: .black.opacity(0.2), radius: 16, x: 0, y: 8)
                )
                .frame(width: 290)
                .padding(.trailing, 12)
            }
            Spacer()
        }
        .padding(.top, 8)
        .allowsHitTesting(true)
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
        sharedFromId: nil,
        sharedWith: nil,
        notificationsEnabled: true
    ))
}
