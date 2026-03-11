//
//  LocationDetailsView.swift
//  Geolocation_v1.0.0
//
//  Created by Subong Jeon on 8/7/24.
//

import SwiftUI
import MapKit


struct LocationDetailsView: View {
    @Binding var mapSelection: MKMapItem?
    @Binding var show: Bool
    @ObservedObject var viewModel: StoresViewModel
    var onViewReminders: ((UserStoreItem) -> Void)? = nil
    @ObservedObject private var logoProvider = StoreLogoProvider.shared

    // Find the matching UserStoreItem for the currently selected store (by normalized name)
    private var matchingUserStoreItem: UserStoreItem? {
        guard let mapSelection = mapSelection else { return nil }
        let storeName = mapSelection.name ?? ""
        let normalizedId = Store.normalizedId(from: storeName)

        return viewModel.userStoreItems.first { userStoreItem in
            Store.normalizedId(from: userStoreItem.store.name) == normalizedId
        }
    }

    private var isStoreAlreadyAdded: Bool {
        matchingUserStoreItem != nil
    }

    private var storeName: String {
        mapSelection?.name ?? "Store"
    }

    var body: some View {
        VStack {
            HStack {
                VStack(alignment: .leading, spacing: 5){
                    /// Name
                    Text(storeName)
                       .font(.title2)
                       .fontWeight(.semibold)
                       .padding(.horizontal)
                    /// Address
                   Text(mapSelection?.placemark.title ?? "Address")
                       .font(.footnote)
                       .foregroundStyle(.gray)
                       .lineLimit(2)
                       .padding(.horizontal)

                    /// Store Logo
                    ZStack(alignment: .topTrailing) {
                        // Logo content
                        ZStack {
                            if let image = logoProvider.cachedImage(for: storeName) {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 200)
                                    .clipped()
                            } else if logoProvider.logoURL(for: storeName) != nil {
                                ProgressView()
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .background(Color(.systemGray6))
                            } else {
                                // No logo available — show styled placeholder
                                VStack(spacing: 12) {
                                    CachedLogoImage(storeName: storeName, size: 80)
                                    Text(storeName)
                                        .font(.headline)
                                        .foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .background(Color(.systemGray6))
                            }
                        }//:ZSTACK
                        .frame(height: 200)
                        .clipShape(.rect(cornerRadius: 15))

                        // Close button - outside clipped area
                        Button {
                            show.toggle()
                            withAnimation(.snappy) {
                                mapSelection = nil
                            }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .resizable()
                                .frame(width: 24, height: 24)
                                .foregroundStyle(.gray, Color(.systemGray6))
                        }//:BUTTON
                        .padding(8)
                    }//:OUTER ZSTACK
                    .padding(.horizontal)


                    /// Add / View Reminders Button
                    if let existingItem = matchingUserStoreItem {
                        Button(action: {
                            show = false
                            mapSelection = nil
                            onViewReminders?(existingItem)
                        }) {
                            Text("View Reminders")
                        }//:BUTTON
                        .buttonStyle(PrimaryButtonStyle(color: .blue))
                        .padding(.horizontal)
                    } else {
                        Button(action: {
                            guard let selectedItem = mapSelection else { return }

                            // Create a Store object from the MKMapItem (name-based, no address/coords stored)
                            let store = Store(
                                name: selectedItem.name ?? "Unknown Store",
                                imageURL: logoProvider.logoURL(for: selectedItem.name ?? "")
                            )

                            // Add store to user's list
                            viewModel.addStoreToUser(store: store)

                            // Close the detail view
                            show = false
                            mapSelection = nil
                        }) {
                            Text("Add")
                        }//:BUTTON
                        .buttonStyle(PrimaryButtonStyle(color: .blue))
                        .padding(.horizontal)
                    }

                }//:VSTACK

                Spacer()

            }//:HSTACK
        }//:VSTACK
    }
}

#Preview {
    LocationDetailsView(mapSelection: .constant(nil), show: .constant(false), viewModel: StoresViewModel())
}
