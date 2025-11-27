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
    @State private var showDetails = false
    @State private var isUserLocationTracking = true // Track if we're in userLocation mode
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

            ForEach(results, id: \.self) { item in
                let placemark = item.placemark
                Marker(placemark.name ?? "", coordinate: placemark.coordinate)
            }
        }//:MAP
        .onMapCameraChange({ ctx in
            viewingRegion = ctx.region
            // Only dismiss keyboard when user manually interacts with map (panning/zooming)
            // Don't dismiss for programmatic changes (location button, search results)
            if isSearchFocused && ctx.reason == .gesture {
                isSearchFocused = false
            }
        })
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
            if !newValue.isEmpty {
                Task {
                    await searchPlaces()
                }
            }
        }
        .onChange(of: isSearchExpanded) { oldValue, newValue in
            if newValue {
                // When search expands, pause user location tracking to prevent interference with keyboard
                if case .userLocation = cameraPosition {
                    isUserLocationTracking = true
                    // Switch to fixed region to stop continuous tracking
                    if let region = viewingRegion {
                        cameraPosition = .region(region)
                    }
                }
            } else {
                // Clear search when collapsed
                searchText = ""
                searchQuery = ""
                results.removeAll(keepingCapacity: false)
                showDetails = false
                // Restore user location tracking if it was active before
                if isUserLocationTracking {
                    cameraPosition = .userLocation(fallback: .automatic)
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
        .onChange(of: cameraPosition) { oldValue, newValue in
            // Track when user manually toggles location tracking via MapUserLocationButton
            // (but don't track changes we made programmatically for search)
            if !isSearchExpanded {
                if case .userLocation = newValue {
                    isUserLocationTracking = true
                } else if case .region = newValue {
                    isUserLocationTracking = false
                }
            }
        }
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
    MapView(selectedTab: .constant(1), isSearchExpanded: .constant(false), searchQuery: .constant(""))
}
