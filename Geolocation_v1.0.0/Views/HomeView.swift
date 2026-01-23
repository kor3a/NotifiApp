//
//  HomeView.swift
//  Geolocation_v1.0.0
//
//  Created by James Jeon on 10/8/24.
//

import SwiftUI

struct HomeView: View {
    @ObservedObject private var sessionManager = UserSessionManager.shared
    @ObservedObject private var notificationManager = NotificationManager.shared
    @ObservedObject private var locationMonitor = LocationMonitoringManager.shared
    @ObservedObject private var storesViewModel = StoresViewModel()
    @StateObject private var messagesViewModel = MessagesViewModel()
    @StateObject private var friendsViewModel = FriendsViewModel()
    @State private var selectedTab = 0
    @State private var isSearchExpanded = false
    @State private var searchQuery = ""
    @State private var hasRequestedPermissions = false
    @State private var hasMigratedCoordinates = false
    @State private var showNotificationLog = false

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                StoresView()
                    .navigationTitle("Hi, \(sessionManager.currentUser?.name ?? "there")")
                    .navigationBarTitleDisplayMode(.large)
                    .onAppear {
                        // Fetch user data if not already loaded
                        if sessionManager.currentUser == nil && !sessionManager.isLoading {
                            sessionManager.fetchUser()
                        }
                    }
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            NavigationLink(destination: ProfileView(), label: {
                                Image(systemName: "person")
                                    .imageScale(.large)
                            })
                        }

                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button(action: {
                                showNotificationLog = true
                            }) {
                                Image(systemName: "bell.badge")
                                    .imageScale(.large)
                            }
                        }
                    }
            }//:NAVIGATIONSTACK
            .tabItem {
                Image(systemName: "storefront")
                Text("Stores")
            }
            .tag(0)

            NavigationStack {
                MessagesView(viewModel: messagesViewModel)
                    .navigationBarTitleDisplayMode(.large)
            }//:NAVIGATIONSTACK
            .tabItem {
                Image(systemName: "message")
                Text("Messages")
            }
            .badge(messagesViewModel.totalUnreadCount)
            .onChange(of: messagesViewModel.totalUnreadCount) { oldValue, newValue in
                print("📱 HomeView: Badge count changed from \(oldValue) to \(newValue)")
            }
            .tag(1)

            NavigationStack {
                FriendsView(messagesViewModel: messagesViewModel)
                    .navigationBarTitleDisplayMode(.large)
            }//:NAVIGATIONSTACK
            .tabItem {
                Image(systemName: "person.2")
                Text("Friends")
            }
            .badge(friendsViewModel.pendingRequestCount)
            .tag(2)

            NavigationStack {
                MapView(
                    selectedTab: $selectedTab,
                    isSearchExpanded: $isSearchExpanded,
                    searchQuery: $searchQuery,
                    messagesViewModel: messagesViewModel
                )
                .toolbar(.hidden, for: .tabBar)
            }//:NAVIGATIONSTACK
            .tabItem {
                Image(systemName: "map")
                Text("Search")
            }
            .tag(3)
        }
        .sheet(isPresented: $showNotificationLog) {
            NotificationLogView()
        }
        .onAppear {
            initializeLocationNotifications()
            // Fetch stores for migration
            storesViewModel.fetchUserStores()
            // Fetch unread message count for badge
            messagesViewModel.fetchUnreadCount()
            // Fetch pending friend requests count for badge
            friendsViewModel.fetchPendingRequestCount()
        }
        .onChange(of: sessionManager.currentUser) { newUser in
            // Fetch unread message count whenever user data becomes available
            if newUser?.userId != nil {
                messagesViewModel.fetchUnreadCount()
                friendsViewModel.fetchPendingRequestCount()
            }

            // Start monitoring when user data becomes available
            if let userId = newUser?.userId, !locationMonitor.isMonitoring {
                let locationStatus = locationMonitor.checkLocationPermission()
                if locationStatus == .authorizedAlways || locationStatus == .authorizedWhenInUse {
                    locationMonitor.startMonitoring(userId: userId)
                    print("HomeView: Started monitoring after user data loaded for: \(userId)")
                } else {
                    // Store userId for auto-start when permission is granted
                    locationMonitor.setUserId(userId)
                    print("HomeView: User ID set, waiting for location permission")
                }

                // Fetch stores now that user data is available
                storesViewModel.fetchUserStores()

                // Run coordinate migration once per session
                if !hasMigratedCoordinates {
                    hasMigratedCoordinates = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        storesViewModel.migrateUserStoresWithCoordinates()
                    }
                }
            }
        }
    }

    // MARK: - Location & Notification Setup

    private func initializeLocationNotifications() {
        // Only request permissions once
        guard !hasRequestedPermissions else { return }
        hasRequestedPermissions = true

        print("🚀 HomeView: Initializing location and notification permissions")

        // Request notification permission
        Task {
            let notificationGranted = await notificationManager.requestAuthorization()
            if notificationGranted {
                print("✅ HomeView: Notification permission granted")
            } else {
                print("⚠️ HomeView: Notification permission denied")
            }

            // Debug: Print detailed notification settings
            notificationManager.debugNotificationSettings()
        }

        // Request location permission and start monitoring
        let locationStatus = locationMonitor.checkLocationPermission()
        print("📍 HomeView: Current location status: \(locationStatus.rawValue)")

        // Only request permission if not yet determined
        if locationStatus == .notDetermined {
            print("   Requesting location permission...")
            locationMonitor.requestLocationPermission()
        }

        // Start monitoring if we have permission and user is logged in
        if let userId = sessionManager.currentUser?.userId {
            print("👤 HomeView: User ID available: \(userId)")
            if locationStatus == .authorizedAlways || locationStatus == .authorizedWhenInUse {
                locationMonitor.startMonitoring(userId: userId)
                print("✅ HomeView: Started location monitoring")
            } else {
                locationMonitor.setUserId(userId)
                print("⏸️ HomeView: User ID saved, waiting for location permission")
            }
        } else {
            print("⏸️ HomeView: User ID not available yet, will start monitoring when user data loads")
        }
    }
}

#Preview {
    HomeView()
}
