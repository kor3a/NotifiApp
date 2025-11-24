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

    // Check if the currently selected store is already in user's list
    private var isStoreAlreadyAdded: Bool {
        guard let mapSelection = mapSelection else { return false }
        let storeName = mapSelection.placemark.name ?? ""
        let storeAddress = mapSelection.placemark.title ?? ""

        // Check if any user store matches this location
        return viewModel.userStoreItems.contains { userStoreItem in
            userStoreItem.store.name == storeName && userStoreItem.store.address == storeAddress
        }
    }

    var body: some View {
        VStack {
            HStack {
                VStack(alignment: .leading, spacing: 5){
//                    Text(mapSelection?.placemark.name ?? "")
//                        .font(.title2)
//                        .fontWeight(.semibold)
//                    
//                    Text(mapSelection?.placemark.title ?? "")
//                        .font(.footnote)
//                        .foregroundStyle(.gray)
//                        .lineLimit(2)
//                        .padding(.trailing)
                    
                    /// Name
                    Text(mapSelection?.placemark.name ?? "Store")
                       .font(.title2)
                       .fontWeight(.semibold)
                       .padding(.leading)
                    /// Address
                   Text(mapSelection?.placemark.title ?? "Address")
                       .font(.footnote)
                       .foregroundStyle(.gray)
                       .lineLimit(2)
                       .padding(.leading)
                    
                    /// Photo
                    ZStack{
                        ContentUnavailableView("No Preview Available", systemImage: "eye.slash")
                    }//:ZSTACK
                    .frame(height: 200)
                    .clipShape(.rect(cornerRadius: 15))
                    .overlay(alignment: .topTrailing) {
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
                        .padding(10)
                    }
                    

                    /// Add Button
                    Button(action: {
                        guard let selectedItem = mapSelection else { return }

                        // Create a Store object from the MKMapItem
                        let store = Store(
                            id: UUID().uuidString, // Generate temporary ID
                            name: selectedItem.placemark.name ?? "Unknown Store",
                            address: selectedItem.placemark.title ?? "Unknown Address",
                            reminderCount: 0,
                            sortOrder: nil,
                            latitude: selectedItem.placemark.coordinate.latitude,
                            longitude: selectedItem.placemark.coordinate.longitude
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
