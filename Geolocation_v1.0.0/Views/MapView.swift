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
    // The Map's own selection binding. Kept so MapKit renders and handles the
    // annotations exactly as before, but it is NOT used to drive the details
    // sheet — see `selectedSearchItem` below.
    @State private var mapSelection: MKMapItem?
    // Dedicated state for a tapped search-result pin that drives the details
    // sheet. This intentionally does NOT rely on the Map's `selection:` binding:
    // custom `Annotation`s aren't registered as selectable, so MapKit writes
    // `nil` back into its selection on the next update (e.g. when the continuous
    // camera change rebuilds the `results` array as the sheet resizes the map) —
    // which was instantly dismissing the sheet. Managing our own state decouples
    // the sheet from MapKit's selection lifecycle, exactly like
    // `selectedStoreLocation` already does for stores.
    @State private var selectedSearchItem: MKMapItem?
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
    @Environment(\.colorScheme) private var colorScheme

    // Messages view model for unread badge
    @ObservedObject var messagesViewModel: MessagesViewModel

    // Store location search
    // @State so the manager (and its result cache) persists across view
    // re-inits. As a plain `let` it was recreated every time the parent
    // re-rendered (e.g. on messagesViewModel updates), wiping the cache and
    // forcing a fresh MKLocalSearch for every store on each region change —
    // which tripped MKLocalSearch's rate limit and made markers vanish.
    @State private var clusterManager = StoreClusterManager()
    @State private var clusteredAnnotations: [StoreAnnotation] = []
    @State private var storeLocations: [StoreLocation] = []
    @State private var storeSearchTask: Task<Void, Never>?
    @State private var selectedStoreLocation: StoreLocation?
    @State private var storeItemForReminders: UserStoreItem?

    var body: some View {
        Map(position: $cameraPosition, selection: $mapSelection, scope: mapScope){
            UserAnnotation()

            // User's saved store locations (found via search)
            ForEach(storeLocations) { storeLocation in
                Annotation("", coordinate: storeLocation.coordinate) {
                    StoreIconView(
                        storeName: storeLocation.userStoreItem.store.name,
                        reminderCount: storeLocation.userStoreItem.store.reminderCount
                    )
                    .onTapGesture {
                        // Set selection first; onChange(of: selectedStoreLocation)
                        // will open the sheet after the state is committed.
                        mapSelection = nil       // Clear any Map selection
                        selectedSearchItem = nil // Clear any search result selection
                        selectedStoreLocation = storeLocation
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
                            // Drive the sheet from our own state (not the Map's
                            // selection binding) so a subsequent camera-change
                            // auto-search can't clear it and dismiss the sheet.
                            selectedStoreLocation = nil
                            selectedSearchItem = item
                        }
                }
                .annotationTitles(.hidden)
            }
        }//:MAP
        .simultaneousGesture(
            // Tapping the map while the search field is focused dismisses the
            // keyboard and shrinks the search bar back to the tab bar.
            // We use simultaneousGesture instead of .onTapGesture because a
            // plain tap gesture on a Map hijacks its gesture pipeline and
            // suppresses onMapCameraChange — which would stop store clustering
            // and hide all store annotations. Gating on isSearchFocused keeps
            // this from interfering with taps on search-result pins.
            TapGesture().onEnded {
                guard isSearchFocused else { return }
                // Dismiss the keyboard on a map tap. If there's text in the
                // field, keep the bar extended and its result pins on the map
                // (the user is still viewing those results) — only shrink the
                // bar back to the tab bar when the field is empty.
                isSearchFocused = false
                if searchQuery.isEmpty {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        isSearchExpanded = false
                    }
                }
            }
        )
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
            .tint(OrganicPalette.terracotta(colorScheme))
            .padding()
            .padding(.bottom, 60) // Make room for custom tab bar
        }
        .overlay(alignment: .bottom) {
            customTabBar
        }
        .mapScope(mapScope)
        .sheet(isPresented: $showDetails, onDismiss: {
            // Clear all selection sources when sheet is dismissed
            selectedStoreLocation = nil
            selectedSearchItem = nil
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
        .onChange(of: searchQuery) { oldValue, newValue in
            searchText = newValue

            // Clear results if search is empty
            if newValue.isEmpty {
                results.removeAll(keepingCapacity: false)
                previousSearchRegion = nil
                searchTask?.cancel()
                // Removing the search-result pins can leave the map blank until
                // the next camera change. Force a clustering refresh so the
                // user's saved store markers reappear immediately.
                updateClustering(for: viewingRegion ?? viewModel.region, force: true)
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
        .onChange(of: selectedSearchItem, { oldValue, newValue in
            // Only update showDetails from the search selection if we don't have
            // a store location selected
            if selectedStoreLocation == nil {
                showDetails = newValue != nil
            }
            // Dismiss keyboard when a pin is tapped
            if newValue != nil {
                isSearchFocused = false
                // Clear store location selection when selecting a search result
                selectedStoreLocation = nil
            }
        })
        .onChange(of: selectedStoreLocation) { oldValue, newValue in
            // Open the sheet AFTER selectedStoreLocation is committed so
            // the binding reads the correct value on first presentation.
            if newValue != nil {
                showDetails = true
            }
        }
        .onAppear {
            // Fetch user's stores when view appears
            storesViewModel.fetchUserStores()
            // Initial clustering. Fall back to the view model's region so we
            // can start searching before the first camera callback arrives.
            updateClustering(for: viewingRegion ?? viewModel.region, force: storeLocations.isEmpty)
        }
        .onChange(of: storesViewModel.userStoreItems) { oldValue, newValue in
            // Stores just finished loading — kick off clustering right away
            // (skip the debounce on the first batch so markers appear fast).
            updateClustering(for: viewingRegion ?? viewModel.region, force: storeLocations.isEmpty)
        }
    }

    // MARK: - CUSTOM TAB BAR

    private var customTabBar: some View {
        HStack(spacing: 0) {
            // Left side: Tab items
            HStack(spacing: 12) {
                // Stores tab
                Button(action: {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        if isSearchExpanded {
                            // Tapping the shrunk store icon restores the full tab bar
                            // by collapsing the search field.
                            isSearchExpanded = false
                            searchQuery = ""
                            isSearchFocused = false
                        } else {
                            selectedTab = 0
                        }
                    }
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: "storefront")
                            .font(.system(size: 20))
                        // Hide the label while search is expanded so the
                        // tab bar shrinks down to just the store icon.
                        if !isSearchExpanded {
                            Text("Stores")
                                .font(.system(size: 11))
                        }
                    }
                    .foregroundColor(
                        selectedTab == 0
                            ? OrganicPalette.terracotta(colorScheme)
                            : OrganicPalette.inkSoft(colorScheme)
                    )
                    .frame(width: isSearchExpanded ? 44 : 60, height: 50)
                }

                // Messages and Friends tabs collapse away while searching to
                // make room for the expanding search bar.
                if !isSearchExpanded {
                    // Messages tab
                    Button(action: {
                        withAnimation(.spring(response: 0.3)) {
                            selectedTab = 1
                        }
                    }) {
                        VStack(spacing: 4) {
                            ZStack(alignment: .topTrailing) {
                                Image(systemName: "message")
                                    .font(.system(size: 20))
                                // Unread badge
                                if messagesViewModel.totalUnreadCount > 0 {
                                    Text("\(messagesViewModel.totalUnreadCount)")
                                        .font(.system(size: 10, weight: .bold, design: .serif))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 2)
                                        .background(OrganicPalette.terracotta(colorScheme))
                                        .clipShape(Capsule())
                                        .offset(x: 10, y: -8)
                                }
                            }
                            Text("Messages")
                                .font(.system(size: 11))
                        }
                        .foregroundColor(
                            selectedTab == 1
                                ? OrganicPalette.terracotta(colorScheme)
                                : OrganicPalette.inkSoft(colorScheme)
                        )
                        .frame(width: 60, height: 50)
                    }
                    .transition(.move(edge: .leading).combined(with: .opacity))

                    // Friends tab
                    Button(action: {
                        withAnimation(.spring(response: 0.3)) {
                            selectedTab = 2
                        }
                    }) {
                        VStack(spacing: 4) {
                            Image(systemName: "person.2")
                                .font(.system(size: 20))
                            Text("Friends")
                                .font(.system(size: 11))
                        }
                        .foregroundColor(
                            selectedTab == 2
                                ? OrganicPalette.terracotta(colorScheme)
                                : OrganicPalette.inkSoft(colorScheme)
                        )
                        .frame(width: 60, height: 50)
                    }
                    .transition(.move(edge: .leading).combined(with: .opacity))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            // Paper rather than frosted glass. This bar floats over map
            // imagery, so it keeps its shadow — that is what separates it from
            // whatever is underneath, not a blur.
            .background(
                Capsule()
                    .fill(OrganicPalette.surface(colorScheme))
                    .shadow(color: OrganicPalette.shadow(colorScheme), radius: 10, x: 0, y: 4)
            )

            Spacer()

            // Right side: Search
            HStack(spacing: 0) {
                if isSearchExpanded {
                    TextField(
                        "",
                        text: $searchQuery,
                        prompt: Text("Search places\u{2026}")
                            .foregroundColor(OrganicPalette.inkSoft(colorScheme).opacity(0.8))
                    )
                        .textFieldStyle(PlainTextFieldStyle())
                        .font(.system(size: 16))
                        .foregroundColor(OrganicPalette.ink(colorScheme))
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
                                    // Explicit search: recenter so the user's
                                    // location and the top result are both visible.
                                    await searchPlaces(recenter: true)
                                }
                                isSearchFocused = false
                            } else {
                                // Pressing return with no text shrinks the
                                // search bar back to the tab bar.
                                isSearchFocused = false
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    isSearchExpanded = false
                                }
                            }
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
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(OrganicPalette.terracotta(colorScheme))
                        .frame(width: 44, height: 44)
                }
                .tutorialHighlight(id: "tutorial_mapSearch")
            }
            .background(
                Capsule()
                    .fill(OrganicPalette.surface(colorScheme))
                    .shadow(color: OrganicPalette.shadow(colorScheme), radius: 10, x: 0, y: 4)
            )
            .frame(maxWidth: isSearchExpanded ? .infinity : 44)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isSearchExpanded)
    }
}

extension MapView {
    /// Computed binding that returns either the selected store location as MKMapItem or the search result selection
    var effectiveMapSelectionBinding: Binding<MKMapItem?> {
        Binding(
            get: {
                // Prioritize store location selection over search result selection
                if let storeLocation = selectedStoreLocation {
                    return createMapItemForStoreLocation(storeLocation)
                }
                return selectedSearchItem
            },
            set: { newValue in
                if newValue == nil {
                    selectedStoreLocation = nil
                    selectedSearchItem = nil
                    mapSelection = nil
                }
            }
        )
    }

    /// Search for nearby store locations based on current map region
    /// - Parameter force: when true, skips the debounce delay and always
    ///   re-assigns `storeLocations` (even if the IDs are unchanged) so the
    ///   map re-renders markers immediately — used on first load and when
    ///   clearing the search so pins don't vanish until a manual map gesture.
    func updateClustering(for region: MKCoordinateRegion, force: Bool = false) {
        // Don't update locations while details sheet is showing or a store is selected
        guard !showDetails && selectedStoreLocation == nil else { return }

        // Cancel any existing search task
        storeSearchTask?.cancel()

        // Debounce: wait 600ms after the last camera change so we don't
        // fire dozens of MKLocalSearch requests during a pinch-to-zoom gesture.
        // A forced refresh (first load / search cleared) skips the wait.
        storeSearchTask = Task {
            if !force {
                try? await Task.sleep(nanoseconds: 600_000_000)
            }

            guard !Task.isCancelled else { return }

            // Double-check conditions haven't changed during the delay
            guard !showDetails && selectedStoreLocation == nil else { return }

            // Search for nearby stores
            clusterManager.searchNearbyStores(storesViewModel.userStoreItems, in: region) { locations in
                // Only update if locations changed and no selection is active
                guard !showDetails && selectedStoreLocation == nil else { return }

                let newIds = Set(locations.map { $0.id })
                let currentIds = Set(storeLocations.map { $0.id })

                if force || newIds != currentIds {
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

    /// - Parameter recenter: when true (an explicit, user-initiated search),
    ///   the map animates to a region framing both the user's location and the
    ///   top result pin — even if that result is outside the current view. Auto
    ///   searches (triggered by panning/zooming) pass false so the camera stays
    ///   put while the user explores.
    func searchPlaces(recenter: Bool = false) async {
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

        // Don't wipe existing result pins if an auto-search (triggered by
        // panning/zooming) comes back empty — keep the current pins on screen
        // until the user changes the query. An explicit search always updates
        // (including clearing to empty for a no-match query).
        if recenter || !foundResults.isEmpty {
            self.results = foundResults
        }

        // On an explicit search, frame the map so both the user's location
        // (blue dot) and the top/nearest result pin are visible — even if the
        // result is well outside the current view. Auto searches leave the
        // camera where it is so panning around isn't interrupted.
        if recenter, let firstResult = self.results.first {
            let region = calculateRegionForUserAndResult(firstResult)
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

    /// Calculate a region that frames both the user's current location (the
    /// blue dot) and a single result pin, with padding so neither sits against
    /// the screen edge. Used to reveal an off-screen search result while keeping
    /// the user's own position in view.
    func calculateRegionForUserAndResult(_ result: MKMapItem) -> MKCoordinateRegion {
        let userCoord = viewModel.region.center
        let resultCoord = result.placemark.coordinate

        let minLat = min(userCoord.latitude, resultCoord.latitude)
        let maxLat = max(userCoord.latitude, resultCoord.latitude)
        let minLon = min(userCoord.longitude, resultCoord.longitude)
        let maxLon = max(userCoord.longitude, resultCoord.longitude)

        let centerLat = (minLat + maxLat) / 2
        let centerLon = (minLon + maxLon) / 2

        // 40% padding around the two points, with a minimum span so a nearby
        // result doesn't zoom in uncomfortably tight.
        let spanLat = max((maxLat - minLat) * 1.4, 0.01)
        let spanLon = max((maxLon - minLon) * 1.4, 0.01)

        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon),
            span: MKCoordinateSpan(latitudeDelta: spanLat, longitudeDelta: spanLon)
        )
    }
}

// MARK: - Store Icon View (Logo with Reminder Badge)

struct StoreIconView: View {
    let storeName: String
    var reminderCount: Int = 0
    @ObservedObject private var logoProvider = StoreLogoProvider.shared
    @State private var isAnimating = false
    @Environment(\.colorScheme) private var colorScheme

    private var firstLetter: String {
        let letter = storeName.prefix(1).uppercased()
        return letter.isEmpty ? "?" : letter
    }

    /// The store's tint, from the palette the avatars share.
    ///
    /// Keyed off the name the same way they are — `hashValue` is seeded per
    /// launch, so the old hash handed every store a new colour every time the
    /// app opened.
    private var storeColor: Color {
        OrganicAvatarTint.forName(storeName).fill
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Main pin content. These sit on map imagery rather than the paper
            // canvas, so the white ring and the shadow stay — they are what
            // separates a pin from whatever is under it.
            ZStack {
                if let image = logoProvider.cachedImage(for: storeName) {
                    // Store logo from cache
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 30, height: 30)
                        .clipShape(Circle())
                } else {
                    // Fallback: letter circle
                    Circle()
                        .fill(storeColor)
                        .frame(width: 30, height: 30)
                        .overlay(
                            Text(firstLetter)
                                .font(.system(size: 14, weight: .bold, design: .serif))
                                .foregroundColor(OrganicAvatarTint.forName(storeName).glyph)
                        )
                }
            }
            .overlay(Circle().strokeBorder(.white, lineWidth: 2))
            .shadow(color: Color.black.opacity(0.28), radius: 4, x: 0, y: 2)

            // Reminder count badge
            if reminderCount > 0 {
                Text("\(reminderCount)")
                    .font(.system(size: 10, weight: .bold, design: .serif))
                    .foregroundColor(.white)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(
                        Capsule()
                            .fill(OrganicPalette.terracotta(colorScheme))
                    )
                    .overlay(Capsule().strokeBorder(.white, lineWidth: 1.5))
                    .offset(x: 8, y: -6)
            }
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
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            // Flat terracotta rather than an orange-to-red gradient with a
            // highlight on top. The white ring and the shadow stay: this pin
            // lands on map imagery, not on paper.
            ZStack {
                Circle()
                    .fill(OrganicPalette.terracotta(colorScheme))
                    .frame(width: 38, height: 38)

                Image(systemName: "mappin")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
            }
            .overlay(Circle().strokeBorder(.white, lineWidth: 2))
            .shadow(color: Color.black.opacity(0.28), radius: 4, x: 0, y: 3)
            .zIndex(1)

            // Pin pointer/tail
            Triangle()
                .fill(OrganicPalette.terracotta(colorScheme))
                .frame(width: 14, height: 10)
                .offset(y: -3)
                .shadow(color: Color.black.opacity(0.2), radius: 2, x: 0, y: 2)

            // Name label
            Text(name)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(OrganicPalette.ink(colorScheme))
                .lineLimit(1)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(OrganicPalette.surface(colorScheme))
                        .shadow(color: Color.black.opacity(0.18), radius: 3, x: 0, y: 2)
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
            StoreIconView(storeName: "Walmart", reminderCount: 3)
            StoreIconView(storeName: "Target", reminderCount: 0)
            StoreIconView(storeName: "Costco", reminderCount: 1)
            StoreIconView(storeName: "Best Buy")
        }
    }
}
