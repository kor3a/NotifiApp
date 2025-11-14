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
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        ZStack(alignment: .bottom) {
            // Main content
            Group {
                if selectedTab == 0 {
                    NavigationStack {
                        StoresView()
                            .navigationTitle("Hi, \(sessionManager.currentUser?.name ?? "there")")
                            .navigationBarTitleDisplayMode(.large)
                            .onAppear {
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
                    }
                } else {
                    NavigationStack {
                        MapView(isSearchExpanded: $isSearchExpanded, searchQuery: $searchQuery)
                            .navigationTitle("Map")
                            .navigationBarTitleDisplayMode(.inline)
                            .toolbarBackground(.visible, for: .navigationBar)
                            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Custom tab bar at bottom
            customTabBar
        }
        .ignoresSafeArea(.keyboard) // Prevent keyboard from pushing tab bar up
    }

    private var customTabBar: some View {
        Group {
            if selectedTab == 1 {
                // MapView: Left-aligned tabs with search on right
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
                    .transition(.opacity)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isSearchExpanded)
            } else {
                // Other views: Centered tab bar
                HStack(spacing: 40) {
                    // Stores tab
                    Button(action: {
                        withAnimation(.spring(response: 0.3)) {
                            selectedTab = 0
                        }
                    }) {
                        VStack(spacing: 4) {
                            Image(systemName: "storefront")
                                .font(.system(size: 24))
                            Text("Stores")
                                .font(.system(size: 11))
                        }
                        .foregroundColor(selectedTab == 0 ? .blue : .primary)
                    }

                    // Map tab
                    Button(action: {
                        withAnimation(.spring(response: 0.3)) {
                            selectedTab = 1
                        }
                    }) {
                        VStack(spacing: 4) {
                            Image(systemName: "map")
                                .font(.system(size: 24))
                            Text("Search")
                                .font(.system(size: 11))
                        }
                        .foregroundColor(selectedTab == 1 ? .blue : .primary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 0))
            }
        }
        .animation(.spring(response: 0.3), value: selectedTab)
    }
}

#Preview {
    HomeView()
}
