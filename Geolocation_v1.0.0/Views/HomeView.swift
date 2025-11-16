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
    @State private var selectedTab = 0
    @State private var isSearchExpanded = false
    @State private var searchQuery = ""
    @State private var hasRequestedPermissions = false

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
                    }
            }//:NAVIGATIONSTACK
            .tabItem {
                Image(systemName: "storefront")
                Text("Stores")
            }
            .tag(0)

            NavigationStack {
                MapView(
                    selectedTab: $selectedTab,
                    isSearchExpanded: $isSearchExpanded,
                    searchQuery: $searchQuery
                )
                .toolbar(.hidden, for: .tabBar)
            }//:NAVIGATIONSTACK
            .tabItem {
                Image(systemName: "map")
                Text("Search")
            }
            .tag(1)
        }
        .onAppear {
            initializeLocationNotifications()
        }
    }

    // MARK: - Location & Notification Setup

    private func initializeLocationNotifications() {
        // Only request permissions once
        guard !hasRequestedPermissions else { return }
        hasRequestedPermissions = true

        // Request notification permission
        Task {
            let notificationGranted = await notificationManager.requestAuthorization()
            if notificationGranted {
                print("HomeView: Notification permission granted")
            } else {
                print("HomeView: Notification permission denied")
            }
        }

        // Request location permission and start monitoring
        let locationStatus = locationMonitor.checkLocationPermission()
        if locationStatus == .notDetermined || locationStatus == .authorizedWhenInUse {
            locationMonitor.requestLocationPermission()
        }

        // Start monitoring if we have permission and user is logged in
        if let userId = sessionManager.currentUser?.userId {
            if locationStatus == .authorizedAlways {
                locationMonitor.startMonitoring(userId: userId)
                print("HomeView: Started location monitoring for user: \(userId)")
            } else {
                print("HomeView: Waiting for 'Always' location permission to start monitoring")
            }
        }
    }
}

#Preview {
    HomeView()
}
