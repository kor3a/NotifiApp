//
//  AddStoreView.swift
//  Geolocation_v1.0.0
//
//  Created by James Jeon on 11/1/25.
//

import SwiftUI

struct AddStoreView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var viewModel: StoresViewModel
    @ObservedObject private var subscriptionManager = SubscriptionManager.shared
    @StateObject private var locationSearchManager = LocationSearchManager()
    @State private var searchText = ""
    @State private var showingPaywall = false
    @FocusState private var isSearchFocused: Bool

    /// Free-tier store limit check. Existing stores over the limit are kept
    /// (grandfathered), but adding another store requires a subscription.
    private var canAddStore: Bool {
        TutorialManager.shared.isActive || SubscriptionManager.canAddStore(
            isSubscribed: subscriptionManager.isSubscribed,
            currentStoreCount: viewModel.userStoreItems.count
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                OrganicPalette.canvas(colorScheme)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Add a store")
                            .font(OrganicPalette.display(32))
                            .foregroundColor(OrganicPalette.ink(colorScheme))
                            .padding(.top, 8)

                        Text("Search for a shop near you and add it to your list.")
                            .font(.system(size: 16))
                            .foregroundColor(OrganicPalette.inkSoft(colorScheme))

                        searchField

                        if !locationSearchManager.isLocationAuthorized {
                            locationBanner
                        }

                        results

                        if !viewModel.errorMessage.isEmpty {
                            errorCard
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                }
                .scrollDismissesKeyboard(.immediately)
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(OrganicPalette.canvas(colorScheme), for: .navigationBar)
            .tint(OrganicPalette.terracotta(colorScheme))
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(OrganicPalette.terracotta(colorScheme))
                }
            }
            .sheet(isPresented: $showingPaywall) {
                SubscriptionPaywallView()
            }
            .onChange(of: searchText) { _, newValue in
                locationSearchManager.searchNearbyStores(query: newValue)
            }
            .onAppear {
                locationSearchManager.requestLocation()
            }
        }
    }

    // MARK: - Search Field

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(OrganicPalette.inkSoft(colorScheme))

            TextField(
                "",
                text: $searchText,
                prompt: Text("Store name")
                    .foregroundColor(OrganicPalette.inkSoft(colorScheme).opacity(0.8))
            )
            .font(.system(size: 17))
            .foregroundColor(OrganicPalette.ink(colorScheme))
            .autocorrectionDisabled()
            .submitLabel(.search)
            .focused($isSearchFocused)

            if locationSearchManager.isSearching {
                ProgressView()
                    .tint(OrganicPalette.terracotta(colorScheme))
            } else if !searchText.isEmpty {
                Button {
                    searchText = ""
                    isSearchFocused = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(OrganicPalette.inkSoft(colorScheme).opacity(0.7))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 18)
        .frame(height: 54)
        .background(Capsule().fill(OrganicPalette.field(colorScheme)))
    }

    // MARK: - States

    /// Nothing here can be searched until Location is on, so this leads with the
    /// button that fixes it rather than an explanation of the problem.
    private var locationBanner: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "location.slash")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(OrganicPalette.terracotta(colorScheme))

                Text("Location access required")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(OrganicPalette.ink(colorScheme))
            }

            if !locationSearchManager.locationError.isEmpty {
                Text(locationSearchManager.locationError)
                    .font(.system(size: 14))
                    .foregroundColor(OrganicPalette.inkSoft(colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button {
                locationSearchManager.requestLocationPermission()
            } label: {
                Text("Enable Location")
                    .font(OrganicPalette.title(15))
                    .foregroundColor(.white)
                    .padding(.horizontal, 22)
                    .frame(height: 44)
                    .background(Capsule().fill(OrganicPalette.terracotta(colorScheme)))
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            OrganicCardBackground(colorScheme: colorScheme, fill: OrganicPalette.blush(colorScheme))
        )
    }

    @ViewBuilder
    private var results: some View {
        if searchText.isEmpty && locationSearchManager.isLocationAuthorized {
            hint(
                icon: "magnifyingglass",
                title: "Search for nearby stores",
                message: "Type a store name to find locations near you."
            )
        } else if locationSearchManager.searchResults.isEmpty && !searchText.isEmpty && !locationSearchManager.isSearching {
            hint(
                icon: "storefront",
                title: "No stores found",
                message: "Try a different search term."
            )
        } else {
            VStack(spacing: 10) {
                ForEach(locationSearchManager.searchResults) { searchResult in
                    resultRow(for: searchResult)
                }
            }
        }
    }

    private func hint(icon: String, title: String, message: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 30, weight: .light))
                .foregroundColor(OrganicPalette.terracotta(colorScheme).opacity(0.55))
                .frame(width: 72, height: 72)
                .background(Circle().fill(OrganicPalette.blush(colorScheme)))

            Text(title)
                .font(OrganicPalette.display(22))
                .foregroundColor(OrganicPalette.ink(colorScheme))

            Text(message)
                .font(.system(size: 15))
                .foregroundColor(OrganicPalette.inkSoft(colorScheme))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 32)
    }

    // MARK: - Result Row

    private func resultRow(for searchResult: SearchResultStore) -> some View {
        // A store already on the list can't be added again, so its row goes
        // quiet and shows a sage check instead of the add glyph.
        let isAdded = viewModel.userStoreItems.contains {
            Store.normalizedId(from: $0.store.name) == searchResult.id
        }

        return Button {
            guard canAddStore else {
                showingPaywall = true
                return
            }
            let store = searchResult.toStore()
            viewModel.addStoreToUser(store: store)
            dismiss()
        } label: {
            HStack(spacing: 14) {
                CachedLogoImage(storeName: searchResult.name, size: 46)

                VStack(alignment: .leading, spacing: 3) {
                    Text(searchResult.name)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(OrganicPalette.ink(colorScheme))
                        .lineLimit(1)

                    Text(searchResult.locationCountFormatted)
                        .font(.system(size: 14))
                        .foregroundColor(OrganicPalette.inkSoft(colorScheme))
                        .lineLimit(1)

                    HStack(spacing: 5) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 10))
                        Text("Nearest: \(searchResult.distanceFormatted)")
                            .font(.system(size: 13))
                    }
                    .foregroundColor(OrganicPalette.terracotta(colorScheme))
                }

                Spacer(minLength: 8)

                Image(systemName: isAdded ? "checkmark.circle.fill" : "plus.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(
                        isAdded
                            ? OrganicPalette.sageInk(colorScheme)
                            : OrganicPalette.terracotta(colorScheme)
                    )
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(OrganicCardBackground(colorScheme: colorScheme))
            .opacity(isAdded ? 0.6 : 1)
        }
        .buttonStyle(.plain)
        .disabled(isAdded)
    }

    private var errorCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 18))
                .foregroundColor(OrganicPalette.rust(colorScheme))

            Text(viewModel.errorMessage)
                .font(.system(size: 14))
                .foregroundColor(OrganicPalette.ink(colorScheme))
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            OrganicCardBackground(colorScheme: colorScheme, fill: OrganicPalette.blush(colorScheme))
        )
    }
}

#Preview {
    AddStoreView(viewModel: StoresViewModel())
}
