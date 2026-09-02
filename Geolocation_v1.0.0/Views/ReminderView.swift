//
//  ReminderSummaryView.swift
//  Geolocation_v1.0.0
//
//  Created by James Jeon on 10/8/24.
//

import SwiftUI
import Foundation
import UniformTypeIdentifiers

/// Holds the global frames of each row's checkbox for the AutoDeleteSwipeRail's
/// pan hit-testing.
///
/// Deliberately a reference type held in `@State` rather than a `@State`
/// dictionary: rows report their frame on every displayed frame while the list
/// scrolls, and each write to a `@State` value invalidated ReminderView's entire
/// body — every visible row plus the store-wide avatar/member maps — at up to
/// 120Hz. The frames are never read during rendering, only inside the rail's
/// drag handler, so they don't need to drive view updates at all.
private final class CheckboxFrameStore {
    var frames: [String: CGRect] = [:]
}

struct ReminderView: View {
    let userStoreItem: UserStoreItem
    var availableStores: [UserStoreItem] = []
    @StateObject private var viewModel = ReminderViewModel()
    @Environment(\.openURL) private var openURL
    @State private var isAddingNewReminder = false
    @State private var newReminderText = ""
    @FocusState private var isNewReminderFocused: Bool
    @AppStorage("autoDeleteReminders") private var autoDeleteEnabled = false
    @State private var smartCategoryEnabled = true
    @State private var showSettingsSheet = false
    /// Set by a settings row that opens another sheet, run once the settings
    /// sheet has finished dismissing. See `runPendingSettingsAction()`.
    @State private var pendingSettingsAction: (() -> Void)?
    @State private var showBarcodePanel = false
    @State private var showingRecipePicker = false
    @State private var showingHistory = false
    @State private var showingAnalytics = false
    @State private var showingBackgroundPicker = false
    @State private var showingEditWebsite = false
    @State private var websiteInputText = ""
    @State private var fadingReminderIds: Set<String> = []
    @State private var reminderToShare: Reminder?
    @State private var reminderToDelete: Reminder?
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
    /// Category lifted by a press-and-drag, if any. Set on lift and cleared on
    /// drop; the section it names is dimmed while it's in flight.
    @State private var draggedCategory: String?
    /// Reminder lifted by a press-and-drag, if any.
    @State private var draggedReminderId: String?
    /// Frames of every drop target, kept while a drag is in flight.
    @State private var dragTargets = DragTargetFrameStore()
    /// Set once a backlog categorization pass has been requested for this
    /// appearance, so routine list changes don't keep re-requesting one. Cleared
    /// when Smart Category becomes available again (subscription or toggle).
    @State private var hasRequestedCategoryBackfill = false
    @State private var autosaveWorkItem: DispatchWorkItem?
    @State private var lastSubmittedAt: Date?
    @State private var showRemoveAllFavoritesConfirmation = false
    @State private var checkboxFrames = CheckboxFrameStore()
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
    /// Observed so the toolbar icon and the top sheet react when a card is
    /// added, edited or removed.
    @ObservedObject private var membershipCardStore = MembershipCardStore.shared
    // NOTE: don't observe StoreLogoProvider here. This view never reads a logo,
    // and observing the shared provider re-rendered the whole screen whenever a
    // logo resolved anywhere in the app.

    private var isSubscribed: Bool {
        subscriptionManager.isSubscribed
    }

    /// Smart Category is active only when the user is subscribed AND has the toggle enabled.
    private var effectiveSmartCategoryEnabled: Bool {
        isSubscribed && smartCategoryEnabled
    }

    /// Categorize items that are still uncategorized — typically a list built up
    /// while the user had no subscription, since Smart Category only runs on new
    /// items for subscribers.
    ///
    /// Called when the list first loads and whenever access turns on. The
    /// ViewModel skips items it has already sent to the AI and coalesces
    /// overlapping passes, so calling this more than once costs nothing.
    private func runCategoryBackfillIfNeeded() {
        guard effectiveSmartCategoryEnabled,
              // A viewer can't write to someone else's list.
              userStoreItem.permission != .view,
              // Wait for the first snapshot; an empty list has nothing to do.
              !viewModel.reminders.isEmpty,
              !hasRequestedCategoryBackfill else { return }

        hasRequestedCategoryBackfill = true
        viewModel.categorizeUncategorizedReminders()
    }

    /// Recipient names this (owner's) store is shared with, used to flag newly
    /// added reminders as shared so they get the shared icon.
    ///
    /// The owner's `user_store.sharedWith` is only written when the recipient
    /// accepts the invite, and `userStoreItem` is a snapshot that can be stale,
    /// so relying on it alone leaves reminders added later unflagged. When it's
    /// empty we recover the recipient list from reminders already marked shared
    /// (stamped at share time by `markRemindersAsShared`), excluding the current
    /// user's own name. Returns nil only when the store truly isn't shared.
    private var effectiveSharedWith: [String]? {
        if let sharedWith = userStoreItem.sharedWith, !sharedWith.isEmpty {
            return sharedWith
        }
        let currentUserName = UserSessionManager.shared.currentUser?.name
        let recovered = Set(
            viewModel.reminders
                .filter { $0.isShared == true }
                .flatMap { $0.sharedWith ?? [] }
        ).subtracting([currentUserName].compactMap { $0 })
        return recovered.isEmpty ? nil : Array(recovered)
    }

    /// userId → display name for everyone who participates in this store. Built
    /// from the current user, the store owner, and any reminder that recorded
    /// both an id and a name for its author or its last editor — so a
    /// participant's name (and initial) can be recovered for reminders that
    /// carry only their id.
    private var storeMemberNames: [String: String] {
        // Start with names resolved from the user's friends list, then let the
        // local (authoritative) sources below override.
        var names: [String: String] = viewModel.authorNamesById
        let currentUser = UserSessionManager.shared.currentUser
        if let id = currentUser?.userId, !id.isEmpty,
           let name = currentUser?.name, !name.isEmpty {
            names[id] = name
        }
        // Store owner (present on a recipient's copy of the store).
        if let id = userStoreItem.sharedFromId, !id.isEmpty,
           let name = userStoreItem.sharedFromName, !name.isEmpty {
            names[id] = name
        }
        // Any reminder that recorded both fields teaches us that id's name —
        // for whoever authored it and for whoever last edited it.
        for reminder in viewModel.reminders {
            if let id = reminder.sharedFromId, !id.isEmpty,
               let name = reminder.sharedFrom, !name.isEmpty {
                names[id] = name
            }
            if let id = reminder.lastEditedById, !id.isEmpty,
               let name = reminder.lastEditedBy, !name.isEmpty {
                names[id] = name
            }
        }
        return names
    }

    /// Store-wide avatar color assignment. Collects the identity of everyone
    /// whose avatar can appear in this store — each item's author and, where one
    /// exists, its last editor — and resolves colors so members who share a first
    /// initial never share a color. Participants are keyed by userId (via
    /// `participantIdentity`), so two *different* accounts with the same display
    /// name still get distinct colors. Computed from the full participant set so
    /// the mapping is stable across every reminder row.
    private var avatarColorMap: [String: Color] {
        let currentUser = UserSessionManager.shared.currentUser
        let members = storeMemberNames
        var identities: [(key: String, name: String)] = []

        // The current user always participates (they may have authored items).
        if let name = currentUser?.name, !name.isEmpty {
            identities.append((
                SharedAvatarPalette.identityKey(id: currentUser?.userId, name: name),
                name
            ))
        }

        for reminder in viewModel.reminders where reminder.isShared == true {
            // Recover a name from the member map when the reminder itself
            // carries only an id, so the color key and initial agree with what
            // the badge renders. Both the author and the last editor are
            // collected: the badge shows the editor once there is one, and the
            // author needs a color for every row nobody has edited yet.
            let participants = [
                (reminder.sharedFromId, reminder.sharedFrom),
                (reminder.lastEditedById, reminder.lastEditedBy)
            ]
            for (id, name) in participants {
                let resolvedName = (name?.isEmpty == false) ? name : id.flatMap { members[$0] }
                if let identity = SharedAvatarPalette.participantIdentity(
                    name: resolvedName,
                    id: id,
                    currentUserName: currentUser?.name,
                    currentUserId: currentUser?.userId
                ) {
                    identities.append(identity)
                }
            }
        }

        return SharedAvatarPalette.colorMap(for: identities)
    }

    /// Email allowed to edit shared store website overrides (writes to `store_websites`,
    /// which applies for every user). Restricted to the app owner.
    private static let adminEmail = "kor3a5@gmail.com"

    /// Whether the current user may set/edit shared store website overrides.
    private var isStoreAdmin: Bool {
        UserSessionManager.shared.currentUser?.email.lowercased() == Self.adminEmail
    }

    private var smartCategoryKey: String {
        "smartCategoryEnabled_\(userStoreItem.id)"
    }

    private var smartCategorySubtitle: String {
        guard isSubscribed else { return "Available for subscribers" }
        return viewModel.isCategorizingBacklog
            ? "Categorizing your list…"
            : "AI auto-categorizes new items"
    }

    /// Whether the auto-delete swipe rail is mounted. Rows only report checkbox
    /// frames while it is, since nothing else reads them.
    private var isSwipeRailActive: Bool {
        autoDeleteEnabled && userStoreItem.permission != .view
    }

    var body: some View {
        coreView
            .sheet(isPresented: $showSettingsSheet, onDismiss: runPendingSettingsAction) {
                settingsSheet
            }
            .sheet(item: $reminderToShare) { reminder in
                ShareReminderView(reminder: reminder, store: userStoreItem.store)
            }
            .sheet(isPresented: $showingRecipePicker) {
                RecipePickerView(
                    userStoreItem: userStoreItem,
                    useSmartCategory: effectiveSmartCategoryEnabled
                )
            }
            .sheet(isPresented: $showingHistory) {
                HistoryView(
                    userStoreItem: userStoreItem,
                    currentReminderTitles: Set(viewModel.displayedReminders.map {
                        $0.title.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                    })
                )
            }
            .sheet(isPresented: $showingAnalytics) {
                StoreAnalyticsView(userStoreItem: userStoreItem)
            }
            .sheet(isPresented: $showingBackgroundPicker) {
                // Keyed to this store's user_store document, so each store's
                // list keeps its own look.
                BackgroundPickerView(
                    surface: .reminders(storeId: userStoreItem.id),
                    title: userStoreItem.store.name,
                    // Lets the picker offer this look to every other store's
                    // list; this store is filtered out on the other side.
                    storeIds: [userStoreItem.id] + availableStores.map(\.id),
                    systemDefault: OrganicPalette.canvas(colorScheme)
                )
            }
            .sheet(item: $reminderForPhoto) { reminder in
                ImagePicker(selectedImage: $selectedImage) { image in
                    viewModel.uploadPhoto(for: reminder, image: image)
                }
            }
            .organicAlert(
                "Delete Shared Reminder",
                isPresented: .init(
                    get: { reminderToDelete != nil },
                    set: { if !$0 { reminderToDelete = nil } }
                ),
                icon: "trash.fill",
                tone: .destructive,
                message: deleteSharedReminderMessage,
                actions: [
                    .destructive("Delete for Everyone") {
                        if let reminder = reminderToDelete {
                            stageReminderForDeletion(reminder)
                            reminderToDelete = nil
                        }
                    },
                    .cancel { reminderToDelete = nil }
                ]
            )
            .organicAlert(
                "Duplicate Reminder",
                isPresented: $showDuplicateAlert,
                icon: "exclamationmark.circle.fill",
                message: "'\(duplicateTitle)' already exists in this store.",
                actions: [.ok { newReminderText = "" }]
            )
            .organicAlert(
                "Add Quantity",
                isPresented: .init(
                    get: { reminderForQuantity != nil },
                    set: { if !$0 { reminderForQuantity = nil } }
                ),
                icon: "number",
                message: "Enter quantity for this reminder item.",
                actions: [
                    .primary("Save") {
                        if let reminder = reminderForQuantity {
                            let qty = Int(quantityText)
                            viewModel.updateReminderQuantity(reminder, newQuantity: qty)
                        }
                        reminderForQuantity = nil
                        quantityText = ""
                    },
                    .destructive("Remove") {
                        if let reminder = reminderForQuantity {
                            viewModel.updateReminderQuantity(reminder, newQuantity: nil)
                        }
                        reminderForQuantity = nil
                        quantityText = ""
                    },
                    .cancel {
                        reminderForQuantity = nil
                        quantityText = ""
                    }
                ]
            ) {
                OrganicAlertTextField(placeholder: "Quantity", text: $quantityText)
                    .keyboardType(.numberPad)
            }
            .organicAlert(
                "Set Category",
                isPresented: .init(
                    get: { reminderForCategory != nil },
                    set: { if !$0 { reminderForCategory = nil } }
                ),
                icon: "tag.fill",
                message: "Enter a custom category for this item.",
                actions: [
                    .primary("Save") {
                        if let reminder = reminderForCategory {
                            let cat = customCategoryText.trimmingCharacters(in: .whitespaces)
                            viewModel.updateReminderCategory(reminder, newCategory: cat.isEmpty ? nil : cat)
                        }
                        reminderForCategory = nil
                        customCategoryText = ""
                    },
                    .destructive("Remove Category") {
                        if let reminder = reminderForCategory {
                            viewModel.updateReminderCategory(reminder, newCategory: nil)
                        }
                        reminderForCategory = nil
                        customCategoryText = ""
                    },
                    .cancel {
                        reminderForCategory = nil
                        customCategoryText = ""
                    }
                ]
            ) {
                OrganicAlertTextField(placeholder: "Category name", text: $customCategoryText)
                    .textInputAutocapitalization(.words)
            }
            .organicAlert(
                "Store Website",
                isPresented: $showingEditWebsite,
                icon: "globe",
                message: "Set the website for \(userStoreItem.store.name). This applies for everyone who has this store, and the app opens it in the store's app when installed.",
                actions: [
                    .primary("Save") {
                        let trimmed = websiteInputText.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty {
                            StoreLogoProvider.shared.setStoreWebsite(
                                storeName: userStoreItem.store.name,
                                websiteURL: trimmed
                            )
                        }
                        websiteInputText = ""
                    },
                    .cancel { websiteInputText = "" }
                ]
            ) {
                OrganicAlertTextField(placeholder: "https://example.com", text: $websiteInputText)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
            }
    }

    private var coreView: some View {
        ZStack {
            // The user's chosen background for this store, falling back to the
            // paper canvas. It sits here rather than on the list so the empty
            // and loading states stand on the same ground.
            SurfaceBackground(
                surface: .reminders(storeId: userStoreItem.id),
                systemDefault: OrganicPalette.canvas(colorScheme)
            )

            if viewModel.isLoading {
                ProgressView("Loading reminders...")
                    .tint(OrganicPalette.terracotta(colorScheme))
                    .foregroundColor(OrganicPalette.inkSoft(colorScheme))
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
            if isSwipeRailActive {
                AutoDeleteSwipeRail(
                    captureWidth: 40,
                    isEnabled: autoDeleteEnabled,
                    onDragChanged: { location in
                        for (id, frame) in checkboxFrames.frames {
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

            // Membership barcode — slides down from the top of the screen.
            if showBarcodePanel {
                Color.black.opacity(0.18)
                    .contentShape(Rectangle())
                    .onTapGesture { dismissBarcodePanel() }
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .zIndex(19)
            }

            // The top-aligned container stays mounted so the panel's own
            // move transition travels its own height (sliding out from behind
            // the navigation bar) rather than a full screen height.
            VStack(spacing: 0) {
                if showBarcodePanel {
                    MembershipBarcodeTopSheet(
                        storeName: userStoreItem.store.name,
                        onDismiss: dismissBarcodePanel
                    )
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
                Spacer(minLength: 0)
            }
            .allowsHitTesting(showBarcodePanel)
            .zIndex(20)

            // Sticky banner ad above tab bar (hidden for subscribers)
            if !isSubscribed {
                VStack(spacing: 0) {
                    Spacer()
                    BannerAdView(adUnitID: kBannerAdUnitID)
                        .frame(height: 50)
                        .background(OrganicPalette.canvas(colorScheme))
                }
            }
        }
        // The drop target for press-and-drag reordering sits on this container
        // rather than on the List: a List swallows the drag before its rows see
        // it, and the whole screen being a target means a drop just short of a
        // row still lands. Drop locations arrive in this container's own
        // coordinates, so its origin is recorded to convert them to the global
        // frames the rows report.
        .background(
            GeometryReader { geo in
                Color.clear
                    .onAppear { dragTargets.containerOrigin = geo.frame(in: .global).origin }
                    .onChange(of: geo.frame(in: .global)) { _, frame in
                        dragTargets.containerOrigin = frame.origin
                    }
            }
        )
        .onDrop(
            of: [UTType.plainText, UTType.utf8PlainText, UTType.text],
            delegate: ReminderListDropDelegate(
                viewModel: viewModel,
                targets: dragTargets,
                draggedCategory: $draggedCategory,
                draggedReminderId: $draggedReminderId
            )
        )
        // The watchdog cancels a drag that never reached a drop target (dropped
        // outside the app, interrupted by a call); clear the view's own drag
        // state with it so rows don't stay dimmed.
        .onChange(of: viewModel.isDragging) { _, isDragging in
            guard !isDragging else { return }
            draggedCategory = nil
            draggedReminderId = nil
            dragTargets.reset()
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(OrganicPalette.canvas(colorScheme), for: .navigationBar)
        .tint(OrganicPalette.terracotta(colorScheme))
        .toolbar { toolbarContent }
        .onAppear {
            viewModel.fetchReminders(for: userStoreItem.reminderStoreId, sharedFromName: userStoreItem.sharedFromName)
            viewModel.fetchFavoriteTags(for: userStoreItem.reminderStoreId)
            smartCategoryEnabled = UserDefaults.standard.object(forKey: smartCategoryKey) as? Bool ?? true
            // No-op unless the app launched before the device was first
            // unlocked, when the membership cards kept in the keychain
            // couldn't be read yet.
            membershipCardStore.reloadIfBackupWasUnavailable()
            // Reminders usually arrive after this (the fetch above is a live
            // listener), in which case the reminders.count change below is what
            // actually starts the pass.
            runCategoryBackfillIfNeeded()
        }
        .onChange(of: viewModel.reminders.count) { _, _ in
            runCategoryBackfillIfNeeded()
        }
        .onChange(of: viewModel.isCategorizingBacklog) { wasRunning, isRunning in
            // A pass that failed (offline, AI error) puts its items back in the
            // queue. Re-arm so the next list change or visit retries them; items
            // that succeeded are categorized now and won't be sent again.
            if wasRunning && !isRunning {
                hasRequestedCategoryBackfill = false
            }
        }
        .onChange(of: isSubscribed) { _, subscribed in
            // Access just turned on (purchase, restore, or status refresh) —
            // categorize whatever the user built up without a subscription.
            if subscribed {
                hasRequestedCategoryBackfill = false
                runCategoryBackfillIfNeeded()
            }
        }
        .onChange(of: smartCategoryEnabled) { oldValue, newValue in
            UserDefaults.standard.set(newValue, forKey: smartCategoryKey)
            if !oldValue && newValue {
                hasRequestedCategoryBackfill = false
                runCategoryBackfillIfNeeded()
            }
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
            let shared = effectiveSharedWith
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
                        sharedWith: effectiveSharedWith,
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
        let canAdd = userStoreItem.permission != .view
        var addItem: (() -> Void)?
        if canAdd {
            addItem = { isAddingNewReminder = true }
        }

        return OrganicEmptyState(
            systemImage: "checklist",
            title: "Nothing on the list",
            message: "Add what you need at \(userStoreItem.store.name) and it will be waiting for you when you get there.",
            actionTitle: canAdd ? "Add an item" : nil,
            action: addItem,
            footnote: canAdd ? nil : "You have view-only access to this list."
        )
    }

    private var reminderListView: some View {
        // Resolved once per list rebuild and handed to every row. Both maps scan
        // all reminders (and avatarColorMap runs the palette solver), so reading
        // them inside reminderRow made building the list O(n²) in the number of
        // reminders.
        let avatarColors = avatarColorMap
        let memberNames = storeMemberNames
        // Same reason: this scans every displayed reminder and was evaluated
        // once per section header.
        let showsCategoryHeaders = viewModel.hasDisplayedCategorizedReminders

        return ScrollViewReader { proxy in
            List {
                // Favorite tags section
                if !viewModel.favoriteTags.isEmpty {
                    favoriteTagsSection
                        .organicRow()
                }

                if !isReorderMode {
                    // Always render the sectioned structure so that the List's
                    // direct children don't change shape when the first AI
                    // categorization arrives mid-typing — otherwise the List
                    // reconciles and the focused TextField in inlineAddSection
                    // gets torn down, dropping the keyboard.
                    ForEach(viewModel.displayedCategoryOrder, id: \.self) { category in
                        Section {
                            // The title is a row rather than a section header: a
                            // `.plain` list pins its headers and draws its own
                            // backing behind them, which puts a grey bar across
                            // the paper canvas as soon as the list scrolls.
                            if showsCategoryHeaders {
                                categoryHeader(for: category)
                                    .organicSectionLabelRow()
                            }

                            if !collapsedCategories.contains(category) {
                                ForEach(viewModel.displayedReminders(for: category)) { reminder in
                                    reminderRow(
                                        for: reminder,
                                        avatarColors: avatarColors,
                                        memberNames: memberNames
                                    )
                                }
                            }
                        }
                    }
                } else {
                    // Reorder mode requires a flat ForEach for .onMove to work.
                    ForEach(viewModel.displayedReminders) { reminder in
                        reminderRow(
                            for: reminder,
                            avatarColors: avatarColors,
                            memberNames: memberNames
                        )
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
            .listSectionSpacing(10)
            .scrollContentBackground(.hidden)
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: 50)
            }
            .environment(\.editMode, editMode)
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

    /// Press-and-drag reordering is for members who can edit, and only outside
    /// the explicit reorder mode (which has its own flat list and drag handles).
    private var canDragReorder: Bool {
        userStoreItem.permission != .view && !isReorderMode
    }

    private var isDragActive: Bool {
        draggedCategory != nil || draggedReminderId != nil
    }

    /// The payload isn't read on drop — what's in flight is tracked in view
    /// state — but the drag needs *something* registered under a type the list's
    /// drop target accepts, so it's registered explicitly rather than left to
    /// conformance matching.
    private func dragItemProvider(_ value: String) -> NSItemProvider {
        NSItemProvider(item: value as NSString, typeIdentifier: UTType.plainText.identifier)
    }

    private func startDrag(category: String?, reminderId: String?) {
        dragTargets.reset()
        draggedCategory = category
        draggedReminderId = reminderId
        viewModel.beginDrag()
    }

    /// Records where a header or row sits so the drop delegate can work out what
    /// the finger is over. Global coordinates, like the swipe rail's checkbox
    /// frames — a named space declared outside the List doesn't reliably resolve
    /// from inside its cells.
    ///
    /// Installed only while a drag is in flight: `geo.frame` recomputes on every
    /// displayed frame while the list scrolls, and this list already learned
    /// that lesson with the swipe rail.
    @ViewBuilder
    private func dragTargetFrameReader(_ key: DragTargetKey) -> some View {
        if isDragActive {
            GeometryReader { geo in
                Color.clear
                    .onAppear {
                        dragTargets.frames[key] = geo.frame(in: .global)
                    }
                    .onChange(of: geo.frame(in: .global)) { _, frame in
                        dragTargets.frames[key] = frame
                    }
                    .onDisappear {
                        dragTargets.frames.removeValue(forKey: key)
                    }
            }
        }
    }

    /// Rows are dimmed while they're being dragged — either the row itself, or
    /// every row of a category whose header is in flight, so it reads as the
    /// whole section moving.
    private func isInFlight(_ reminder: Reminder) -> Bool {
        if draggedReminderId == reminder.id { return true }
        guard let draggedCategory = draggedCategory else { return false }
        return draggedCategory == viewModel.categoryName(for: reminder)
    }

    @ViewBuilder
    private func categoryHeader(for category: String) -> some View {
        let header = categoryHeaderLabel(for: category)

        if canDragReorder {
            header
                .opacity(draggedCategory == category ? 0.4 : 1)
                .background(dragTargetFrameReader(.header(category)))
                .onDrag {
                    startDrag(category: category, reminderId: nil)
                    return dragItemProvider(category)
                }
        } else {
            header
        }
    }

    private func categoryHeaderLabel(for category: String) -> some View {
        Button {
            withAnimation {
                if collapsedCategories.contains(category) {
                    collapsedCategories.remove(category)
                } else {
                    collapsedCategories.insert(category)
                }
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: categoryIcon(for: category))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(OrganicPalette.terracotta(colorScheme))
                    .frame(width: 20)

                Text(category)
                    .font(OrganicPalette.display(20))
                    .foregroundColor(OrganicPalette.ink(colorScheme))

                OrganicCountBadge(
                    count: viewModel.displayedReminders(for: category).count,
                    fontSize: 12
                )

                Spacer()

                Image(systemName: collapsedCategories.contains(category) ? "chevron.right" : "chevron.down")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(OrganicPalette.inkSoft(colorScheme))
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func categoryIcon(for category: String) -> String {
        CategoryIcon.symbol(for: category)
    }

    @ViewBuilder
    private func reminderRow(
        for reminder: Reminder,
        avatarColors: [String: Color],
        memberNames: [String: String]
    ) -> some View {
        let row = reminderRowContent(
            for: reminder,
            avatarColors: avatarColors,
            memberNames: memberNames
        )

        if canDragReorder {
            row
                .opacity(isInFlight(reminder) ? 0.4 : 1)
                .background(dragTargetFrameReader(.row(reminder.id)))
                .onDrag {
                    startDrag(category: nil, reminderId: reminder.id)
                    return dragItemProvider(reminder.id)
                }
        } else {
            row
        }
    }

    private func reminderRowContent(
        for reminder: Reminder,
        avatarColors: [String: Color],
        memberNames: [String: String]
    ) -> some View {
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
            // Only track frames while the swipe rail is actually mounted —
            // otherwise every visible row would recompute its global frame on
            // each scroll frame for a feature that isn't running.
            onCheckboxFrameChanged: isSwipeRailActive ? { frame in
                checkboxFrames.frames[reminder.id] = frame
            } : nil,
            onDragChanged: nil,
            onDragEnded: nil,
            autoDeleteEnabled: autoDeleteEnabled,
            avatarColorMap: avatarColors,
            memberNames: memberNames
        )
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(OrganicCardBackground(colorScheme: colorScheme, cornerRadius: 20))
        .contentShape(Rectangle())
        .organicRow()
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
            .tint(OrganicPalette.terracotta(colorScheme))
        }
    }

    // MARK: - Favorite Tags

    private var favoriteTagsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Favorites")
                .font(.system(size: 11, weight: .bold))
                .kerning(0.8)
                .foregroundColor(OrganicPalette.inkSoft(colorScheme))
                .textCase(.uppercase)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(viewModel.favoriteTags) { tag in
                        let alreadyExists = viewModel.isDuplicateReminder(title: tag.title)
                        FavoriteTagView(title: tag.title, isActive: !alreadyExists)
                            .onTapGesture {
                                viewModel.addReminderFromFavorite(
                                    tag: tag,
                                    sharedWith: effectiveSharedWith,
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
        .organicAlert(
            "Remove All Favorites",
            isPresented: $showRemoveAllFavoritesConfirmation,
            icon: "star.slash.fill",
            tone: .destructive,
            message: "This will remove all \(viewModel.favoriteTags.count) favorite\(viewModel.favoriteTags.count == 1 ? "" : "s"). This cannot be undone.",
            actions: [
                .destructive("Remove All") { viewModel.removeAllFavoriteTags() },
                .cancel()
            ]
        )
    }

    @ViewBuilder
    private var inlineAddSection: some View {
        if isAddingNewReminder {
            HStack {
                Image(systemName: "square")
                    .font(.system(size: 24))
                    .foregroundColor(OrganicPalette.inkSoft(colorScheme).opacity(0.5))
                    // Match the checkbox footprint in ReminderItemView so the
                    // text field lines up with the reminder titles below it.
                    .frame(width: 32, height: 32)
                TextField(
                    "",
                    text: $newReminderText,
                    prompt: Text("What do you need?")
                        .foregroundColor(OrganicPalette.inkSoft(colorScheme).opacity(0.8))
                )
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(OrganicPalette.ink(colorScheme))
                .focused($isNewReminderFocused)
                .onSubmit {
                    submitNewReminder()
                }
                .textInputAutocapitalization(.sentences)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(OrganicCardBackground(colorScheme: colorScheme, cornerRadius: 20))
            .organicRow()
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
                HStack(spacing: 10) {
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(OrganicPalette.terracotta(colorScheme))
                    Text("Add item")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(OrganicPalette.terracotta(colorScheme))
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                // Outlined rather than filled: this is the one row that isn't an
                // item yet, so it stays a hollow slot at the end of the list.
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(
                            OrganicPalette.terracotta(colorScheme).opacity(0.35),
                            style: StrokeStyle(lineWidth: 1.5, dash: [6, 5])
                        )
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .organicRow()
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
            .organicAlert(
                "Delete Photo",
                isPresented: $showDeletePhotoConfirm,
                icon: "trash.fill",
                tone: .destructive,
                message: "Are you sure you want to delete this photo?",
                actions: [
                    .destructive("Delete") {
                        if let reminder = enlargedPhotoReminder, let url = enlargedPhotoURL {
                            withAnimation { enlargedPhotoURL = nil }
                            enlargedPhotoReminder = nil
                            stagePhotoForDeletion(reminder: reminder, url: url)
                        }
                    },
                    .cancel()
                ]
            )
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
                .tint(
                    autoDeleteEnabled
                        ? OrganicPalette.rust(colorScheme)
                        : OrganicPalette.inkSoft(colorScheme)
                )
            }
        }

        // The store name in the screen's own display face, with the number of
        // still-unchecked reminders under it — the list itself no longer
        // carries a count anywhere else.
        ToolbarItem(placement: .principal) {
            VStack(spacing: 1) {
                Text(userStoreItem.store.name)
                    .font(OrganicPalette.title(17))
                    .foregroundColor(OrganicPalette.ink(colorScheme))
                    .lineLimit(1)

                if !viewModel.displayedReminders.isEmpty {
                    Text(remainingCountSubtitle)
                        .font(.system(size: 12))
                        .foregroundColor(OrganicPalette.inkSoft(colorScheme))
                }
            }
        }

        ToolbarItem(placement: .navigationBarTrailing) {
            if isReorderMode {
                Button("Done") {
                    withAnimation {
                        isReorderMode = false
                    }
                }
                .font(OrganicPalette.title(16))
                .foregroundColor(OrganicPalette.terracotta(colorScheme))
            } else if userStoreItem.permission == .view {
                Image(systemName: "eye.fill")
                    .foregroundColor(OrganicPalette.inkSoft(colorScheme))
                    .frame(width: 22, height: 22)
            }
        }

        // Membership barcode
        ToolbarItem(placement: .navigationBarTrailing) {
            if !isReorderMode {
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        showBarcodePanel.toggle()
                    }
                } label: {
                    Image(systemName: hasMembershipCard ? "barcode.viewfinder" : "barcode")
                        .foregroundColor(OrganicPalette.terracotta(colorScheme))
                        .frame(width: 22, height: 22)
                }
                .frame(width: 44, height: 44)
                .accessibilityLabel("Membership barcode")
            }
        }

        // Break the shared Liquid Glass capsule so the barcode button renders in
        // its own circle, separate from the settings button.
        if #available(iOS 26.0, *) {
            ToolbarSpacer(.fixed, placement: .navigationBarTrailing)
        }

        ToolbarItem(placement: .navigationBarTrailing) {
            if !isReorderMode {
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        showBarcodePanel = false
                    }
                    showSettingsSheet = true
                } label: {
                    Image(systemName: "gearshape")
                        .foregroundColor(OrganicPalette.terracotta(colorScheme))
                        .frame(width: 22, height: 22)
                }
                .frame(width: 44, height: 44)
                .accessibilityLabel("Settings")
            }
        }
    }

    /// "4 reminders remaining", counting only the unchecked ones, or
    /// "All done" once everything on the list is checked off.
    private var remainingCountSubtitle: String {
        let remaining = viewModel.displayedReminders.filter { !$0.isDone }.count
        guard remaining > 0 else { return "All done" }
        return "\(remaining) reminder\(remaining == 1 ? "" : "s") remaining"
    }

    /// Whether a membership card is saved for this store, used to fill in the
    /// toolbar barcode icon.
    private var hasMembershipCard: Bool {
        membershipCardStore.card(forStoreNamed: userStoreItem.store.name) != nil
    }

    private func dismissBarcodePanel() {
        withAnimation(.easeInOut(duration: 0.25)) {
            showBarcodePanel = false
        }
    }

    private var deleteSharedReminderMessage: String? {
        guard let reminder = reminderToDelete else { return nil }

        if let sharedWith = reminder.sharedWith, !sharedWith.isEmpty {
            return "This reminder is shared with \(sharedWith.joined(separator: ", ")). Deleting it will remove it for everyone."
        } else if let sharedFrom = reminder.sharedFrom {
            return "This reminder was shared by \(sharedFrom). Deleting it will remove it for everyone."
        } else {
            return "This reminder is shared. Deleting it will remove it for everyone."
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
                sharedWith: effectiveSharedWith,
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

            // Auto-delete skips the Firestore isDone toggle, so stamp the
            // check-off on the local copy — deleteReminder uses it to record
            // the reminder_history entry with the right attribution.
            var checkedOff = reminder
            checkedOff.isDone = true
            checkedOff.checkedOffAt = Date().timeIntervalSince1970
            checkedOff.checkedOffBy = UserSessionManager.shared.currentUser?.name
            checkedOff.checkedOffById = UserSessionManager.shared.currentUser?.userId

            // After fade animation, stage the deletion (undo still possible)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                fadingReminderIds.remove(reminder.id)
                stageReminderForDeletion(checkedOff)
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
        // The toast is inverted paper — ink where the screen is canvas — so its
        // accent has to come from the opposite appearance to stay legible.
        let inverted: ColorScheme = colorScheme == .dark ? .light : .dark
        return VStack {
            Spacer()
            HStack(spacing: 12) {
                Image(systemName: "trash.fill")
                    .font(.system(size: 14))
                    .foregroundColor(OrganicPalette.canvas(colorScheme).opacity(0.7))

                Text(message)
                    .font(.system(size: 15))
                    .foregroundColor(OrganicPalette.canvas(colorScheme))
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer()

                Button {
                    onUndo()
                } label: {
                    Text("Undo")
                        .font(OrganicPalette.title(15))
                        .foregroundColor(OrganicPalette.terracotta(inverted))
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            // Inverted paper: ink for the fill, canvas for the type, so the
            // toast reads as part of the same palette rather than a grey slab.
            .background(
                Capsule()
                    .fill(OrganicPalette.ink(colorScheme))
                    .shadow(color: OrganicPalette.shadow(colorScheme), radius: 12, x: 0, y: 4)
            )
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .allowsHitTesting(true)
    }

    // MARK: - Settings Sheet

    /// Runs whatever a settings row asked for once the sheet is off screen.
    private func runPendingSettingsAction() {
        guard let action = pendingSettingsAction else { return }
        pendingSettingsAction = nil
        action()
    }

    /// Everything that used to sit behind the toolbar's info button, pulled up
    /// from the bottom instead: the same rows, in the same order, on a sheet
    /// that starts half-height and can be dragged to full.
    private var settingsSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Auto Delete row
                    settingsRow(
                        icon: autoDeleteEnabled ? "trash.fill" : "trash",
                        iconTint: autoDeleteEnabled ? OrganicPalette.rust(colorScheme) : nil,
                        title: "Auto Delete",
                        subtitle: "Delete checked items automatically",
                        accessory: userStoreItem.permission == .view
                            ? .readOnlyToggle($autoDeleteEnabled)
                            : .toggle($autoDeleteEnabled),
                        showsDivider: false
                    )

                    // Smart Category row
                    settingsRow(
                        icon: "sparkles",
                        title: "Smart Category",
                        subtitle: smartCategorySubtitle,
                        isDimmed: !isSubscribed,
                        accessory: isSubscribed ? .toggle($smartCategoryEnabled) : .locked
                    )

                    if userStoreItem.permission != .view {
                        // Recipes row
                        settingsRow(
                            icon: "fork.knife",
                            title: "Recipes",
                            subtitle: "Add ingredients from a saved recipe",
                            accessory: .chevron
                        ) {
                            showingRecipePicker = true
                        }
                    }

                    settingsSecondaryRows
                }
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(OrganicPalette.surface(colorScheme))
                )
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .background(OrganicPalette.canvas(colorScheme))
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(OrganicPalette.canvas(colorScheme), for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showSettingsSheet = false
                    }
                    .font(OrganicPalette.title(16))
                    .foregroundColor(OrganicPalette.terracotta(colorScheme))
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    /// The lower half of the settings sheet.
    ///
    /// Split out of `settingsSheet` purely for the ViewBuilder child
    /// limit — the rows had outgrown the ten a single stack allows.
    private var settingsSecondaryRows: some View {
        Group {
            // History row — checked-off items no longer in the list
            settingsRow(
                icon: "clock.arrow.circlepath",
                title: "History",
                subtitle: "Checked-off items no longer in the list",
                accessory: .chevron
            ) {
                showingHistory = true
            }

            // Analytics row — premium shopping insights for this store.
            // The view itself shows an upgrade pitch for free users.
            settingsRow(
                icon: "chart.bar.xaxis",
                title: "Analytics",
                subtitle: isSubscribed ? "Shopping trends and item insights" : "Available for subscribers",
                isDimmed: !isSubscribed,
                accessory: isSubscribed ? .chevron : .locked
            ) {
                showingAnalytics = true
            }

            // Background row — colors are free, so this is never locked. The
            // picker itself pitches the upgrade for photos.
            settingsRow(
                icon: "photo.on.rectangle.angled",
                title: "Change Background",
                subtitle: isSubscribed ? "A photo or color just for this store" : "A color just for this store",
                accessory: .chevron
            ) {
                showingBackgroundPicker = true
            }

            // Store app / website row. The URL is derived from the store name
            // (no per-store data to maintain); iOS opens the store's app via
            // universal links when installed, otherwise falls back to Safari.
            if let storeURL = storeWebsiteURL {
                settingsRow(
                    icon: "safari",
                    title: "Visit store",
                    subtitle: "Open the store's app or website",
                    accessory: .arrow
                ) {
                    openURL(storeURL)
                }
            }

            // Set / edit store website (admin only). Writes a shared override to
            // the store_websites collection so it applies for everyone with this
            // store, so it is restricted to the app owner's account.
            if isStoreAdmin {
                settingsRow(
                    icon: "link",
                    title: storeWebsiteURL == nil ? "Set store website" : "Edit store website",
                    subtitle: "Add a link to this store's website or app",
                    accessory: .chevron
                ) {
                    websiteInputText = storeWebsiteURL?.absoluteString ?? ""
                    showingEditWebsite = true
                }
            }
        }
    }

    /// One row of the settings sheet: a terracotta glyph on blush, a title, the
    /// line of explanation under it, and whatever the row does on the right.
    ///
    /// `action` runs only once the sheet has finished dismissing — every row
    /// that has one either pushes another sheet, which iOS drops while this one
    /// is still up, or leaves the app.
    @ViewBuilder
    private func settingsRow(
        icon: String,
        iconTint: Color? = nil,
        title: String,
        subtitle: String,
        isDimmed: Bool = false,
        accessory: SettingsRowAccessory,
        showsDivider: Bool = true,
        action: (() -> Void)? = nil
    ) -> some View {
        VStack(spacing: 0) {
            if showsDivider {
                Rectangle()
                    .fill(OrganicPalette.outline(colorScheme).opacity(0.5))
                    .frame(height: 1)
                    .padding(.horizontal, 16)
            }

            let content = HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(iconTint ?? OrganicPalette.terracotta(colorScheme))
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(OrganicPalette.blush(colorScheme)))
                    .opacity(isDimmed ? 0.5 : 1)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(OrganicPalette.ink(colorScheme).opacity(isDimmed ? 0.5 : 1))
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(OrganicPalette.inkSoft(colorScheme))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                settingsRowAccessory(accessory)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            if let action {
                Button {
                    pendingSettingsAction = action
                    showSettingsSheet = false
                } label: {
                    content.contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            } else {
                content
            }
        }
    }

    @ViewBuilder
    private func settingsRowAccessory(_ accessory: SettingsRowAccessory) -> some View {
        switch accessory {
        case .toggle(let isOn):
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(OrganicPalette.terracotta(colorScheme))
        case .readOnlyToggle(let isOn):
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(OrganicPalette.terracotta(colorScheme))
                .disabled(true)
        case .chevron:
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(OrganicPalette.inkSoft(colorScheme).opacity(0.7))
        case .arrow:
            Image(systemName: "arrow.up.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(OrganicPalette.inkSoft(colorScheme).opacity(0.7))
        case .locked:
            Image(systemName: "lock.fill")
                .font(.system(size: 13))
                .foregroundColor(OrganicPalette.inkSoft(colorScheme))
        }
    }

    /// The store's website URL, derived from its name via the shared domain map.
    /// Returns `nil` when no domain is known, in which case the link row is hidden.
    private var storeWebsiteURL: URL? {
        guard let urlString = StoreLogoProvider.shared.websiteURL(for: userStoreItem.store.name) else {
            return nil
        }
        return URL(string: urlString)
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

// MARK: - Info Panel Accessory

/// What sits at the trailing edge of an info-panel row.
enum SettingsRowAccessory {
    case toggle(Binding<Bool>)
    /// A toggle the user can see the state of but not change — a list they
    /// only have view access to.
    case readOnlyToggle(Binding<Bool>)
    case chevron
    case arrow
    /// A subscriber-only row, which shows what it would do and why it can't.
    case locked
}

// MARK: - Favorite Tag View

struct FavoriteTagView: View {
    let title: String
    /// False once the item is already on the list, when tapping the tag would
    /// do nothing.
    var isActive: Bool = true

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Text(title)
            .font(.system(size: 13, weight: .semibold))
            .lineLimit(1)
            .foregroundColor(
                isActive ? .white : OrganicPalette.inkSoft(colorScheme)
            )
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule().fill(
                    isActive
                        ? OrganicPalette.terracotta(colorScheme)
                        : OrganicPalette.field(colorScheme)
                )
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

// MARK: - Drag Reordering Drop Target

/// Identifies something a dragged row or category can be dropped onto.
enum DragTargetKey: Hashable {
    case header(String)
    case row(String)
}

/// Where each drop target sits inside the list while a drag is in flight.
///
/// A reference type for the same reason as `CheckboxFrameStore`: every visible
/// row rewrites its frame on each displayed frame, and these are only ever read
/// inside the drop delegate, never during rendering, so they must not invalidate
/// the body.
final class DragTargetFrameStore {
    var frames: [DragTargetKey: CGRect] = [:]
    /// Global origin of the view carrying the drop target, so the local drop
    /// locations it reports can be compared against the global row frames.
    var containerOrigin: CGPoint = .zero
    /// The target the last move acted on. A finger held still keeps delivering
    /// drop callbacks, and re-running the same move would swap the row back and
    /// forth under it.
    var lastHandled: DragTargetKey?

    func target(at point: CGPoint) -> (key: DragTargetKey, belowMidpoint: Bool)? {
        for (key, frame) in frames where frame.contains(point) {
            return (key, point.y > frame.midY)
        }
        return nil
    }

    /// Clears per-drag state. `containerOrigin` survives: it describes the
    /// screen, not the drag.
    func reset() {
        frames.removeAll()
        lastHandled = nil
    }
}

/// The screen's single drop target.
///
/// Drop targets on the individual rows never saw the drag — the List accepts it
/// first — so hit-testing happens here instead: rows and headers record their
/// global frames while a drag is in flight, and the drag location picks out
/// whichever one is under the finger.
struct ReminderListDropDelegate: DropDelegate {
    let viewModel: ReminderViewModel
    let targets: DragTargetFrameStore
    @Binding var draggedCategory: String?
    @Binding var draggedReminderId: String?

    /// Only ever accept a drag this list started — not text dropped in from
    /// another app.
    func validateDrop(info: DropInfo) -> Bool {
        draggedCategory != nil || draggedReminderId != nil
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        applyMove(at: info.location)
        return DropProposal(operation: .move)
    }

    func dropExited(info: DropInfo) {
        targets.lastHandled = nil
    }

    func performDrop(info: DropInfo) -> Bool {
        applyMove(at: info.location)
        viewModel.commitDrag()
        targets.reset()
        draggedCategory = nil
        draggedReminderId = nil
        return true
    }

    private func applyMove(at location: CGPoint) {
        let point = CGPoint(
            x: location.x + targets.containerOrigin.x,
            y: location.y + targets.containerOrigin.y
        )
        guard let hit = targets.target(at: point), hit.key != targets.lastHandled else { return }
        targets.lastHandled = hit.key

        withAnimation(.easeInOut(duration: 0.2)) {
            switch hit.key {
            case .header(let category):
                if let draggedCategory = draggedCategory {
                    viewModel.moveCategory(draggedCategory, before: category)
                } else if let draggedReminderId = draggedReminderId {
                    viewModel.moveReminder(id: draggedReminderId, toCategory: category)
                }
            case .row(let id):
                guard let target = viewModel.reminders.first(where: { $0.id == id }) else { return }
                if let draggedCategory = draggedCategory {
                    // Aiming anywhere in a section's body moves the dragged
                    // category to that section, so a tall section is as easy to
                    // hit as its header.
                    viewModel.moveCategory(draggedCategory, before: viewModel.categoryName(for: target))
                } else if let draggedReminderId = draggedReminderId {
                    viewModel.moveReminder(id: draggedReminderId, onto: target, placeAfter: hit.belowMidpoint)
                }
            }
        }
    }
}
