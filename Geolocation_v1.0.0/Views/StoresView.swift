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
    @ObservedObject private var sessionManager = UserSessionManager.shared
    @State private var showingAddStore = false
    @State private var selectedStoreToShare: UserStoreItem?
    @State private var editMode: EditMode = .inactive
    @State private var longPressedItemId: String?
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        NavigationStack {
            if sessionManager.isLoading || viewModel.isLoading {
                ProgressView("Loading your stores...")
            } else if viewModel.userStoreItems.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "cart.badge.plus")
                        .resizable()
                        .frame(width: 80, height: 80)
                        .foregroundStyle(.gray)
                    
                    Text("No Stores Added")
                        .font(.title2)
                        .bold()
                    
                    Text("Add stores to start creating reminders")
                        .foregroundStyle(.gray)
                        .multilineTextAlignment(.center)
                    
                    Button(action: {
                        showingAddStore = true
                    }) {
                        Label("Add Store", systemImage: "plus")
                            .font(.headline)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                }
                .padding()
            } else {
                List {
                    ForEach(viewModel.userStoreItems) { userStoreItem in
                        ZStack {
                            if editMode == .inactive {
                                NavigationLink(destination: ReminderView(userStoreItem: userStoreItem)) {
                                    StoreItemView(store: userStoreItem.store)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            } else {
                                StoreItemView(store: userStoreItem.store)
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
                                Label("Delete", systemImage: "trash")
                            }

                            Button {
                                selectedStoreToShare = userStoreItem
                            } label: {
                                Label("Share", systemImage: "square.and.arrow.up")
                            }
                            .tint(.blue)
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
                } //:LIST
                .environment(\.editMode, $editMode)
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(
                    Color.backgroundGradient(for: colorScheme)
                        .ignoresSafeArea()
                )
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
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: {
                            showingAddStore = true
                        }) {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
        }//:NAVIGATIONSTACK
        .sheet(isPresented: $showingAddStore) {
            AddStoreView(viewModel: viewModel)
        }
        .sheet(item: $selectedStoreToShare) { storeToShare in
            ShareStoreView(viewModel: viewModel, userStoreItem: storeToShare)
        }
        .onAppear() {
            // Try to fetch immediately if user data is available
            if sessionManager.currentUser != nil {
                self.viewModel.fetchUserStores()
            }
        }
        .onChange(of: sessionManager.currentUser) { oldValue, newValue in
            // Fetch stores when user data becomes available
            if newValue != nil && viewModel.userStoreItems.isEmpty {
                self.viewModel.fetchUserStores()
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

        // Auto-exit edit mode after a short delay
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            withAnimation {
                editMode = .inactive
            }
        }
    }
}

#Preview {
    StoresView()
}
