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

    /// Fetch store photo from Google Places API
    private func fetchStorePhoto() {
        guard let selectedItem = mapSelection else {
            #if DEBUG
            print("⚠️ LocationDetailsView: No map selection available")
            #endif
            return
        }

        let storeName = selectedItem.placemark.name ?? ""
        let coordinate = selectedItem.placemark.coordinate

        #if DEBUG
        print("🏪 LocationDetailsView: fetchStorePhoto called for '\(storeName)'")
        #endif

        guard !storeName.isEmpty else {
            #if DEBUG
            print("⚠️ LocationDetailsView: Store name is empty, skipping photo fetch")
            #endif
            return
        }

        isLoadingPhoto = true
        #if DEBUG
        print("⏳ LocationDetailsView: Starting photo load...")
        #endif

        Task {
            do {
                let photoURL = try await GooglePlacesService.shared.fetchPlacePhoto(
                    name: storeName,
                    coordinate: coordinate
                )

                await MainActor.run {
                    if let url = photoURL {
                        #if DEBUG
                        print("✅ LocationDetailsView: Photo URL received: \(url.prefix(50))...")
                        #endif
                        self.placePhotoURL = photoURL
                    } else {
                        #if DEBUG
                        print("⚠️ LocationDetailsView: No photo URL returned")
                        #endif
                        self.placePhotoURL = nil
                    }
                    self.isLoadingPhoto = false
                    #if DEBUG
                    print("✅ LocationDetailsView: Photo loading completed")
                    #endif
                }
            } catch {
                #if DEBUG
                print("❌ LocationDetailsView: Error fetching place photo: \(error)")
                if let googleError = error as? GooglePlacesError {
                    print("❌ LocationDetailsView: Google Places Error: \(googleError.localizedDescription)")
                }
                #endif
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
                       .padding(.horizontal)
                    /// Address
                   Text(mapSelection?.placemark.title ?? "Address")
                       .font(.footnote)
                       .foregroundStyle(.gray)
                       .lineLimit(2)
                       .padding(.horizontal)
                    
                    /// Photo
                    ZStack(alignment: .topTrailing) {
                        // Photo content
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
                                            .clipped()
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
                            name: selectedItem.placemark.name ?? "Unknown Store",
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
                #if DEBUG
                print("📍 LocationDetailsView: View appeared with selection, fetching photo via .task")
                #endif
                placePhotoURL = nil
                fetchStorePhoto()
            }
        }
    }
}

#Preview {
    LocationDetailsView(mapSelection: .constant(nil), show: .constant(false), viewModel: StoresViewModel())
}
