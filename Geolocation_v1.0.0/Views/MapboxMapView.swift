//
//  MapboxMapView.swift
//  Geolocation_v1.0.0
//
//  Hybrid map screen: renders the interactive map with Mapbox while keeping
//  MapKit (MKLocalSearch) for place/store search. This is a drop-in
//  replacement for `MapView` — same initializer signature.
//
//  IMPORTANT — graceful fallback:
//  The entire Mapbox rendering path is behind `#if canImport(MapboxMaps)` AND a
//  runtime token check. Until the MapboxMaps SDK is added via Swift Package
//  Manager (see MAPBOX_SETUP.md) and a `MAPBOX_ACCESS_TOKEN` is set in
//  Secrets.xcconfig, this view simply renders the existing MapKit `MapView`.
//  That means the project keeps building and the app keeps working today,
//  and it auto-switches to Mapbox the moment the SDK + token are present.
//
//  NOTE: The Mapbox code targets MapboxMaps v11 (SwiftUI API). It could not be
//  compiled in the environment it was written in — verify the build in Xcode
//  after adding the package, and pin to a v11.x release.
//

import SwiftUI
import MapKit
import Contacts

// MARK: - Mapbox configuration helper

enum MapboxConfig {
    /// The public access token, surfaced from Secrets.xcconfig via Info.plist (MBXAccessToken).
    static var accessToken: String? {
        guard let token = Bundle.main.infoDictionary?["MBXAccessToken"] as? String,
              !token.isEmpty,
              token != "YOUR_MAPBOX_PUBLIC_ACCESS_TOKEN_HERE",
              token.hasPrefix("pk.")
        else { return nil }
        return token
    }

    /// True once a real Mapbox public token has been configured.
    static var hasAccessToken: Bool { accessToken != nil }
}

#if canImport(MapboxMaps)
import MapboxMaps

struct MapboxMapView: View {

    // MARK: - Bindings from parent (HomeView)
    @Binding var selectedTab: Int
    @Binding var isSearchExpanded: Bool
    @Binding var searchQuery: String
    @ObservedObject var messagesViewModel: MessagesViewModel

    var body: some View {
        // If no token is configured yet, fall back to the proven MapKit screen.
        if MapboxConfig.hasAccessToken {
            MapboxMapContainer(
                selectedTab: $selectedTab,
                isSearchExpanded: $isSearchExpanded,
                searchQuery: $searchQuery,
                messagesViewModel: messagesViewModel
            )
        } else {
            MapView(
                selectedTab: $selectedTab,
                isSearchExpanded: $isSearchExpanded,
                searchQuery: $searchQuery,
                messagesViewModel: messagesViewModel
            )
        }
    }
}

// MARK: - Mapbox-rendered map

private struct MapboxMapContainer: View {

    // MARK: - Map state
    @State private var viewport: Viewport = .followPuck(zoom: 14, bearing: .constant(0))
    @State private var viewingRegion: MKCoordinateRegion?

    // MARK: - Search state (MapKit MKLocalSearch — unchanged from MapView)
    @State private var searchText = ""
    @State private var results = [MKMapItem]()
    @State private var mapSelection: MKMapItem?
    @State private var showDetails = false
    @State private var previousSearchRegion: MKCoordinateRegion?
    @State private var searchTask: Task<Void, Never>?

    @StateObject private var viewModel: MapViewModel = .init()
    @StateObject private var storesViewModel: StoresViewModel = .init()

    // MARK: - Bindings
    @Binding var selectedTab: Int
    @Binding var isSearchExpanded: Bool
    @Binding var searchQuery: String
    @FocusState private var isSearchFocused: Bool
    @ObservedObject var messagesViewModel: MessagesViewModel

    // MARK: - Store annotations (reuses StoreClusterManager + MKLocalSearch)
    private let clusterManager = StoreClusterManager()
    @State private var storeLocations: [StoreLocation] = []
    @State private var storeSearchTask: Task<Void, Never>?
    @State private var selectedStoreLocation: StoreLocation?
    @State private var storeItemForReminders: UserStoreItem?

    var body: some View {
        Map(viewport: $viewport) {
            // User location puck
            Puck2D(bearing: .heading)

            // User's saved store locations (found via MKLocalSearch)
            ForEach(storeLocations) { storeLocation in
                ViewAnnotation(storeLocation.coordinate) {
                    StoreIconView(
                        storeName: storeLocation.userStoreItem.store.name,
                        reminderCount: storeLocation.userStoreItem.store.reminderCount
                    )
                    .onTapGesture {
                        mapSelection = nil
                        selectedStoreLocation = storeLocation
                    }
                }
            }

            // Search results
            ForEach(results, id: \.self) { item in
                ViewAnnotation(item.placemark.coordinate) {
                    SearchResultPinView(name: item.placemark.name ?? "Location")
                        .onTapGesture {
                            mapSelection = item
                        }
                }
            }
        }
        .mapStyle(.standard)
        .ignoresSafeArea()
        .onCameraChanged { changed in
            let region = approximateRegion(
                center: changed.cameraState.center,
                zoom: changed.cameraState.zoom
            )
            viewingRegion = region
            updateClustering(for: region)
            handleAutoSearch(for: region)
        }
        .overlay(alignment: .bottomTrailing) {
            recenterButton
        }
        .overlay(alignment: .bottom) {
            customTabBar
        }
        .sheet(isPresented: $showDetails, onDismiss: {
            selectedStoreLocation = nil
            mapSelection = nil
        }, content: {
            LocationDetailsView(
                mapSelection: effectiveMapSelectionBinding,
                show: $showDetails,
                viewModel: storesViewModel,
                onViewReminders: { userStoreItem in
                    storeItemForReminders = userStoreItem
                }
            )
            .presentationDetents([.height(340)])
            .presentationBackgroundInteraction(.enabled(upThrough: .height(340)))
            .presentationCornerRadius(25)
        })
        .sheet(item: $storeItemForReminders) { userStoreItem in
            NavigationStack {
                ReminderView(
                    userStoreItem: userStoreItem,
                    availableStores: storesViewModel.userStoreItems.filter { $0.id != userStoreItem.id }
                )
            }
        }
        .onChange(of: searchQuery) { _, newValue in
            searchText = newValue
            if newValue.isEmpty {
                results.removeAll(keepingCapacity: false)
                previousSearchRegion = nil
                searchTask?.cancel()
            }
        }
        .onChange(of: isSearchExpanded) { _, newValue in
            if !newValue {
                // Clear search when collapsed
                searchText = ""
                searchQuery = ""
                results.removeAll(keepingCapacity: false)
                showDetails = false
                previousSearchRegion = nil
                searchTask?.cancel()
                // Resume following the user
                withAnimation(.easeInOut) {
                    viewport = .followPuck(zoom: 14, bearing: .constant(0))
                }
            }
        }
        .onChange(of: mapSelection) { _, newValue in
            if selectedStoreLocation == nil {
                showDetails = newValue != nil
            }
            if newValue != nil {
                isSearchFocused = false
                selectedStoreLocation = nil
            }
        }
        .onChange(of: selectedStoreLocation) { _, newValue in
            if newValue != nil {
                showDetails = true
            }
        }
        .onAppear {
            storesViewModel.fetchUserStores()
            if let region = viewingRegion {
                updateClustering(for: region)
            }
        }
        .onChange(of: storesViewModel.userStoreItems) { _, _ in
            if let region = viewingRegion {
                updateClustering(for: region)
            }
        }
    }

    // MARK: - Recenter button

    private var recenterButton: some View {
        Button {
            withAnimation(.easeInOut) {
                viewport = .followPuck(zoom: 14, bearing: .constant(0))
            }
        } label: {
            Image(systemName: "location.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.blue)
                .frame(width: 44, height: 44)
                .background(.ultraThinMaterial)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
        }
        .padding()
        .padding(.bottom, 60) // Make room for custom tab bar
    }

    // MARK: - Custom tab bar (mirrors MapView's UX)

    private var customTabBar: some View {
        HStack(spacing: 0) {
            HStack(spacing: 12) {
                tabButton(index: 0, system: "storefront", title: "Stores")
                messagesTabButton
                tabButton(index: 2, system: "person.2", title: "Friends")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 25))

            Spacer()

            HStack(spacing: 0) {
                if isSearchExpanded {
                    TextField("Search places...", text: $searchQuery)
                        .textFieldStyle(PlainTextFieldStyle())
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .focused($isSearchFocused)
                        .onSubmit {
                            if !searchQuery.isEmpty {
                                if let region = viewingRegion {
                                    previousSearchRegion = region
                                }
                                Task { await searchPlaces() }
                            }
                            isSearchFocused = false
                        }
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }

                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        if isSearchExpanded && !searchQuery.isEmpty {
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
                } label: {
                    Image(systemName: isSearchExpanded && !searchQuery.isEmpty ? "xmark" : "magnifyingglass")
                        .font(.system(size: 20))
                        .foregroundColor(.primary)
                        .frame(width: 44, height: 44)
                }
                .tutorialHighlight(id: "tutorial_mapSearch")
            }
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 25))
            .frame(maxWidth: isSearchExpanded ? .infinity : 44)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isSearchExpanded)
    }

    private func tabButton(index: Int, system: String, title: String) -> some View {
        Button {
            withAnimation(.spring(response: 0.3)) {
                selectedTab = index
                if isSearchExpanded {
                    isSearchExpanded = false
                    searchQuery = ""
                }
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: system).font(.system(size: 20))
                Text(title).font(.system(size: 11))
            }
            .foregroundColor(selectedTab == index ? .blue : .primary)
            .frame(width: 60, height: 50)
        }
    }

    private var messagesTabButton: some View {
        Button {
            withAnimation(.spring(response: 0.3)) {
                selectedTab = 1
                if isSearchExpanded {
                    isSearchExpanded = false
                    searchQuery = ""
                }
            }
        } label: {
            VStack(spacing: 4) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "message").font(.system(size: 20))
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
                Text("Messages").font(.system(size: 11))
            }
            .foregroundColor(selectedTab == 1 ? .blue : .primary)
            .frame(width: 60, height: 50)
        }
    }
}

// MARK: - Search / clustering logic (ported from MapView, MKLocalSearch-based)

private extension MapboxMapContainer {

    /// Binding that returns either the selected store location or the search result selection.
    var effectiveMapSelectionBinding: Binding<MKMapItem?> {
        Binding(
            get: {
                if let storeLocation = selectedStoreLocation {
                    let placemark = MKPlacemark(coordinate: storeLocation.coordinate)
                    let mapItem = MKMapItem(placemark: placemark)
                    mapItem.name = storeLocation.placeName
                    return mapItem
                }
                return mapSelection
            },
            set: { newValue in
                if newValue == nil {
                    selectedStoreLocation = nil
                    mapSelection = nil
                }
            }
        )
    }

    /// Convert a Mapbox camera (center + zoom) into an approximate MKCoordinateRegion
    /// using the Web Mercator meters-per-pixel formula, so the existing MKLocalSearch
    /// logic can be reused unchanged.
    func approximateRegion(center: CLLocationCoordinate2D, zoom: CGFloat) -> MKCoordinateRegion {
        let widthPx = Double(UIScreen.main.bounds.width)
        let heightPx = Double(UIScreen.main.bounds.height)
        let latRad = center.latitude * .pi / 180
        // 156543.03392 m/px is the equatorial resolution at zoom 0 for 256px tiles.
        let metersPerPx = 156543.03392 * cos(latRad) / pow(2.0, Double(zoom))
        let spanMetersX = max(metersPerPx * widthPx, 100)
        let spanMetersY = max(metersPerPx * heightPx, 100)
        return MKCoordinateRegion(
            center: center,
            latitudinalMeters: spanMetersY,
            longitudinalMeters: spanMetersX
        )
    }

    /// Re-run nearby store search when the camera changes (debounced).
    func updateClustering(for region: MKCoordinateRegion) {
        guard !showDetails && selectedStoreLocation == nil else { return }
        storeSearchTask?.cancel()
        storeSearchTask = Task {
            try? await Task.sleep(nanoseconds: 600_000_000)
            guard !Task.isCancelled else { return }
            guard !showDetails && selectedStoreLocation == nil else { return }

            clusterManager.searchNearbyStores(storesViewModel.userStoreItems, in: region) { locations in
                guard !showDetails && selectedStoreLocation == nil else { return }
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

    /// Auto-search as the user pans/zooms while a search is active (debounced).
    func handleAutoSearch(for currentRegion: MKCoordinateRegion) {
        guard !searchText.isEmpty && isSearchExpanded else { return }

        var shouldSearch = false
        if let previousRegion = previousSearchRegion {
            let centerLatChange = abs(currentRegion.center.latitude - previousRegion.center.latitude)
            let centerLonChange = abs(currentRegion.center.longitude - previousRegion.center.longitude)
            let spanLatChange = abs(currentRegion.span.latitudeDelta - previousRegion.span.latitudeDelta) / previousRegion.span.latitudeDelta
            let spanLonChange = abs(currentRegion.span.longitudeDelta - previousRegion.span.longitudeDelta) / previousRegion.span.longitudeDelta

            let centerMoved = (centerLatChange > currentRegion.span.latitudeDelta * 0.2) ||
                              (centerLonChange > currentRegion.span.longitudeDelta * 0.2)
            let zoomChanged = (spanLatChange > 0.15) || (spanLonChange > 0.15)
            shouldSearch = centerMoved || zoomChanged
        } else {
            previousSearchRegion = currentRegion
        }

        guard shouldSearch else { return }
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 800_000_000)
            if !Task.isCancelled {
                await searchPlaces()
                await MainActor.run { previousSearchRegion = currentRegion }
            }
        }
    }

    /// MKLocalSearch over the visible region with progressively larger radii.
    func searchPlaces() async {
        let searchCenter: CLLocationCoordinate2D
        let baseRegion: MKCoordinateRegion
        if let currentRegion = viewingRegion {
            searchCenter = currentRegion.center
            baseRegion = currentRegion
        } else {
            searchCenter = viewModel.region.center
            baseRegion = viewModel.region
        }

        let visibleRadius = max(
            baseRegion.span.latitudeDelta * 111000,
            baseRegion.span.longitudeDelta * 111000 * cos(searchCenter.latitude * .pi / 180)
        ) / 2

        let radiusMultipliers: [Double] = [1.0, 1.5, 2.0, 3.0, 5.0]
        var foundResults: [MKMapItem] = []
        let centerLocation = CLLocation(latitude: searchCenter.latitude, longitude: searchCenter.longitude)

        for multiplier in radiusMultipliers {
            let searchRadius = visibleRadius * multiplier
            let searchRegion = MKCoordinateRegion(
                center: searchCenter,
                latitudinalMeters: searchRadius * 2,
                longitudinalMeters: searchRadius * 2
            )

            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = searchText
            request.region = searchRegion

            let response = try? await MKLocalSearch(request: request).start()
            let items = response?.mapItems ?? []
            let filtered = items.filter { item in
                let loc = CLLocation(latitude: item.placemark.coordinate.latitude,
                                     longitude: item.placemark.coordinate.longitude)
                return centerLocation.distance(from: loc) <= searchRadius
            }
            if !filtered.isEmpty {
                foundResults = filtered
                break
            }
        }

        results = foundResults

        // Frame the results on the first explicit search only.
        if !results.isEmpty && previousSearchRegion == nil {
            let coords = results.map { $0.placemark.coordinate }
            if let first = coords.first {
                var minLat = first.latitude, maxLat = first.latitude
                var minLon = first.longitude, maxLon = first.longitude
                for c in coords {
                    minLat = min(minLat, c.latitude); maxLat = max(maxLat, c.latitude)
                    minLon = min(minLon, c.longitude); maxLon = max(maxLon, c.longitude)
                }
                let center = CLLocationCoordinate2D(
                    latitude: (minLat + maxLat) / 2,
                    longitude: (minLon + maxLon) / 2
                )
                withAnimation(.easeInOut) {
                    viewport = .camera(center: center, zoom: 13)
                }
            }
        }
    }
}

#else

// MARK: - Fallback when the MapboxMaps SDK has not been added yet
//
// Keeps the project compiling and the app fully functional on MapKit until you
// add the MapboxMaps Swift Package (see MAPBOX_SETUP.md).

struct MapboxMapView: View {
    @Binding var selectedTab: Int
    @Binding var isSearchExpanded: Bool
    @Binding var searchQuery: String
    @ObservedObject var messagesViewModel: MessagesViewModel

    var body: some View {
        MapView(
            selectedTab: $selectedTab,
            isSearchExpanded: $isSearchExpanded,
            searchQuery: $searchQuery,
            messagesViewModel: messagesViewModel
        )
    }
}

#endif
