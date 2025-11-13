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
    @State private var editMode: EditMode = .inactive
    @State private var longPressedItemId: String?

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
                            NavigationLink(destination: ReminderView(userStoreItem: userStoreItem)) {
                                StoreItemView(store: userStoreItem.store)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .opacity(editMode == .active ? 0 : 1)

                            if editMode == .active {
                                StoreItemView(store: userStoreItem.store)
                            }
                        }
                        .listRowBackground(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(
                                            LinearGradient(
                                                colors: [
                                                    Color.white.opacity(0.6),
                                                    Color.white.opacity(0.2)
                                                ],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 1.5
                                        )
                                )
                                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                                .shadow(color: Color.white.opacity(0.5), radius: 2, x: 0, y: -2)
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
                        }
                        .onLongPressGesture(minimumDuration: 0.5) {
                            withAnimation {
                                editMode = .active
                                longPressedItemId = userStoreItem.id
                            }
                        }
                    }
                    .onMove(perform: moveStore)
                } //:LIST
                .environment(\.editMode, $editMode)
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(
                    LinearGradient(
                        colors: [
                            Color(red: 0.95, green: 0.96, blue: 0.98),
                            Color(red: 0.88, green: 0.92, blue: 0.96)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
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
