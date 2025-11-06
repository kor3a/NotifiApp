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
    @State private var showingAddStore = false
    
    var body: some View {
        NavigationStack {
            if viewModel.isLoading {
                ProgressView("Loading your stores...")
            } else if viewModel.stores.isEmpty {
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
                    ForEach(viewModel.stores) { store in
                        NavigationLink(destination: ReminderView()) {
                            StoreItemView(store: store)
                        }
                    }
                    .onDelete(perform: deleteStore)
                } //:LIST
                .listStyle(.grouped)
                .toolbar {
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
            self.viewModel.fetchUserStores()
        }
    }//:BODY
    
    private func deleteStore(at offsets: IndexSet) {
        for index in offsets {
            let store = viewModel.stores[index]
            viewModel.removeStoreFromUser(store: store)
        }
    }
}

#Preview {
    StoresView()
}
