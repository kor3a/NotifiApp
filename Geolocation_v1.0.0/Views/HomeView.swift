//
//  HomeView.swift
//  Geolocation_v1.0.0
//
//  Created by James Jeon on 10/8/24.
//

import SwiftUI
import UIKit
import Combine
import UserNotifications

struct HomeView: View {
    @ObservedObject private var sessionManager = UserSessionManager.shared
    @ObservedObject private var notificationManager = NotificationManager.shared
    @ObservedObject private var locationMonitor = LocationMonitoringManager.shared
    @ObservedObject private var storesViewModel = StoresViewModel()
    @ObservedObject private var friendRequestService = FriendRequestService.shared
    @ObservedObject private var messagingService = MessagingService.shared
    @StateObject private var messagesViewModel = MessagesViewModel()
    @StateObject private var friendsViewModel = FriendsViewModel()
    @ObservedObject private var tutorialManager = TutorialManager.shared
    @State private var selectedTab = 0
    @State private var isSearchExpanded = false
    @State private var searchQuery = ""
    @State private var hasRequestedPermissions = false
    @State private var pendingStoreName: String? = nil
    @State private var pendingConversationId: String? = nil
    @State private var showCarPlayAlert = false
    @State private var showNotificationsDeniedAlert = false

    @ViewBuilder
    private var debugTab: some View {
        #if DEBUG
        NavigationStack {
            NotificationDebugTab()
        }
        .tabItem {
            Image(systemName: "bell.badge")
            Text("Debug")
        }
        .tag(4)
        #endif
    }

    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                // Stores draws its own greeting, title and profile button in
                // the content, so this stack is here only to push from — the
                // screen hides its navigation bar.
                NavigationStack {
                    StoresView(pendingStoreName: $pendingStoreName)
                        .onAppear {
                            // Fetch user data if not already loaded
                            if sessionManager.currentUser == nil && !sessionManager.isLoading {
                                sessionManager.fetchUser()
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
                    UIApplication.shared.applicationIconBadgeNumber = newValue
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

                debugTab
            }//:TABVIEW

            // Tutorial overlay — rendered above the TabView (including tab bar)
            if tutorialManager.isActive {
                TutorialOverlayView()
                    .ignoresSafeArea()
                    .allowsHitTesting(true)
            }
        }//:ZSTACK
        .onChange(of: notificationManager.pendingNavigation) { _, navigation in
            guard let navigation = navigation else { return }
            handleNotificationNavigation(navigation)
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
            Text("Notifications won't appear on your CarPlay screen. Go to Settings > Notifications > Allim and turn on CarPlay.")
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

            // Tutorial start is handled by TutorialManager's own Combine
            // subscription on UserSessionManager.$currentUser, so it works
            // reliably even when permission dialogs disrupt HomeView's lifecycle.
            #if DEBUG
            print("🎓 HomeView.onAppear: currentUser=\(sessionManager.currentUser?.userId ?? "nil"), isLoading=\(sessionManager.isLoading)")
            #endif
        }
        .onChange(of: tutorialManager.pendingTabSwitch) { _, tab in
            guard let tab = tab else { return }
            withAnimation(.easeInOut(duration: 0.3)) {
                selectedTab = tab
            }
            tutorialManager.pendingTabSwitch = nil
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

            // Start monitoring when user data becomes available. Deliberately not
            // gated on `isMonitoring` — monitoring may already be running under the
            // user ID restored from UserDefaults, and this is where the actual
            // signed-in account takes over. startMonitoring is idempotent when the
            // user is unchanged.
            if let userId = newUser?.userId {
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

        // Request notification permission. New accounts have already been asked
        // from PermissionOnboardingView, so this only fires for anyone who
        // reached the app without being prompted (an install that predates the
        // walkthrough, or a permission reset).
        Task {
            let status = await notificationManager.authorizationStatus()
            let notificationGranted: Bool
            if status == .notDetermined {
                notificationGranted = await notificationManager.requestAuthorization()
            } else {
                notificationManager.checkAuthorizationStatus()
                notificationGranted = status == .authorized
            }
            #if DEBUG
            if notificationGranted {
                print("✅ HomeView: Notification permission granted")
            } else {
                print("⚠️ HomeView: Notification permission denied")
            }
            #endif

            // Debug: Print detailed notification settings
            notificationManager.debugNotificationSettings()

            // Right after the permission walkthrough, a decline the user made
            // seconds ago doesn't need an alert about itself landing on top of
            // the tutorial. The nudge returns on the next launch.
            if PermissionOnboardingManager.shared.didRunThisSession {
                return
            }

            if !notificationGranted {
                // Permission is denied — iOS won't re-prompt, user must go to Settings manually
                showNotificationsDeniedAlert = true
            } else if notificationManager._carPlaySetting == .disabled {
                // Per-app CarPlay toggle exists but is explicitly turned off
                showCarPlayAlert = true
            }
            // .notSupported just means iOS shows no per-app CarPlay toggle for this build.
            // It is not a fault to nag the user about: the proximity banner reaches CarPlay as a
            // communication notification, which is a separate path from this setting.
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

#if DEBUG
private struct NotificationDebugTab: View {
    @ObservedObject private var manager = NotificationManager.shared
    @State private var storeName = "Target"
    @State private var reminderCount = 3

    var body: some View {
        List {
            Section("Status") {
                HStack { Text("Notifications"); Spacer(); Text(manager.isAuthorized ? "✅" : "❌") }
                HStack { Text("CarPlay"); Spacer(); Text(manager.isCarPlayConnected ? "🚗 Connected" : "📱 Disconnected") }
            }

            Section {
                TextField("Store Name", text: $storeName)
                Stepper("Reminders: \(reminderCount)", value: $reminderCount, in: 1...10)
                Button("Test: Passive") { fire(.passive) }
                Button("Test: Time Sensitive") { fire(.timeSensitive) }
                Button("Test: Critical") { fire(.critical) }
            } header: {
                Text("Test Notification")
            } footer: {
                // The CarPlay screen only ever shows a notification the app was NOT
                // frontmost for. Firing this and watching the banner land on top of
                // this very screen tests the foreground path and says nothing about
                // CarPlay — a trap worth spelling out where it gets tapped, rather
                // than in a comment nobody reads while sitting in a car.
                Text("Fires after \(Int(testFireDelay))s. Leave the app before it lands — "
                     + "background it or lock the phone. A banner shown while Allim is "
                     + "open is the in-app presentation and never reaches CarPlay.")
            }

            Section("Debug Actions") {
                Button("Print Detailed Settings") {
                    Task { await manager.printDetailedSettings() }
                }
                Button("Show Pending") { manager.getAllPendingNotificationsDebug() }
                Button("Show Delivered") { manager.getAllDeliveredNotificationsDebug() }
                Button("Clear All Pending", role: .destructive) {
                    manager.removeAllPendingNotifications()
                }
            }

            if !manager.debugInfo.isEmpty {
                Section("Last Settings Check") {
                    Text(manager.debugInfo)
                        .font(.system(.caption, design: .monospaced))
                }
            }
        }
        .navigationTitle("🔧 Notification Debug")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// Long enough to background the app (or lock with the side button) before the
    /// notification lands. Five seconds meant a fumbled swipe left you testing the
    /// foreground path by accident.
    private let testFireDelay: TimeInterval = 12

    private func fire(_ mode: NotificationManager.InterruptionMode) {
        manager.scheduleStoreProximityNotification(
            storeName: storeName,
            reminderCount: reminderCount,
            mode: mode,
            delay: testFireDelay
        )
    }
}
#endif
