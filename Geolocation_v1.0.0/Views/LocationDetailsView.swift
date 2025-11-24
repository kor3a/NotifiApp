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

    @State private var placePhotoURL: String?
    @State private var isLoadingPhoto = false

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

    /// Fetch store photo from Google Places API
    private func fetchStorePhoto() {
        guard let selectedItem = mapSelection else {
            print("⚠️ LocationDetailsView: No map selection available")
            return
        }

        let storeName = selectedItem.placemark.name ?? ""
        let coordinate = selectedItem.placemark.coordinate

        print("🏪 LocationDetailsView: fetchStorePhoto called for '\(storeName)'")

        guard !storeName.isEmpty else {
            print("⚠️ LocationDetailsView: Store name is empty, skipping photo fetch")
            return
        }

        isLoadingPhoto = true
        print("⏳ LocationDetailsView: Starting photo load...")

        Task {
            do {
                let photoURL = try await GooglePlacesService.shared.fetchPlacePhoto(
                    name: storeName,
                    coordinate: coordinate
                )

                await MainActor.run {
                    if let url = photoURL {
                        print("✅ LocationDetailsView: Photo URL received: \(url.prefix(50))...")
                        self.placePhotoURL = photoURL
                    } else {
                        print("⚠️ LocationDetailsView: No photo URL returned")
                        self.placePhotoURL = nil
                    }
                    self.isLoadingPhoto = false
                    print("✅ LocationDetailsView: Photo loading completed")
                }
            } catch {
                print("❌ LocationDetailsView: Error fetching place photo: \(error)")
                if let googleError = error as? GooglePlacesError {
                    print("❌ LocationDetailsView: Google Places Error: \(googleError.localizedDescription)")
                }
                await MainActor.run {
                    self.isLoadingPhoto = false
                }
            }
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
                        if isLoadingPhoto {
                            ProgressView()
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .background(Color(.systemGray6))
                        } else if let photoURLString = placePhotoURL,
                                  let photoURL = URL(string: photoURLString) {
                            AsyncImage(url: photoURL) { phase in
                                switch phase {
                                case .empty:
                                    ProgressView()
                                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                                        .background(Color(.systemGray6))
                                case .success(let image):
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(height: 200)
                                case .failure:
                                    ContentUnavailableView("No Preview Available", systemImage: "eye.slash")
                                @unknown default:
                                    ContentUnavailableView("No Preview Available", systemImage: "eye.slash")
                                }
                            }
                        } else {
                            ContentUnavailableView("No Preview Available", systemImage: "eye.slash")
                        }
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

                        // Create a Store object from the MKMapItem with Google Places photo
                        let store = Store(
                            id: UUID().uuidString, // Generate temporary ID
                            name: selectedItem.placemark.name ?? "Unknown Store",
                            address: selectedItem.placemark.title ?? "Unknown Address",
                            reminderCount: 0,
                            sortOrder: nil,
                            latitude: selectedItem.placemark.coordinate.latitude,
                            longitude: selectedItem.placemark.coordinate.longitude,
                            imageURL: placePhotoURL
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
        .task(id: mapSelection) {
            // Fetch photo when view appears or mapSelection changes
            if mapSelection != nil {
                print("📍 LocationDetailsView: View appeared with selection, fetching photo via .task")
                placePhotoURL = nil
                fetchStorePhoto()
            }
        }
    }
}

#Preview {
    LocationDetailsView(mapSelection: .constant(nil), show: .constant(false), viewModel: StoresViewModel())
}
