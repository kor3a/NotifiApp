//
//  StoresView.swift
//  Geolocation_v1.0.0
//
//  Created by James Jeon on 10/18/24.
//

import SwiftUI

struct StoresView: View {
    // MARK: - PROPERTIES

    @StateObject private var viewModel = StoresViewModel()
    @ObservedObject private var sessionManager = UserSessionManager.shared
    @State private var showingAddStore = false
    @State private var isMenuExpanded = false
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color.backgroundGradient(for: colorScheme)
                    .ignoresSafeArea()

                // Dimmed overlay when menu is expanded
                if isMenuExpanded {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                isMenuExpanded = false
                            }
                        }
                        .transition(.opacity)
                }

                // Floating action button and menu
                VStack {
                    Spacer()
                    HStack {
                        Spacer()

                        ZStack {
                            // Expanded menu
                            if isMenuExpanded {
                                VStack(spacing: 0) {
                                    Button(action: {
                                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                            isMenuExpanded = false
                                        }
                                        showingAddStore = true
                                    }) {
                                        HStack {
                                            Image(systemName: "cart.badge.plus")
                                                .font(.system(size: 20))
                                            Text("Add Store")
                                                .font(.headline)
                                            Spacer()
                                        }
                                        .padding()
                                        .frame(width: 200)
                                        .background(
                                            RoundedRectangle(cornerRadius: 16)
                                                .fill(.ultraThinMaterial)
                                        )
                                        .foregroundColor(.primary)
                                    }
                                }
                                .transition(.scale(scale: 0.1, anchor: .bottomTrailing).combined(with: .opacity))
                            }

                            // Floating + button
                            if !isMenuExpanded {
                                Button(action: {
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                        isMenuExpanded = true
                                    }
                                }) {
                                    Image(systemName: "plus")
                                        .font(.system(size: 24, weight: .semibold))
                                        .foregroundColor(.white)
                                        .frame(width: 60, height: 60)
                                        .background(
                                            Circle()
                                                .fill(Color.blue)
                                                .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 4)
                                        )
                                }
                                .transition(.scale(scale: 0.1, anchor: .bottomTrailing).combined(with: .opacity))
                            }
                        }
                        .padding(.trailing, 24)
                        .padding(.bottom, 24)
                    }
                }
            }
        }//:NAVIGATIONSTACK
        .sheet(isPresented: $showingAddStore) {
            AddStoreView(viewModel: viewModel)
        }
        .onAppear() {
            // Try to fetch immediately if user data is available
            if sessionManager.currentUser != nil {
                self.viewModel.fetchUserStores()
            }
        }
        .onChange(of: sessionManager.currentUser) { oldValue, newValue in
            // Fetch stores when user data becomes available
            if newValue != nil && viewModel.userStoreItems.isEmpty {
                self.viewModel.fetchUserStores()
            }
        }
    }//:BODY
}

#Preview {
    StoresView()
}
