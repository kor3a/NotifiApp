//
//  MapView.swift
//  Geolocation_v1.0.0
//
//  Created by Subong Jeon on 9/7/24.
//

import SwiftUI
import MapKit

// MARK: - Map Style Type
enum MapStyleType {
    case standard
    case imagery
    case hybrid

    var mapStyle: MapStyle {
        switch self {
        case .standard:
            return .standard
        case .imagery:
            return .imagery
        case .hybrid:
            return .hybrid
        }
    }
}

struct MapView: View {

    // MARK: - PROPERTIES

    @State private var cameraPosition: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var viewingRegion: MKCoordinateRegion?
    @State private var searchText = ""
    @State private var results = [MKMapItem]()
    @State private var mapSelection: MKMapItem?
    @State private var showSearch = false
    @State private var showDetails = false
    @State private var isSearchExpanded = false
    @State private var selectedMapStyle: MapStyleType = .standard
    @Namespace private var mapScope
    @FocusState private var isSearchFocused: Bool

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
            .mapStyle(selectedMapStyle.mapStyle)
            .onMapCameraChange({ ctx in
                viewingRegion = ctx.region
            })
            .overlay(alignment: .topTrailing) {
                VStack(spacing: 15){
                    MapPitchToggle(scope: mapScope)
                    MapUserLocationButton(scope: mapScope)
                }//:VSTACK
                .buttonBorderShape(.circle)
                .padding()
            }
            .overlay(alignment: .bottom) {
                customBottomBar
            }
            .mapScope(mapScope)
            .navigationTitle("Map")
            .navigationBarTitleDisplayMode(.inline)
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
        .onChange(of: mapSelection, { oldValue, newValue in
            showDetails = newValue != nil /// Whenever newValue is not nil, showDetails
        })
    }

    // MARK: - CUSTOM BOTTOM BAR

    private var customBottomBar: some View {
        HStack(spacing: 0) {
            // Left side: Tab bar
            HStack(spacing: 12) {
                // Standard Map View Button
                Button(action: {
                    withAnimation(.spring(response: 0.3)) {
                        selectedMapStyle = .standard
                    }
                }) {
                    Image(systemName: "map")
                        .font(.system(size: 20))
                        .foregroundColor(selectedMapStyle == .standard ? .white : .primary)
                        .frame(width: 44, height: 44)
                        .background(selectedMapStyle == .standard ? Color.blue : Color.clear)
                        .clipShape(Circle())
                }

                // Satellite Map View Button
                Button(action: {
                    withAnimation(.spring(response: 0.3)) {
                        selectedMapStyle = .imagery
                    }
                }) {
                    Image(systemName: "globe.americas.fill")
                        .font(.system(size: 20))
                        .foregroundColor(selectedMapStyle == .imagery ? .white : .primary)
                        .frame(width: 44, height: 44)
                        .background(selectedMapStyle == .imagery ? Color.blue : Color.clear)
                        .clipShape(Circle())
                }

                // Hybrid Map View Button
                Button(action: {
                    withAnimation(.spring(response: 0.3)) {
                        selectedMapStyle = .hybrid
                    }
                }) {
                    Image(systemName: "map.fill")
                        .font(.system(size: 20))
                        .foregroundColor(selectedMapStyle == .hybrid ? .white : .primary)
                        .frame(width: 44, height: 44)
                        .background(selectedMapStyle == .hybrid ? Color.blue : Color.clear)
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 25))

            Spacer()

            // Right side: Search
            HStack(spacing: 0) {
                if isSearchExpanded {
                    TextField("Search places...", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .focused($isSearchFocused)
                        .onSubmit {
                            Task {
                                guard !searchText.isEmpty else { return }
                                await searchPlaces()
                                isSearchFocused = false
                            }
                        }
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }

                Button(action: {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        if isSearchExpanded && !searchText.isEmpty {
                            // Clear search
                            searchText = ""
                            results.removeAll(keepingCapacity: false)
                            showDetails = false
                            withAnimation(.snappy) {
                                cameraPosition = .region(viewModel.region)
                            }
                        }
                        isSearchExpanded.toggle()
                        if isSearchExpanded {
                            isSearchFocused = true
                        } else {
                            isSearchFocused = false
                        }
                    }
                }) {
                    Image(systemName: isSearchExpanded && !searchText.isEmpty ? "xmark" : "magnifyingglass")
                        .font(.system(size: 20))
                        .foregroundColor(.primary)
                        .frame(width: 44, height: 44)
                }
            }
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 25))
            .frame(maxWidth: isSearchExpanded ? .infinity : 44)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }
}

extension MapView {
    func searchPlaces() async {
        // Start with a small radius and incrementally increase until we find results
        let radiusSteps: [CLLocationDistance] = [2000, 5000, 10000, 20000, 50000] // 2km, 5km, 10km, 20km, 50km
        var foundResults: [MKMapItem] = []
        let userLocation = CLLocation(latitude: viewModel.region.center.latitude, longitude: viewModel.region.center.longitude)

        // Try each radius until we find results
        for radius in radiusSteps {
            let searchRegion = createRegion(around: viewModel.region.center, radius: radius)

            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = self.searchText
            request.region = searchRegion

            let results = try? await MKLocalSearch(request: request).start()
            let items = results?.mapItems ?? []

            // Filter results to only include items within the current radius
            let filteredItems = items.filter { item in
                let itemLocation = CLLocation(latitude: item.placemark.coordinate.latitude,
                                             longitude: item.placemark.coordinate.longitude)
                let distance = userLocation.distance(from: itemLocation)
                return distance <= radius
            }

            if !filteredItems.isEmpty {
                foundResults = filteredItems
                break
            }
        }

        self.results = foundResults

        /// Zoom to show both user location and all search results
        if !self.results.isEmpty {
            let region = calculateRegionForResults(self.results)
            withAnimation(.smooth(duration: 0.5)) {
                cameraPosition = .region(region)
            }
        }
    }

    /// Create a region with specified radius around a center point
    func createRegion(around center: CLLocationCoordinate2D, radius: CLLocationDistance) -> MKCoordinateRegion {
        return MKCoordinateRegion(
            center: center,
            latitudinalMeters: radius * 2,
            longitudinalMeters: radius * 2
        )
    }

    /// Calculate a region that encompasses user location and all search results
    func calculateRegionForResults(_ mapItems: [MKMapItem]) -> MKCoordinateRegion {
        guard !mapItems.isEmpty else {
            return viewModel.region
        }

        // Start with user's location
        let userLat = viewModel.region.center.latitude
        let userLon = viewModel.region.center.longitude
        var minLat = userLat
        var maxLat = userLat
        var minLon = userLon
        var maxLon = userLon

        // Expand bounds to include all search results
        for item in mapItems {
            let coordinate = item.placemark.coordinate
            minLat = min(minLat, coordinate.latitude)
            maxLat = max(maxLat, coordinate.latitude)
            minLon = min(minLon, coordinate.longitude)
            maxLon = max(maxLon, coordinate.longitude)
        }

        // Calculate center and span with padding
        let centerLat = (minLat + maxLat) / 2
        let centerLon = (minLon + maxLon) / 2
        let spanLat = (maxLat - minLat) * 1.3 // Add 30% padding
        let spanLon = (maxLon - minLon) * 1.3

        // Ensure minimum span for visibility
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
