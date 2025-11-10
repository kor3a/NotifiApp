//
//  AddStoreView.swift
//  Geolocation_v1.0.0
//
//  Created by James Jeon on 11/1/25.
//

import SwiftUI

struct AddStoreView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: StoresViewModel
    @State private var searchText = ""
    
    var filteredStores: [Store] {
        if searchText.isEmpty {
            return viewModel.allStores
        } else {
            return viewModel.allStores.filter { store in
                store.name.localizedCaseInsensitiveContains(searchText) ||
                store.address.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                if viewModel.isLoadingAllStores {
                    VStack(spacing: 20) {
                        ProgressView()
                        Text("Loading available stores...")
                            .foregroundStyle(.gray)
                    }
                    .padding()
                } else if viewModel.allStores.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "storefront")
                            .resizable()
                            .frame(width: 60, height: 60)
                            .foregroundStyle(.gray)

                        Text("No stores available")
                            .font(.headline)

                        Text("There are no stores in the database yet")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else {
                    List {
                        ForEach(filteredStores) { store in
                            Button(action: {
                                viewModel.addStoreToUser(store: store)
                                dismiss()
                            }) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(store.name)
                                            .font(.headline)
                                            .foregroundStyle(.primary)

                                        Text(store.address)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    if viewModel.userStoreItems.contains(where: { $0.store.id == store.id }) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.green)
                                    } else {
                                        Image(systemName: "plus.circle")
                                            .foregroundStyle(.blue)
                                    }
                                }
                            }
                            .disabled(viewModel.userStoreItems.contains(where: { $0.store.id == store.id }))
                        }
                    }
                    .searchable(text: $searchText, prompt: "Search stores")
                }

                if !viewModel.errorMessage.isEmpty {
                    Text(viewModel.errorMessage)
                        .foregroundStyle(.red)
                        .font(.caption)
                        .padding()
                }
            }
            .navigationTitle("Add Store")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                viewModel.fetchAllStores()
            }
        }
    }
}

#Preview {
    AddStoreView(viewModel: StoresViewModel())
}
