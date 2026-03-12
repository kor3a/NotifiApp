//
//  HomeView.swift
//  Geolocation_v1.0.0
//
//  Created by James Jeon on 10/8/24.
//

import SwiftUI
import UIKit

struct HomeView: View {
    @ObservedObject private var sessionManager = UserSessionManager.shared
    @ObservedObject private var notificationManager = NotificationManager.shared
    @ObservedObject private var locationMonitor = LocationMonitoringManager.shared
    @ObservedObject private var storesViewModel = StoresViewModel()
    @ObservedObject private var friendRequestService = FriendRequestService.shared
    @ObservedObject private var messagingService = MessagingService.shared
    @StateObject private var messagesViewModel = MessagesViewModel()
    @StateObject private var friendsViewModel = FriendsViewModel()
    @State private var selectedTab = 0
    @State private var isSearchExpanded = false
    @State private var searchQuery = ""
    @State private var hasRequestedPermissions = false
    @State private var pendingStoreName: String? = nil
    @State private var pendingConversationId: String? = nil
    @State private var showCarPlayAlert = false
    @State private var showNotificationsDeniedAlert = false

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                StoresView(pendingStoreName: $pendingStoreName)
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
                MessagesView(viewModel: messagesViewModel, pendingConversationId: $pendingConversationId)
                    .navigationBarTitleDisplayMode(.large)
            }//:NAVIGATIONSTACK
            .tabItem {
                Image(systemName: "message")
                Text("Messages")
            }
            .badge(messagesViewModel.totalUnreadCount)
            .onChange(of: messagesViewModel.totalUnreadCount) { oldValue, newValue in
                #if DEBUG
                print("📱 HomeView: Badge count changed from \(oldValue) to \(newValue)")
                #endif
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
        .onChange(of: notificationManager.pendingNavigation) { _, navigation in
            guard let navigation = navigation else { return }
            handleNotificationNavigation(navigation)
        }
        .onChange(of: notificationManager.isCarPlayEnabled) { _, enabled in
            if notificationManager.isAuthorized && !enabled {
                showCarPlayAlert = true
            }
        }
        .alert("Notifications Are Disabled", isPresented: $showNotificationsDeniedAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Dismiss", role: .cancel) {}
        } message: {
            Text("Allim needs notifications to alert you about nearby stores and messages. Go to Settings > Notifications > Allim and turn on Allow Notifications.")
        }
        .alert("Enable CarPlay Notifications", isPresented: $showCarPlayAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Dismiss", role: .cancel) {}
        } message: {
            switch notificationManager._carPlaySetting {
            case .disabled:
                Text("Notifications won't appear on your CarPlay screen. Go to Settings > Notifications > Allim and turn on CarPlay.")
            case .notSupported:
                Text("CarPlay notifications aren't registered for this app yet. Go to Settings > Notifications > Allim, toggle Notifications off and back on, then relaunch the app.")
            case .enabled:
                Text("CarPlay notifications are enabled.")
            }
        }
        .onAppear {
            // Handle any notification tap that occurred before the view appeared
            if let navigation = notificationManager.pendingNavigation {
                handleNotificationNavigation(navigation)
            }
            initializeLocationNotifications()
            // Fetch stores for migration
            storesViewModel.fetchUserStores()
            // Fetch unread message count for badge
            messagesViewModel.fetchUnreadCount()
            // Fetch pending friend request count for badge
            friendsViewModel.fetchPendingRequestCount()

            // Start listening for friend requests, incoming messages, and shared reminder changes
            if let userId = sessionManager.currentUser?.userId {
                friendRequestService.listenForIncomingRequests(userId: userId)
                messagingService.startListeningForIncomingMessages(userId: userId)
            }
            if let userEmail = sessionManager.currentUser?.email {
                SharedReminderNotificationService.shared.startListening(userEmail: userEmail)
                OnMyWayNotificationService.shared.startListening(userEmail: userEmail)
            }
        }
        .onChange(of: sessionManager.currentUser) { oldUser, newUser in
            // Fetch unread message count whenever user data becomes available
            if let userId = newUser?.userId {
                messagesViewModel.fetchUnreadCount()
                friendsViewModel.fetchPendingRequestCount()

                // Start listening for friend requests
                friendRequestService.listenForIncomingRequests(userId: userId)

                // Start listening for incoming messages
                messagingService.startListeningForIncomingMessages(userId: userId)

                // Start listening for shared reminder change and on-my-way notifications
                if let userEmail = newUser?.email {
                    SharedReminderNotificationService.shared.startListening(userEmail: userEmail)
                    OnMyWayNotificationService.shared.startListening(userEmail: userEmail)
                }
            }

            // Start monitoring when user data becomes available
            if let userId = newUser?.userId, !locationMonitor.isMonitoring {
                let locationStatus = locationMonitor.checkLocationPermission()
                if locationStatus == .authorizedAlways || locationStatus == .authorizedWhenInUse {
                    locationMonitor.startMonitoring(userId: userId)
                    #if DEBUG
                    print("HomeView: Started monitoring after user data loaded for: \(userId)")
                    #endif
                } else {
                    // Store userId for auto-start when permission is granted
                    locationMonitor.setUserId(userId)
                    #if DEBUG
                    print("HomeView: User ID set, waiting for location permission")
                    #endif
                }

                // Fetch stores now that user data is available
                storesViewModel.fetchUserStores()
            }
        }
    }

    // MARK: - Notification Navigation

    private func handleNotificationNavigation(_ navigation: NotificationManager.NotificationNavigation) {
        switch navigation {
        case .store(let name):
            selectedTab = 0
            pendingStoreName = name
        case .message(let conversationId):
            selectedTab = 1
            pendingConversationId = conversationId
        case .friendRequest:
            selectedTab = 2
        }
        notificationManager.pendingNavigation = nil
    }

    // MARK: - Location & Notification Setup

    private func initializeLocationNotifications() {
        // Only request permissions once
        guard !hasRequestedPermissions else { return }
        hasRequestedPermissions = true

        #if DEBUG
        print("🚀 HomeView: Initializing location and notification permissions")
        #endif

        // Request notification permission
        Task {
            let notificationGranted = await notificationManager.requestAuthorization()
            #if DEBUG
            if notificationGranted {
                print("✅ HomeView: Notification permission granted")
            } else {
                print("⚠️ HomeView: Notification permission denied")
            }
            #endif

            // Debug: Print detailed notification settings
            notificationManager.debugNotificationSettings()

            if !notificationGranted {
                // Permission is denied — iOS won't re-prompt, user must go to Settings manually
                showNotificationsDeniedAlert = true
            } else if notificationManager._carPlaySetting != .enabled {
                // Notifications authorized but CarPlay specifically is off/unsupported
                showCarPlayAlert = true
            }
        }

        // Request location permission and start monitoring
        let locationStatus = locationMonitor.checkLocationPermission()
        #if DEBUG
        print("📍 HomeView: Current location status: \(locationStatus.rawValue)")
        #endif

        // Only request permission if not yet determined
        if locationStatus == .notDetermined {
            #if DEBUG
            print("   Requesting location permission...")
            #endif
            locationMonitor.requestLocationPermission()
        }

        // Start monitoring if we have permission and user is logged in
        if let userId = sessionManager.currentUser?.userId {
            #if DEBUG
            print("👤 HomeView: User ID available: \(userId)")
            #endif
            if locationStatus == .authorizedAlways || locationStatus == .authorizedWhenInUse {
                locationMonitor.startMonitoring(userId: userId)
                #if DEBUG
                print("✅ HomeView: Started location monitoring")
                #endif
            } else {
                locationMonitor.setUserId(userId)
                #if DEBUG
                print("⏸️ HomeView: User ID saved, waiting for location permission")
                #endif
            }
        } else {
            #if DEBUG
            print("⏸️ HomeView: User ID not available yet, will start monitoring when user data loads")
            #endif
        }
    }
}

#Preview {
    HomeView()
}
