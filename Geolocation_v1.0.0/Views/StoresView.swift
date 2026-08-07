//
//  StoresView.swift
//  Geolocation_v1.0.0
//
//  Created by James Jeon on 10/18/24.
//

import SwiftUI

enum StoreViewMode: String {
    case list
    case float
}

struct StoresView: View {
    // MARK: - PROPERTIES

    @Binding var pendingStoreName: String?
    @StateObject private var viewModel = StoresViewModel()
    @StateObject private var messagesViewModel = MessagesViewModel()
    @StateObject private var smartRecipeViewModel = SmartRecipeViewModel()
    @ObservedObject private var sessionManager = UserSessionManager.shared
    @ObservedObject private var subscriptionManager = SubscriptionManager.shared
    @ObservedObject private var tutorialManager = TutorialManager.shared
    @State private var showingAddStore = false
    @State private var showingSmartRecipe = false
    @State private var showingRecipes = false
    @State private var showingPaywall = false
    @State private var isMenuExpanded = false
    @State private var selectedStoreToShare: UserStoreItem?
    @State private var editMode: EditMode = .inactive
    @State private var longPressedItemId: String?
    @State private var showOnMyWayConfirmation = false
    @State private var selectedOnMyWayStore: UserStoreItem?
    @State private var storeToDelete: UserStoreItem?
    @State private var notificationDestination: UserStoreItem? = nil
    @State private var pressedStoreId: String? = nil
    @AppStorage("storeViewMode") private var storeViewMode: StoreViewMode = .list
    @State private var isFloatEditMode: Bool = false
    @State private var isFabShrunk: Bool = false
    @State private var isAtScrollBottom: Bool = false
    @State private var fabInactivityTimer: Timer? = nil
    @State private var showingBackgroundPicker = false
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        NavigationStack {
            ZStack {
                // Background always visible — the user's chosen color for
                // subscribers, the default gradient otherwise.
                SurfaceBackground(surface: .stores)

                // Hidden navigation destination for notification taps
                Color.clear
                    .navigationDestination(item: $notificationDestination) { storeItem in
                        ReminderView(
                            userStoreItem: storeItem,
                            availableStores: viewModel.userStoreItems.filter { $0.id != storeItem.id }
                        )
                    }

                // Main content
                if sessionManager.isLoading || viewModel.isLoading {
                    ProgressView("Loading your stores...")
                } else if viewModel.userStoreItems.isEmpty {
                    emptyStateView
                } else {
                    if storeViewMode == .list {
                        listContent
                    } else {
                        StoreFloatView(
                            stores: viewModel.userStoreItems,
                            onStoreTap: { item in
                                notificationDestination = item
                            },
                            onStoreDelete: { item in
                                storeToDelete = item
                            },
                            onReorder: { newOrder in
                                viewModel.reorderStores(newOrder: newOrder)
                            },
                            isEditMode: $isFloatEditMode
                        )
                    }
                }

                // Transparent overlay to close FAB menu when tapped outside
                if isMenuExpanded {
                    Color.clear
                        .contentShape(Rectangle())
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                isMenuExpanded = false
                                if storeViewMode == .float {
                                    isFabShrunk = true
                                }
                            }
                        }
                }

                // Sticky banner ad at the bottom (list and float modes, hidden for subscribers)
                if !viewModel.userStoreItems.isEmpty && !subscriptionManager.isSubscribed {
                    bannerAdOverlay
                }

                // Floating action button (both list and float modes)
                fabOverlay
            }
            .toolbar {
                // Done button when reordering in list mode
                if editMode == .active && storeViewMode == .list {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Done") {
                            withAnimation {
                                editMode = .inactive
                            }
                        }
                    }
                }

                // Done button when in float edit mode
                if isFloatEditMode && storeViewMode == .float {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Done") {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                isFloatEditMode = false
                            }
                        }
                    }
                }

                // Sort + view mode toggle (shown when stores exist, or during tutorial to highlight the icons)
                if !viewModel.userStoreItems.isEmpty || tutorialManager.isActive {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        HStack(spacing: 4) {
                            // Sort by reminder count — one tap permanently reorders the stores
                            Button(action: {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    editMode = .inactive
                                    viewModel.sortByReminderCount()
                                }
                            }) {
                                Image(systemName: "arrow.up.arrow.down.circle")
                                    .imageScale(.large)
                            }

                            // List / float view toggle
                            Button(action: {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    if storeViewMode == .list {
                                        editMode = .inactive
                                        storeViewMode = .float
                                    } else {
                                        isFloatEditMode = false
                                        storeViewMode = .list
                                    }
                                }
                            }) {
                                Image(systemName: storeViewMode == .list ? "circle.grid.3x3" : "list.bullet")
                                    .imageScale(.large)
                            }
                        }
                        .tutorialHighlight(id: "tutorial_toolbar")
                    }
                }
            }
        }//:NAVIGATIONSTACK
        .sheet(isPresented: $showingAddStore) {
            AddStoreView(viewModel: viewModel)
        }
        .sheet(isPresented: $showingSmartRecipe) {
            SmartRecipeView(viewModel: smartRecipeViewModel, storesViewModel: viewModel)
        }
        .sheet(isPresented: $showingRecipes) {
            RecipeView()
        }
        .sheet(isPresented: $showingPaywall) {
            SubscriptionPaywallView()
        }
        .sheet(isPresented: $showingBackgroundPicker) {
            BackgroundPickerView(surface: .stores)
        }
        .sheet(item: $selectedStoreToShare) { storeToShare in
            ShareStoreView(viewModel: viewModel, messagesViewModel: messagesViewModel, userStoreItem: storeToShare)
        }
        .alert("On My Way", isPresented: $showOnMyWayConfirmation) {
            Button("Send") {
                if let store = selectedOnMyWayStore {
                    viewModel.sendOnMyWayNotification(for: store)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            if let store = selectedOnMyWayStore {
                Text("Notify people you share \(store.store.name) with that you're on your way?")
            }
        }
        .alert("Notification Sent", isPresented: Binding(
            get: { viewModel.onMyWaySentStoreName != nil },
            set: { if !$0 { viewModel.onMyWaySentStoreName = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            if let storeName = viewModel.onMyWaySentStoreName {
                Text("Your shared contacts have been notified that you're on your way to \(storeName).")
            }
        }
        .alert("Unable to Send", isPresented: Binding(
            get: { viewModel.onMyWayError != nil },
            set: { if !$0 { viewModel.onMyWayError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            if let error = viewModel.onMyWayError {
                Text(error)
            }
        }
        .alert(deleteAlertTitle, isPresented: Binding(
            get: { storeToDelete != nil },
            set: { if !$0 { storeToDelete = nil } }
        )) {
            Button(deleteAlertActionLabel, role: .destructive) {
                if let store = storeToDelete {
                    deleteStore(store)
                }
                storeToDelete = nil
            }
            Button("Cancel", role: .cancel) {
                storeToDelete = nil
            }
        } message: {
            if let store = storeToDelete {
                Text(deleteAlertMessage(for: store))
            }
        }
        .overlay {
            if viewModel.isSendingOnMyWay {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                ProgressView("Calculating travel time...")
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            }
        }
        .onAppear() {
            if sessionManager.currentUser != nil {
                self.viewModel.fetchUserStores()
            }
            if storeViewMode == .list {
                startFabInactivityTimer()
            }
            // Start tutorial for new users if user data is already available
            if let userId = sessionManager.currentUser?.userId {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    tutorialManager.startIfNeeded(userId: userId)
                }
            }
        }
        .onDisappear {
            fabInactivityTimer?.invalidate()
            fabInactivityTimer = nil
        }
        .onChange(of: storeViewMode) { _, mode in
            if mode == .list {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                    isFabShrunk = false
                    isMenuExpanded = false
                }
                startFabInactivityTimer()
            } else {
                fabInactivityTimer?.invalidate()
                withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                    isFabShrunk = false
                    isMenuExpanded = false
                }
            }
        }
        .onChange(of: sessionManager.currentUser) { oldValue, newValue in
            if let newValue = newValue {
                if viewModel.userStoreItems.isEmpty {
                    self.viewModel.fetchUserStores()
                }
                // Start tutorial when user data becomes available (backup trigger for new users)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    tutorialManager.startIfNeeded(userId: newValue.userId)
                }
            }
        }
        .onChange(of: pendingStoreName) { _, storeName in
            guard let storeName = storeName else { return }
            if let storeItem = viewModel.userStoreItems.first(where: { $0.store.name == storeName }) {
                notificationDestination = storeItem
                pendingStoreName = nil
            } else {
                viewModel.fetchUserStores()
            }
        }
        .onChange(of: viewModel.userStoreItems) { _, items in
            guard let storeName = pendingStoreName else { return }
            if let storeItem = items.first(where: { $0.store.name == storeName }) {
                notificationDestination = storeItem
                pendingStoreName = nil
            }
        }
    }//:BODY

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 24) {
                // Icon
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            colors: [Color.blue.opacity(0.15), Color.purple.opacity(0.15)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 120, height: 120)

                    Image(systemName: "cart.badge.plus")
                        .font(.system(size: 52, weight: .light))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }

                // Title & description
                VStack(spacing: 10) {
                    Text("No Stores Yet")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)

                    Text("Add your favorite grocery stores\nto start managing your shopping reminders.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)
                }

                // Step-by-step hint
                VStack(spacing: 12) {
                    EmptyStateStep(number: 1, text: "Tap the  +  button below")
                    EmptyStateStep(number: 2, text: "Choose \"Add Store\" and search nearby")
                    EmptyStateStep(number: 3, text: "Set reminders for items you need")
                }
                .padding(.horizontal, 32)
                .padding(.top, 4)
            }
            .padding(.horizontal, 24)

            Spacer()
            // Reserve space for the FAB so content stays visually centred
            Color.clear.frame(height: 100)
        }
    }

    // MARK: - Store Row Card

    /// The full rectangular store row — the store info on top of the glass
    /// card. Used as the Button label so the entire block (not just the text)
    /// participates in the press animation.
    @ViewBuilder
    private func storeRowCard(for userStoreItem: UserStoreItem) -> some View {
        StoreItemView(store: userStoreItem.store, isShared: userStoreItem.isShared)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    // In light mode the material takes on the light backdrop
                    // behind it, so a row ends up almost the same brightness as
                    // the background and the rows blur together. The shared card
                    // tint and border lift each row off the background.
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.cardFillTint(for: colorScheme))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                Color.cardBorderStyle(for: colorScheme),
                                lineWidth: 1.5
                            )
                    )
                    // Flatten fill + stroke before the shadow so it is computed
                    // once per row; a second decorative shadow here cost an
                    // extra offscreen pass per row while scrolling.
                    .compositingGroup()
                    .shadow(color: Color.black.opacity(Color.cardShadowOpacity(for: colorScheme)), radius: 8, x: 0, y: 4)
            )
            .padding(.vertical, 4)
    }

    // MARK: - List Content

    private var listContent: some View {
        List {
            ForEach(Array(viewModel.userStoreItems.enumerated()), id: \.element.id) { index, userStoreItem in
                ZStack {
                    if editMode == .inactive {
                        // A plain Button (not a NavigationLink) so the List
                        // still scrolls. The tap plays a quick press bounce and
                        // navigation is briefly delayed so the animation is
                        // actually visible before the next screen pushes in.
                        Button {
                            withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
                                pressedStoreId = userStoreItem.id
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                    pressedStoreId = nil
                                }
                                notificationDestination = userStoreItem
                            }
                        } label: {
                            storeRowCard(for: userStoreItem)
                                .scaleEffect(pressedStoreId == userStoreItem.id ? 0.95 : 1.0)
                                .opacity(pressedStoreId == userStoreItem.id ? 0.9 : 1.0)
                        }
                        .buttonStyle(.plain)
                    } else {
                        storeRowCard(for: userStoreItem)
                    }
                }
                .tutorialHighlight(id: index == 0 ? "tutorial_storeRow" : "noop_store_\(index)")
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                .listRowSeparator(.hidden)
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        storeToDelete = userStoreItem
                    } label: {
                        if userStoreItem.permission == .view {
                            Label("Remove", systemImage: "xmark.circle")
                        } else {
                            Label("Delete", systemImage: "trash")
                        }
                    }

                    if userStoreItem.permission != .view {
                        Button {
                            selectedStoreToShare = userStoreItem
                        } label: {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                        .tint(.blue)
                    }
                }
                .swipeActions(edge: .leading, allowsFullSwipe: false) {
                    if userStoreItem.isShared {
                        Button {
                            selectedOnMyWayStore = userStoreItem
                            showOnMyWayConfirmation = true
                        } label: {
                            Label("On My Way", systemImage: "car.fill")
                        }
                        .tint(.green)
                    }
                }
                .simultaneousGesture(
                    LongPressGesture(minimumDuration: 0.5)
                        .onEnded { _ in
                            withAnimation {
                                editMode = .active
                                longPressedItemId = userStoreItem.id
                            }
                        }
                )
            }
            .onMove(perform: moveStore)

        Color.clear
            .frame(height: 1)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets())
            .onAppear {
                isAtScrollBottom = true
                fabInactivityTimer?.invalidate()
                withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                    isFabShrunk = false
                }
            }
            .onDisappear {
                isAtScrollBottom = false
            }
        }
        .environment(\.editMode, $editMode)
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .safeAreaInset(edge: .bottom) {
            // Reserve just enough space so the FAB doesn't cover the last store item.
            // The TabView tab bar (~83pt) is already part of the safe area, so only
            // the ad height + 24pt desired gap is needed on top of that.
            let adHeight: CGFloat = subscriptionManager.isSubscribed ? 0 : 50
            Color.clear.frame(height: adHeight + 24)
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 10)
                .onChanged { value in
                    guard !isFabShrunk else { return }
                    // When scrolling down (finger moving up) at the bottom, keep FAB expanded.
                    // When scrolling up (finger moving down, positive height), shrink immediately
                    // regardless of scroll position so it stops blocking the list.
                    let isScrollingDown = value.translation.height < 0
                    if isScrollingDown && isAtScrollBottom { return }
                    fabInactivityTimer?.invalidate()
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        isFabShrunk = true
                    }
                }
        )
    }

    // MARK: - FAB Overlay

    private var fabOverlay: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()

                ZStack {
                    // Expanded menu items
                    if isMenuExpanded && !isFabShrunk {
                        VStack(spacing: 8) {
                            Button(action: {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    isMenuExpanded = false
                                    if storeViewMode == .float {
                                        isFabShrunk = true
                                    }
                                }
                                // Free-tier store limit: existing stores over the limit are
                                // kept, but adding another requires a subscription.
                                if tutorialManager.isActive || SubscriptionManager.canAddStore(
                                    isSubscribed: subscriptionManager.isSubscribed,
                                    currentStoreCount: viewModel.userStoreItems.count
                                ) {
                                    showingAddStore = true
                                } else {
                                    showingPaywall = true
                                }
                            }) {
                                HStack {
                                    Image(systemName: "cart.badge.plus")
                                        .font(.system(size: 20))
                                    Text("Add Store")
                                        .font(.system(size: 17))
                                    Spacer()
                                }
                                .padding()
                                .frame(width: 200)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(.ultraThinMaterial)
                                )
                                .foregroundColor(.primary)
                            }

                            Button(action: {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    isMenuExpanded = false
                                    if storeViewMode == .float {
                                        isFabShrunk = true
                                    }
                                }
                                showingRecipes = true
                            }) {
                                HStack {
                                    Image(systemName: "list.bullet.rectangle")
                                        .font(.system(size: 20))
                                    Text("Add Recipe")
                                        .font(.system(size: 17))
                                    Spacer()
                                }
                                .padding()
                                .frame(width: 200)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(.ultraThinMaterial)
                                )
                                .foregroundColor(.primary)
                            }

                            Button(action: {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    isMenuExpanded = false
                                    if storeViewMode == .float {
                                        isFabShrunk = true
                                    }
                                }
                                if subscriptionManager.isSubscribed {
                                    showingSmartRecipe = true
                                } else {
                                    showingPaywall = true
                                }
                            }) {
                                HStack {
                                    Image(systemName: "fork.knife.circle")
                                        .font(.system(size: 20))
                                    Text("Smart Recipe")
                                        .font(.system(size: 17))
                                    Spacer()
                                }
                                .padding()
                                .frame(width: 200)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(.ultraThinMaterial)
                                )
                                .foregroundColor(.primary)
                            }

                            Button(action: {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    isMenuExpanded = false
                                    if storeViewMode == .float {
                                        isFabShrunk = true
                                    }
                                }
                                showingBackgroundPicker = true
                            }) {
                                HStack {
                                    Image(systemName: "paintpalette")
                                        .font(.system(size: 20))
                                    Text("Colors")
                                        .font(.system(size: 17))
                                    Spacer()
                                }
                                .padding()
                                .frame(width: 200)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(.ultraThinMaterial)
                                )
                                .foregroundColor(.primary)
                            }
                        }
                        .transition(.scale(scale: 0.1, anchor: .bottomTrailing).combined(with: .opacity))
                    }

                    // Floating button — hidden when menu is open (unless shrunk in list mode)
                    // Never shrink during the tutorial so the highlight and context are clear.
                    let effectivelyShrunk = isFabShrunk && storeViewMode == .list && !viewModel.userStoreItems.isEmpty && !tutorialManager.isActive
                    if effectivelyShrunk || !isMenuExpanded {
                    Button(action: {
                        if effectivelyShrunk {
                            // Expand back from shrunk state (list mode only)
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                                isFabShrunk = false
                            }
                            startFabInactivityTimer()
                        } else if !isMenuExpanded {
                            // Open menu
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                isMenuExpanded = true
                                isFabShrunk = false
                            }
                            if storeViewMode == .list {
                                fabInactivityTimer?.invalidate()
                            }
                        }
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color.blue)
                                .shadow(
                                    color: Color.black.opacity(0.3),
                                    radius: effectivelyShrunk ? 4 : 8,
                                    x: 0,
                                    y: effectivelyShrunk ? 2 : 4
                                )

                            if !effectivelyShrunk {
                                Image(systemName: "plus")
                                    .font(.system(size: 24, weight: .semibold))
                                    .foregroundColor(.white)
                                    .transition(.opacity.combined(with: .scale(scale: 0.5)))
                            }
                        }
                        .frame(
                            width: effectivelyShrunk ? 28 : 60,
                            height: effectivelyShrunk ? 28 : 60
                        )
                        .animation(.spring(response: 0.5, dampingFraction: 0.75), value: effectivelyShrunk)
                        .tutorialHighlight(id: "tutorial_fab")
                    }
                    } // end: if effectivelyShrunk || !isMenuExpanded
                }
                .padding(.trailing, 24)
                .padding(.bottom, subscriptionManager.isSubscribed ? 24 : 74) // 24pt gap, +50pt for ad
            }
        }
    }

    // MARK: - Banner Ad Overlay

    private var bannerAdOverlay: some View {
        VStack(spacing: 0) {
            Spacer()
            BannerAdView(adUnitID: kBannerAdUnitID)
                .frame(height: 50)
                .background(Color(.systemBackground).opacity(0.95))
        }
    }

    // MARK: - FAB Timer Helpers

    private func startFabInactivityTimer() {
        fabInactivityTimer?.invalidate()
        fabInactivityTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { _ in
            DispatchQueue.main.async {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                    isFabShrunk = true
                }
            }
        }
    }

    // MARK: - Helpers

    private var deleteAlertTitle: String {
        guard let store = storeToDelete else { return "Delete Store?" }
        if store.sharedFromName != nil {
            return "Remove \(store.store.name)?"
        }
        return "Delete \(store.store.name)?"
    }

    private var deleteAlertActionLabel: String {
        storeToDelete?.sharedFromName != nil ? "Remove" : "Delete"
    }

    private func deleteAlertMessage(for store: UserStoreItem) -> String {
        if let ownerName = store.sharedFromName {
            return "This will only remove \(store.store.name) from your account. \(ownerName) will be notified that you removed the shared store."
        } else if let sharedWith = store.sharedWith, !sharedWith.isEmpty {
            let names = sharedWith.joined(separator: ", ")
            return "\(store.store.name) is currently shared with \(names). Deleting it will remove the store from their accounts too, and they will be notified."
        } else if store.permission == .edit, store.sharedStoreGroupId != nil {
            return "\(store.store.name) is a shared store. Deleting it will remove it from all shared accounts, and they will be notified."
        }
        return "All reminders for \(store.store.name) will also be deleted."
    }

    private func deleteStore(_ userStoreItem: UserStoreItem) {
        viewModel.removeStoreFromUser(userStoreItem: userStoreItem)
    }

    private func moveStore(from source: IndexSet, to destination: Int) {
        viewModel.moveStore(from: source, to: destination)

        Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            withAnimation {
                editMode = .inactive
            }
        }
    }
}

// MARK: - Empty State Step

private struct EmptyStateStep: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.15))
                    .frame(width: 28, height: 28)
                Text("\(number)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.blue)
            }
            Text(text)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#Preview {
    StoresView(pendingStoreName: .constant(nil))
}
