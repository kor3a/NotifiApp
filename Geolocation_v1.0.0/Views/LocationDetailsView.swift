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

    // Check if the currently selected store is already in user's list (by normalized name)
    private var isStoreAlreadyAdded: Bool {
        guard let mapSelection = mapSelection else { return false }
        let storeName = mapSelection.placemark.name ?? ""
        let normalizedId = Store.normalizedId(from: storeName)

        // Check if any user store matches this store name
        return viewModel.userStoreItems.contains { userStoreItem in
            Store.normalizedId(from: userStoreItem.store.name) == normalizedId
        }
    }

    var body: some View {
        VStack {
            HStack {
                VStack(alignment: .leading, spacing: 5){

                    /// Name
                    Text(mapSelection?.placemark.name ?? "Store")
                       .font(.title2)
                       .fontWeight(.semibold)
                       .padding(.horizontal)
                    /// Address
                   Text(mapSelection?.placemark.title ?? "Address")
                       .font(.footnote)
                       .foregroundStyle(.gray)
                       .lineLimit(2)
                       .padding(.horizontal)

                    /// Map preview
                    ZStack(alignment: .topTrailing) {
                        if let mapItem = mapSelection {
                            Map(initialPosition: .region(MKCoordinateRegion(
                                center: mapItem.placemark.coordinate,
                                span: MKCoordinateSpan(latitudeDelta: 0.002, longitudeDelta: 0.002)
                            ))) {
                                Marker(mapItem.placemark.name ?? "", coordinate: mapItem.placemark.coordinate)
                            }
                            .frame(height: 200)
                            .clipShape(.rect(cornerRadius: 15))
                            .allowsHitTesting(false)
                        } else {
                            ContentUnavailableView("No Preview Available", systemImage: "eye.slash")
                                .frame(height: 200)
                                .clipShape(.rect(cornerRadius: 15))
                        }

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


                    /// Add Button
                    Button(action: {
                        guard let selectedItem = mapSelection else { return }

                        // Create a Store object from the MKMapItem (name-based, no address/coords stored)
                        let store = Store(
                            name: selectedItem.placemark.name ?? "Unknown Store"
                        )

                        // Add store to user's list
                        viewModel.addStoreToUser(store: store)

                        // Close the detail view
                        show = false
                        mapSelection = nil
                    }) {
                        Text(isStoreAlreadyAdded ? "Added" : "Add")
                    }//:BUTTON
                    .buttonStyle(PrimaryButtonStyle(color: isStoreAlreadyAdded ? .gray : .blue))
                    .disabled(isStoreAlreadyAdded)
                    .padding(.horizontal)

                }//:VSTACK

                Spacer()

            }//:HSTACK
        }//:VSTACK
    }
}

#Preview {
    LocationDetailsView(mapSelection: .constant(nil), show: .constant(false), viewModel: StoresViewModel())
}
