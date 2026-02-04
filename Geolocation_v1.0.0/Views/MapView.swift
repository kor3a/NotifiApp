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
    @State private var previousSearchRegion: MKCoordinateRegion?
    @State private var searchTask: Task<Void, Never>?
    @Namespace private var mapScope

    @StateObject private var viewModel:MapViewModel = .init()
    @StateObject private var storesViewModel: StoresViewModel = .init()

    // Bindings to control from parent (HomeView)
    @Binding var selectedTab: Int
    @Binding var isSearchExpanded: Bool
    @Binding var searchQuery: String
    @FocusState private var isSearchFocused: Bool

    // Messages view model for unread badge
    @ObservedObject var messagesViewModel: MessagesViewModel

    // Store location search
    private let clusterManager = StoreClusterManager()
    @State private var clusteredAnnotations: [StoreAnnotation] = []
    @State private var storeLocations: [StoreLocation] = []
    @State private var storeSearchTask: Task<Void, Never>?

    var body: some View {
        Map(position: $cameraPosition, selection: $mapSelection, scope: mapScope){
            UserAnnotation()

            // User's saved store locations (found via search)
            ForEach(storeLocations) { storeLocation in
                Annotation("", coordinate: storeLocation.coordinate) {
                    StoreIconView(storeName: storeLocation.userStoreItem.store.name)
                        .onTapGesture {
                            mapSelection = createMapItemForStoreLocation(storeLocation)
                        }
                }
                .annotationTitles(.hidden)
            }

            // Search results with modern pins
            ForEach(results, id: \.self) { item in
                let placemark = item.placemark
                Annotation(placemark.name ?? "", coordinate: placemark.coordinate) {
                    SearchResultPinView(name: placemark.name ?? "Location")
                        .onTapGesture {
                            mapSelection = item
                        }
                }
                .annotationTitles(.hidden)
            }
        }//:MAP
        .onMapCameraChange(frequency: .continuous) { context in
            viewingRegion = context.region

            // Update clustering based on new region
            updateClustering(for: context.region)

            // Auto-search when map view changes if there's an active search
            if !searchText.isEmpty && isSearchExpanded {
                let currentRegion = context.region

                // Check if the map view has changed significantly
                var shouldSearch = false

                if let previousRegion = previousSearchRegion {
                    // Calculate how much the center has moved (in degrees)
                    let centerLatChange = abs(currentRegion.center.latitude - previousRegion.center.latitude)
                    let centerLonChange = abs(currentRegion.center.longitude - previousRegion.center.longitude)

                    // Calculate how much the zoom has changed
                    let spanLatChange = abs(currentRegion.span.latitudeDelta - previousRegion.span.latitudeDelta) / previousRegion.span.latitudeDelta
                    let spanLonChange = abs(currentRegion.span.longitudeDelta - previousRegion.span.longitudeDelta) / previousRegion.span.longitudeDelta

                    // Trigger search if:
                    // 1. Center moved by more than 20% of the current visible span, OR
                    // 2. Zoom level changed by more than 15%
                    let centerMovedSignificantly = (centerLatChange > currentRegion.span.latitudeDelta * 0.2) ||
                                                   (centerLonChange > currentRegion.span.longitudeDelta * 0.2)
                    let zoomChangedSignificantly = (spanLatChange > 0.15) || (spanLonChange > 0.15)

                    shouldSearch = centerMovedSignificantly || zoomChangedSignificantly
                } else {
                    // First time tracking, don't search yet
                    previousSearchRegion = currentRegion
                }

                if shouldSearch {
                    // Cancel any pending search task
                    searchTask?.cancel()

                    // Debounce: wait 0.8 seconds before searching to allow smooth panning
                    searchTask = Task {
                        try? await Task.sleep(nanoseconds: 800_000_000)

                        if !Task.isCancelled {
                            await searchPlaces()
                            // Update the region after successful search
                            await MainActor.run {
                                previousSearchRegion = currentRegion
                            }
                        }
                    }
                }
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
                previousSearchRegion = nil
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
                previousSearchRegion = nil
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
            // Initial clustering
            if let region = viewingRegion {
                updateClustering(for: region)
            }
        }
        .onChange(of: storesViewModel.userStoreItems) { oldValue, newValue in
            // Update clustering when stores change
            if let region = viewingRegion {
                updateClustering(for: region)
            }
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

                // Messages tab
                Button(action: {
                    withAnimation(.spring(response: 0.3)) {
                        selectedTab = 1
                        // Close search when switching tabs
                        if isSearchExpanded {
                            isSearchExpanded = false
                            searchQuery = ""
                        }
                    }
                }) {
                    VStack(spacing: 4) {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "message")
                                .font(.system(size: 20))
                            // Unread badge
                            if messagesViewModel.totalUnreadCount > 0 {
                                Text("\(messagesViewModel.totalUnreadCount)")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(Color.red)
                                    .clipShape(Capsule())
                                    .offset(x: 10, y: -8)
                            }
                        }
                        Text("Messages")
                            .font(.system(size: 11))
                    }
                    .foregroundColor(selectedTab == 1 ? .blue : .primary)
                    .frame(width: 60, height: 50)
                }

                // Map tab
                Button(action: {
                    withAnimation(.spring(response: 0.3)) {
                        selectedTab = 2
                    }
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: "map")
                            .font(.system(size: 20))
                        Text("Search")
                            .font(.system(size: 11))
                    }
                    .foregroundColor(selectedTab == 2 ? .blue : .primary)
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
                                // Initialize region tracking for auto-search on map changes
                                if let region = viewingRegion {
                                    previousSearchRegion = region
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
    /// Search for nearby store locations based on current map region
    func updateClustering(for region: MKCoordinateRegion) {
        // Cancel any existing search task
        storeSearchTask?.cancel()

        // Debounce the search to avoid too many requests
        storeSearchTask = Task {
            // Wait a bit to allow for smooth panning
            try? await Task.sleep(nanoseconds: 300_000_000)

            guard !Task.isCancelled else { return }

            // Search for nearby stores
            clusterManager.searchNearbyStores(storesViewModel.userStoreItems, in: region) { locations in
                // Only update if locations changed
                let newIds = Set(locations.map { $0.id })
                let currentIds = Set(storeLocations.map { $0.id })

                if newIds != currentIds {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        storeLocations = locations
                    }
                }
            }
        }
    }

    /// Create an MKMapItem from a StoreLocation for map selection
    func createMapItemForStoreLocation(_ storeLocation: StoreLocation) -> MKMapItem {
        let placemark = MKPlacemark(coordinate: storeLocation.coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = storeLocation.placeName
        return mapItem
    }

    /// Create an MKMapItem from a Store for map selection
    func createMapItemForStore(_ store: Store, coordinate: CLLocationCoordinate2D) -> MKMapItem {
        let placemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = store.name
        return mapItem
    }

    /// Create an MKMapItem from a cluster for map selection
    func createMapItemForCluster(_ stores: [UserStoreItem], coordinate: CLLocationCoordinate2D) -> MKMapItem {
        let placemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = "Cluster of \(stores.count) stores"
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

        /// Only zoom to show results on initial search (not when auto-searching)
        /// This prevents the map from jumping when user is exploring
        if !self.results.isEmpty && previousSearchRegion == nil {
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

// MARK: - Store Icon View (First Letter Circle)

struct StoreIconView: View {
    let storeName: String
    @State private var isAnimating = false

    private var firstLetter: String {
        let letter = storeName.prefix(1).uppercased()
        return letter.isEmpty ? "?" : letter
    }

    private var storeColor: Color {
        // Generate a consistent color based on store name
        let hash = abs(storeName.hashValue)
        let colors: [Color] = [
            .blue, .green, .orange, .purple, .pink, .teal, .indigo, .cyan
        ]
        return colors[hash % colors.count]
    }

    var body: some View {
        ZStack {
            // Outer glow for visibility
            Circle()
                .fill(storeColor.opacity(0.3))
                .frame(width: 36, height: 36)

            // Main circle with gradient
            Circle()
                .fill(
                    LinearGradient(
                        colors: [storeColor, storeColor.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 28, height: 28)
                .shadow(color: Color.black.opacity(0.25), radius: 3, x: 0, y: 2)

            // Inner highlight for 3D effect
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.4), Color.clear],
                        startPoint: .topLeading,
                        endPoint: .center
                    )
                )
                .frame(width: 24, height: 24)
                .offset(x: -2, y: -2)

            // First letter
            Text(firstLetter)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(.white)
        }
        .scaleEffect(isAnimating ? 1.0 : 0.5)
        .opacity(isAnimating ? 1.0 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                isAnimating = true
            }
        }
    }
}

// MARK: - Modern Search Result Pin

struct SearchResultPinView: View {
    let name: String
    @State private var isAnimating = false

    var body: some View {
        VStack(spacing: 0) {
            // Pin head with gradient and icon
            ZStack {
                // Outer glow/shadow circle
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.orange.opacity(0.3), Color.clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 24
                        )
                    )
                    .frame(width: 48, height: 48)

                // Main pin circle with gradient
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.orange, Color.red.opacity(0.85)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 38, height: 38)
                    .shadow(color: Color.black.opacity(0.25), radius: 4, x: 0, y: 3)

                // Inner highlight for 3D effect
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.4), Color.clear],
                            startPoint: .topLeading,
                            endPoint: .center
                        )
                    )
                    .frame(width: 34, height: 34)
                    .offset(x: -3, y: -3)

                // Location icon
                Image(systemName: "mappin")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
            }

            // Pin pointer/tail
            Triangle()
                .fill(
                    LinearGradient(
                        colors: [Color.red.opacity(0.85), Color.red.opacity(0.7)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 14, height: 10)
                .offset(y: -3)
                .shadow(color: Color.black.opacity(0.2), radius: 2, x: 0, y: 2)

            // Name label
            Text(name)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.primary)
                .lineLimit(1)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .shadow(color: Color.black.opacity(0.15), radius: 3, x: 0, y: 2)
                )
                .offset(y: 4)
        }
        .scaleEffect(isAnimating ? 1.0 : 0.5)
        .opacity(isAnimating ? 1.0 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                isAnimating = true
            }
        }
    }
}

// Triangle shape for pin pointer
struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

#Preview {
    MapView(selectedTab: .constant(2), isSearchExpanded: .constant(false), searchQuery: .constant(""), messagesViewModel: MessagesViewModel())
}

#Preview("Search Pin") {
    ZStack {
        Color.gray.opacity(0.3)
        SearchResultPinView(name: "Coffee Shop")
    }
}

#Preview("Store Icon") {
    ZStack {
        Color.gray.opacity(0.3)
        HStack(spacing: 20) {
            StoreIconView(storeName: "Walmart")
            StoreIconView(storeName: "Target")
            StoreIconView(storeName: "Costco")
            StoreIconView(storeName: "Best Buy")
        }
    }
}
