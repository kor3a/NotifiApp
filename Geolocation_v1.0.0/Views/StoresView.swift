//
//  StoresView.swift
//  Geolocation_v1.0.0
//
//  Created by James Jeon on 10/18/24.
//

import SwiftUI

enum StoreViewMode {
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
    @State private var showingAddStore = false
    @State private var showingSmartRecipe = false
    @State private var showingPaywall = false
    @State private var isMenuExpanded = false
    @State private var selectedStoreToShare: UserStoreItem?
    @State private var editMode: EditMode = .inactive
    @State private var longPressedItemId: String?
    @State private var showOnMyWayConfirmation = false
    @State private var selectedOnMyWayStore: UserStoreItem?
    @State private var storeToDelete: UserStoreItem?
    @State private var notificationDestination: UserStoreItem? = nil
    @State private var storeViewMode: StoreViewMode = .list
    @State private var isFloatEditMode: Bool = false
    @State private var isFabShrunk: Bool = false
    @State private var fabInactivityTimer: Timer? = nil
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        NavigationStack {
            ZStack {
                // Background always visible
                Color.backgroundGradient(for: colorScheme)
                    .ignoresSafeArea()

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
                } else if !viewModel.userStoreItems.isEmpty {
                    if storeViewMode == .list {
                        listContent
                    } else {
                        StoreFloatView(
                            stores: viewModel.userStoreItems,
                            onStoreTap: { item in
                                notificationDestination = item
                            },
                            onStoreDelete: { item in
                                isFloatEditMode = false
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

                // View mode toggle (only when stores exist)
                if !viewModel.userStoreItems.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
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
                }
            }
        }//:NAVIGATIONSTACK
        .sheet(isPresented: $showingAddStore) {
            AddStoreView(viewModel: viewModel)
        }
        .sheet(isPresented: $showingSmartRecipe) {
            SmartRecipeView(viewModel: smartRecipeViewModel, storesViewModel: viewModel)
        }
        .sheet(isPresented: $showingPaywall) {
            SubscriptionPaywallView()
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
            if newValue != nil {
                if viewModel.userStoreItems.isEmpty {
                    self.viewModel.fetchUserStores()
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

    // MARK: - List Content

    private var listContent: some View {
        List {
            ForEach(viewModel.userStoreItems) { userStoreItem in
                ZStack {
                    if editMode == .inactive {
                        NavigationLink(destination: ReminderView(
                            userStoreItem: userStoreItem,
                            availableStores: viewModel.userStoreItems.filter { $0.id != userStoreItem.id }
                        )) {
                            StoreItemView(store: userStoreItem.store, isShared: userStoreItem.isShared)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    } else {
                        StoreItemView(store: userStoreItem.store, isShared: userStoreItem.isShared)
                    }
                }
                .listRowBackground(
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
                )
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
        }
        .environment(\.editMode, $editMode)
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: 90)
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 10)
                .onChanged { _ in
                    guard !isFabShrunk else { return }
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
                                showingAddStore = true
                            }) {
                                HStack {
                                    Image(systemName: "cart.badge.plus")
                                        .font(.system(size: 20))
                                    Text("Add Store")
                                        .font(.specialElite(size: 17))
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
                                if sessionManager.currentUser?.isSubscribed == true {
                                    showingSmartRecipe = true
                                } else {
                                    showingPaywall = true
                                }
                            }) {
                                HStack {
                                    Image(systemName: "fork.knife.circle")
                                        .font(.system(size: 20))
                                    Text("Smart Recipe")
                                        .font(.specialElite(size: 17))
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
                    let effectivelyShrunk = isFabShrunk && storeViewMode == .list
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
                    }
                    } // end: if effectivelyShrunk || !isMenuExpanded
                }
                .padding(.trailing, 24)
                .padding(.bottom, 24)
            }
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

#Preview {
    StoresView(pendingStoreName: .constant(nil))
}
