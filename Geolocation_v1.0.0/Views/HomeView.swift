//
//  HomeView.swift
//  Geolocation_v1.0.0
//
//  Created by James Jeon on 10/8/24.
//

import SwiftUI

struct HomeView: View {
    @ObservedObject private var sessionManager = UserSessionManager.shared
    @State private var selectedTab = 0
    @State private var isSearchExpanded = false
    @State private var searchQuery = ""

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
    }
}

#Preview {
    HomeView()
}
