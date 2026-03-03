//
//  StoresView.swift
//  Geolocation_v1.0.0
//
//  Created by James Jeon on 10/18/24.
//

import SwiftUI

struct StoresView: View {
    // MARK: - PROPERTIES

    @StateObject private var viewModel = StoresViewModel()
    @StateObject private var messagesViewModel = MessagesViewModel()
    @StateObject private var aiRecipeViewModel = AIRecipeViewModel()
    @ObservedObject private var sessionManager = UserSessionManager.shared
    @State private var showingAddStore = false
    @State private var showingAIRecipe = false
    @State private var showingPaywall = false
    @State private var isMenuExpanded = false
    @State private var selectedStoreToShare: UserStoreItem?
    @State private var editMode: EditMode = .inactive
    @State private var longPressedItemId: String?
    @State private var showOnMyWayConfirmation = false
    @State private var selectedOnMyWayStore: UserStoreItem?
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        NavigationStack {
            ZStack {
                // Background with store list
                if sessionManager.isLoading || viewModel.isLoading {
                    ProgressView("Loading your stores...")
                } else if viewModel.userStoreItems.isEmpty {
                    Color.backgroundGradient(for: colorScheme)
                        .ignoresSafeArea()
                        .onTapGesture {
                            if isMenuExpanded {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    isMenuExpanded = false
                                }
                            }
                        }
                } else {
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
                                    if let index = viewModel.userStoreItems.firstIndex(where: { $0.id == userStoreItem.id }) {
                                        deleteStore(at: IndexSet(integer: index))
                                    }
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
                    .background(
                        Color.backgroundGradient(for: colorScheme)
                            .ignoresSafeArea()
                    )
                    .safeAreaInset(edge: .bottom) {
                        Color.clear.frame(height: 90)
                    }
                    .toolbar {
                        if editMode == .active {
                            ToolbarItem(placement: .navigationBarLeading) {
                                Button("Done") {
                                    withAnimation {
                                        editMode = .inactive
                                    }
                                }
                            }
                        }
                    }
                }

                // Transparent overlay to close menu when tapped
                if isMenuExpanded {
                    Color.clear
                        .contentShape(Rectangle())
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                isMenuExpanded = false
                            }
                        }
                }

                // Floating action button and menu
                VStack {
                    Spacer()
                    HStack {
                        Spacer()

                        ZStack {
                            // Expanded menu
                            if isMenuExpanded {
                                VStack(spacing: 8) {
                                    Button(action: {
                                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                            isMenuExpanded = false
                                        }
                                        showingAddStore = true
                                    }) {
                                        HStack {
                                            Image(systemName: "cart.badge.plus")
                                                .font(.system(size: 20))
                                            Text("Add Store")
                                                .font(.headline)
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
                                        }
                                        if sessionManager.currentUser?.isSubscribed == true {
                                            showingAIRecipe = true
                                        } else {
                                            showingPaywall = true
                                        }
                                    }) {
                                        HStack {
                                            Image(systemName: "fork.knife.circle")
                                                .font(.system(size: 20))
                                            Text("AI Recipe")
                                                .font(.headline)
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

                            // Floating + button
                            if !isMenuExpanded {
                                Button(action: {
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                        isMenuExpanded = true
                                    }
                                }) {
                                    Image(systemName: "plus")
                                        .font(.system(size: 24, weight: .semibold))
                                        .foregroundColor(.white)
                                        .frame(width: 60, height: 60)
                                        .background(
                                            Circle()
                                                .fill(Color.blue)
                                                .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 4)
                                        )
                                }
                                .transition(.scale(scale: 0.1, anchor: .bottomTrailing).combined(with: .opacity))
                            }
                        }
                        .padding(.trailing, 24)
                        .padding(.bottom, 24)
                    }
                }
            }
        }//:NAVIGATIONSTACK
        .sheet(isPresented: $showingAddStore) {
            AddStoreView(viewModel: viewModel)
        }
        .sheet(isPresented: $showingAIRecipe) {
            AIRecipeView(viewModel: aiRecipeViewModel, storesViewModel: viewModel)
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
            // Try to fetch immediately if user data is available
            if sessionManager.currentUser != nil {
                self.viewModel.fetchUserStores()
            }
        }
        .onChange(of: sessionManager.currentUser) { oldValue, newValue in
            // Fetch stores when user data becomes available
            if newValue != nil {
                if viewModel.userStoreItems.isEmpty {
                    self.viewModel.fetchUserStores()
                }
            }
        }
    }//:BODY

    private func deleteStore(at offsets: IndexSet) {
        for index in offsets {
            let userStoreItem = viewModel.userStoreItems[index]
            viewModel.removeStoreFromUser(userStoreItem: userStoreItem)
        }
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
    StoresView()
}
