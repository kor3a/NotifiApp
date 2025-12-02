//
//  MapView.swift
//  Geolocation_v1.0.0
//
//  Created by Subong Jeon on 9/7/24.
//

import SwiftUI
import MapKit
import Contacts

struct MapView: View {

    // MARK: - PROPERTIES

    @State private var cameraPosition: MapCameraPosition = .userLocation(followsHeading: false, fallback: .automatic)
    @State private var viewingRegion: MKCoordinateRegion?
    @State private var searchText = ""
    @State private var results = [MKMapItem]()
    @State private var mapSelection: MKMapItem?
    @State private var showDetails = false
    @State private var wasTrackingBeforeSearch = true // Track if we were in userLocation mode before search opened
    @State private var previousRegionSpan: MKCoordinateSpan?
    @State private var searchTask: Task<Void, Never>?
    @Namespace private var mapScope

    @StateObject private var viewModel:MapViewModel = .init()
    @StateObject private var storesViewModel: StoresViewModel = .init()

    // Bindings to control from parent (HomeView)
    @Binding var selectedTab: Int
    @Binding var isSearchExpanded: Bool
    @Binding var searchQuery: String
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        Map(position: $cameraPosition, selection: $mapSelection, scope: mapScope){
            UserAnnotation()

            // User's saved stores
            ForEach(storesViewModel.userStoreItems) { userStoreItem in
                if let latitude = userStoreItem.store.latitude,
                   let longitude = userStoreItem.store.longitude {
                    let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
                    Marker(userStoreItem.store.name, systemImage: "storefront.fill", coordinate: coordinate)
                        .tint(.blue)
                        .tag(createMapItemForStore(userStoreItem.store, coordinate: coordinate))
                }
            }

            // Search results
            ForEach(results, id: \.self) { item in
                let placemark = item.placemark
                Marker(placemark.name ?? "", coordinate: placemark.coordinate)
            }
        }//:MAP
        .onMapCameraChange(frequency: .continuous) { context in
            viewingRegion = context.region

            // Auto-search when zooming out if there's an active search
            if !searchText.isEmpty && isSearchExpanded {
                let currentSpan = context.region.span

                // Check if user zoomed out (span increased by at least 20%)
                if let previousSpan = previousRegionSpan {
                    let latitudeIncrease = currentSpan.latitudeDelta / previousSpan.latitudeDelta
                    let longitudeIncrease = currentSpan.longitudeDelta / previousSpan.longitudeDelta
                    let zoomChange = max(latitudeIncrease, longitudeIncrease)

                    // If zoomed out significantly, trigger a new search after a delay
                    if zoomChange > 1.2 {
                        // Cancel any pending search task
                        searchTask?.cancel()

                        // Debounce: wait 0.5 seconds before searching
                        searchTask = Task {
                            try? await Task.sleep(nanoseconds: 500_000_000)

                            if !Task.isCancelled {
                                await searchPlaces()
                            }
                        }
                    }
                }

                previousRegionSpan = currentSpan
            }
        }
        .overlay(alignment: .bottomTrailing) {
            VStack(spacing: 15){
                MapPitchToggle(scope: mapScope)
                MapUserLocationButton(scope: mapScope)
            }//:VSTACK
            .buttonBorderShape(.circle)
            .padding()
            .padding(.bottom, 60) // Make room for custom tab bar
        }
        .overlay(alignment: .bottom) {
            customTabBar
        }
        .mapScope(mapScope)
        .sheet(isPresented: $showDetails, content: {
            LocationDetailsView(mapSelection: $mapSelection, show: $showDetails, viewModel: storesViewModel)
                .presentationDetents([.height(340)])
                .presentationBackgroundInteraction(.enabled(upThrough: .height(340)))
                .presentationCornerRadius(25)
        })
        .onChange(of: searchQuery) { oldValue, newValue in
            searchText = newValue

            // Clear results if search is empty
            if newValue.isEmpty {
                results.removeAll(keepingCapacity: false)
                previousRegionSpan = nil
                searchTask?.cancel()
            }
        }
        .onChange(of: isSearchExpanded) { oldValue, newValue in
            if newValue {
                // When search expands, pause user location tracking to prevent interference with keyboard
                // Save current tracking state before switching
                wasTrackingBeforeSearch = String(describing: cameraPosition).contains("userLocation")

                // Switch to fixed region to stop continuous tracking
                if let region = viewingRegion {
                    cameraPosition = .region(region)
                }
            } else {
                // Clear search when collapsed
                searchText = ""
                searchQuery = ""
                results.removeAll(keepingCapacity: false)
                showDetails = false
                previousRegionSpan = nil
                searchTask?.cancel()
                // Restore user location tracking if it was active before search opened
                if wasTrackingBeforeSearch {
                    cameraPosition = .userLocation(followsHeading: false, fallback: .automatic)
                } else {
                    withAnimation(.snappy) {
                        cameraPosition = .region(viewModel.region)
                    }
                }
            }
        }
        .onChange(of: mapSelection, { oldValue, newValue in
            showDetails = newValue != nil
            // Dismiss keyboard when a pin is tapped
            if newValue != nil {
                isSearchFocused = false
            }
        })
        .onAppear {
            // Fetch user's stores when view appears
            storesViewModel.fetchUserStores()
        }
    }

    // MARK: - CUSTOM TAB BAR

    private var customTabBar: some View {
        HStack(spacing: 0) {
            // Left side: Tab items
            HStack(spacing: 12) {
                // Stores tab
                Button(action: {
                    withAnimation(.spring(response: 0.3)) {
                        selectedTab = 0
                        // Close search when switching tabs
                        if isSearchExpanded {
                            isSearchExpanded = false
                            searchQuery = ""
                        }
                    }
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: "storefront")
                            .font(.system(size: 20))
                        Text("Stores")
                            .font(.system(size: 11))
                    }
                    .foregroundColor(selectedTab == 0 ? .blue : .primary)
                    .frame(width: 60, height: 50)
                }

                // Map tab
                Button(action: {
                    withAnimation(.spring(response: 0.3)) {
                        selectedTab = 1
                    }
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: "map")
                            .font(.system(size: 20))
                        Text("Search")
                            .font(.system(size: 11))
                    }
                    .foregroundColor(selectedTab == 1 ? .blue : .primary)
                    .frame(width: 60, height: 50)
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
                    TextField("Search places...", text: $searchQuery)
                        .textFieldStyle(PlainTextFieldStyle())
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .focused($isSearchFocused)
                        .onSubmit {
                            if !searchQuery.isEmpty {
                                // Initialize region tracking for auto-search on zoom
                                if let region = viewingRegion {
                                    previousRegionSpan = region.span
                                }
                                Task {
                                    await searchPlaces()
                                }
                            }
                            isSearchFocused = false
                        }
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }

                Button(action: {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        if isSearchExpanded && !searchQuery.isEmpty {
                            // Clear search
                            searchQuery = ""
                        }
                        isSearchExpanded.toggle()
                        if isSearchExpanded {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                isSearchFocused = true
                            }
                        } else {
                            isSearchFocused = false
                        }
                    }
                }) {
                    Image(systemName: isSearchExpanded && !searchQuery.isEmpty ? "xmark" : "magnifyingglass")
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
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isSearchExpanded)
    }
}

extension MapView {
    /// Create an MKMapItem from a Store for map selection
    func createMapItemForStore(_ store: Store, coordinate: CLLocationCoordinate2D) -> MKMapItem {
        let placemark = MKPlacemark(coordinate: coordinate, addressDictionary: [
            CNPostalAddressStreetKey: store.address
        ])
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = store.name
        return mapItem
    }

    func searchPlaces() async {
        // Use the current viewing region if available, otherwise use user location
        let searchCenter: CLLocationCoordinate2D
        let baseRegion: MKCoordinateRegion

        if let currentRegion = viewingRegion {
            searchCenter = currentRegion.center
            baseRegion = currentRegion
        } else {
            searchCenter = viewModel.region.center
            baseRegion = viewModel.region
        }

        // Calculate search radius based on visible region with padding multipliers
        let visibleRadius = max(
            baseRegion.span.latitudeDelta * 111000, // Convert degrees to meters (roughly)
            baseRegion.span.longitudeDelta * 111000 * cos(searchCenter.latitude * .pi / 180)
        ) / 2

        // Search with progressively larger areas: 1x, 1.5x, 2x, 3x, 5x the visible region
        let radiusMultipliers: [Double] = [1.0, 1.5, 2.0, 3.0, 5.0]
        var foundResults: [MKMapItem] = []
        let centerLocation = CLLocation(latitude: searchCenter.latitude, longitude: searchCenter.longitude)

        // Try each radius until we find results
        for multiplier in radiusMultipliers {
            let searchRadius = visibleRadius * multiplier
            let searchRegion = createRegion(around: searchCenter, radius: searchRadius)

            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = self.searchText
            request.region = searchRegion

            let results = try? await MKLocalSearch(request: request).start()
            let items = results?.mapItems ?? []

            // Filter results to only include items within the current search radius
            let filteredItems = items.filter { item in
                let itemLocation = CLLocation(latitude: item.placemark.coordinate.latitude,
                                             longitude: item.placemark.coordinate.longitude)
                let distance = centerLocation.distance(from: itemLocation)
                return distance <= searchRadius
            }

            if !filteredItems.isEmpty {
                foundResults = filteredItems
                break
            }
        }

        self.results = foundResults

        /// Only zoom to show results on initial search (not when auto-searching on zoom)
        /// This prevents the map from jumping when user is exploring
        if !self.results.isEmpty && previousRegionSpan == nil {
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
    MapView(selectedTab: .constant(1), isSearchExpanded: .constant(false), searchQuery: .constant(""))
}
