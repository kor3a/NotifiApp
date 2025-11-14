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
    @StateObject private var locationSearchManager = LocationSearchManager()
    @State private var searchText = ""
    
    var body: some View {
        NavigationStack {
            VStack {
                // Location status banner
                if !locationSearchManager.isLocationAuthorized {
                    VStack(spacing: 10) {
                        HStack {
                            Image(systemName: "location.slash")
                                .foregroundStyle(.orange)
                            Text("Location access required")
                                .font(.subheadline)
                                .foregroundStyle(.orange)
                        }

                        if !locationSearchManager.locationError.isEmpty {
                            Text(locationSearchManager.locationError)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }

                        Button("Enable Location") {
                            locationSearchManager.requestLocationPermission()
                        }
                        .buttonStyle(.bordered)
                        .tint(.blue)
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(10)
                    .padding(.horizontal)
                }

                // Search results
                if locationSearchManager.isSearching {
                    VStack(spacing: 20) {
                        ProgressView()
                        Text("Searching nearby stores...")
                            .foregroundStyle(.gray)
                    }
                    .padding()
                } else if searchText.isEmpty && locationSearchManager.isLocationAuthorized {
                    VStack(spacing: 20) {
                        Image(systemName: "magnifyingglass")
                            .resizable()
                            .frame(width: 50, height: 50)
                            .foregroundStyle(.gray)

                        Text("Search for nearby stores")
                            .font(.headline)

                        Text("Type a store name to find locations near you")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else if locationSearchManager.searchResults.isEmpty && !searchText.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "storefront")
                            .resizable()
                            .frame(width: 60, height: 60)
                            .foregroundStyle(.gray)

                        Text("No stores found")
                            .font(.headline)

                        Text("Try a different search term")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else {
                    List {
                        ForEach(locationSearchManager.searchResults) { searchResult in
                            Button(action: {
                                let store = searchResult.toStore()
                                viewModel.addStoreToUser(store: store)
                                dismiss()
                            }) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(searchResult.name)
                                            .font(.headline)
                                            .foregroundStyle(.primary)

                                        Text(searchResult.address)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)

                                        HStack(spacing: 5) {
                                            Image(systemName: "location.fill")
                                                .font(.caption2)
                                            Text(searchResult.distanceFormatted)
                                                .font(.caption2)
                                        }
                                        .foregroundStyle(.blue)
                                    }

                                    Spacer()

                                    // Check if store is already added by comparing name and address
                                    if viewModel.userStoreItems.contains(where: {
                                        $0.store.name == searchResult.name &&
                                        $0.store.address == searchResult.address
                                    }) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.green)
                                    } else {
                                        Image(systemName: "plus.circle")
                                            .foregroundStyle(.blue)
                                    }
                                }
                            }
                            .disabled(viewModel.userStoreItems.contains(where: {
                                $0.store.name == searchResult.name &&
                                $0.store.address == searchResult.address
                            }))
                        }
                    }
                }

                if !viewModel.errorMessage.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                            .font(.title2)

                        Text(viewModel.errorMessage)
                            .foregroundStyle(.red)
                            .font(.caption)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
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
            .searchable(text: $searchText, prompt: "Search for store name")
            .onChange(of: searchText) { _, newValue in
                locationSearchManager.searchNearbyStores(query: newValue)
            }
            .onAppear {
                locationSearchManager.requestLocation()
            }
        }
    }
}

#Preview {
    AddStoreView(viewModel: StoresViewModel())
}
