//
//  MapView.swift
//  Geolocation_v1.0.0
//
//  Created by Subong Jeon on 9/7/24.
//

import SwiftUI
import MapKit

struct MapView: View {
    
    // MARK: - PROPERTIES
    
    @State private var cameraPosition: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var viewingRegion: MKCoordinateRegion?
    @State private var searchText = ""
    @State private var results = [MKMapItem]()
    @State private var mapSelection: MKMapItem?
    @State private var showSearch = false
    @State private var showDetails = false
    @Namespace private var mapScope
    
    @StateObject private var viewModel:MapViewModel = .init()
    
    var body: some View {
        NavigationStack {
            Map(position: $cameraPosition, selection: $mapSelection, scope: mapScope){
                UserAnnotation()
                
                ForEach(results, id: \.self) { item in
                    let placemark = item.placemark
                    Marker(placemark.name ?? "", coordinate: placemark.coordinate)
                }
            }//:MAP
            .onMapCameraChange({ ctx in
                viewingRegion = ctx.region
            })
            .overlay(alignment: .bottomTrailing) {
                VStack(spacing: 15){
                    MapPitchToggle(scope: mapScope)
                    MapUserLocationButton(scope: mapScope)
                }//:VSTACK
                .buttonBorderShape(.circle)
                .padding()
            }
            .mapScope(mapScope)
            .navigationTitle("Map")
            .navigationBarTitleDisplayMode(.inline)
            /// Searchbar
            .searchable(text: $searchText, isPresented: $showSearch)
            /// Showing translucent toolbar
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .sheet(isPresented: $showDetails, content: {
                LocationDetailsView(mapSelection: $mapSelection, show: $showDetails)
                    .presentationDetents([.height(340)])
                    .presentationBackgroundInteraction(.enabled(upThrough: .height(340))) /// This enables the user to interact with the map while having this view up
                    .presentationCornerRadius(25)
            })
        }//:NAVIGATIONSTACK
        .onSubmit(of: .search) {
            Task {
                guard !searchText.isEmpty else { return }
                
                await searchPlaces()
            }
        }
        .onChange(of: showSearch, initial: false) {
            if !showSearch {
                /// Clearing search results
                results.removeAll(keepingCapacity: false)
                showDetails = false
                /// Zooming out to the user's location when the searchbar is cancelled
                withAnimation(.snappy){
                    cameraPosition = .region(viewModel.region)
                }
            }
        }
        .onChange(of: mapSelection, { oldValue, newValue in
            showDetails = newValue != nil /// Whenever newValue is not nil, showDetails
        })
    }
}

extension MapView {
    func searchPlaces() async {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = self.searchText

        /// Search based on the user's region
        request.region = self.viewingRegion ?? viewModel.region

        let results = try? await MKLocalSearch(request: request).start()
        self.results = results?.mapItems ?? []

        /// Zoom out to show all search results
        if !self.results.isEmpty {
            let region = calculateRegionForResults(self.results)
            withAnimation(.smooth(duration: 0.5)) {
                cameraPosition = .region(region)
            }
        }
    }

    /// Calculate a region that encompasses all search results
    func calculateRegionForResults(_ mapItems: [MKMapItem]) -> MKCoordinateRegion {
        guard !mapItems.isEmpty else {
            return viewModel.region
        }

        // Start with the first coordinate
        var minLat = mapItems[0].placemark.coordinate.latitude
        var maxLat = minLat
        var minLon = mapItems[0].placemark.coordinate.longitude
        var maxLon = minLon

        // Include user's location in the calculation
        let userLat = viewModel.region.center.latitude
        let userLon = viewModel.region.center.longitude
        minLat = min(minLat, userLat)
        maxLat = max(maxLat, userLat)
        minLon = min(minLon, userLon)
        maxLon = max(maxLon, userLon)

        // Find the bounds of all results
        for item in mapItems {
            let coordinate = item.placemark.coordinate
            minLat = min(minLat, coordinate.latitude)
            maxLat = max(maxLat, coordinate.latitude)
            minLon = min(minLon, coordinate.longitude)
            maxLon = max(maxLon, coordinate.longitude)
        }

        // Calculate center and span
        let centerLat = (minLat + maxLat) / 2
        let centerLon = (minLon + maxLon) / 2
        let spanLat = (maxLat - minLat) * 1.3 // Add 30% padding
        let spanLon = (maxLon - minLon) * 1.3

        // Ensure minimum span for better visibility
        let finalSpanLat = max(spanLat, 0.01)
        let finalSpanLon = max(spanLon, 0.01)

        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon),
            span: MKCoordinateSpan(latitudeDelta: finalSpanLat, longitudeDelta: finalSpanLon)
        )
    }
}

#Preview {
    MapView()
}
