//
//  ContentView.swift
//  Geolocation_v1.0.0
//
//  Created by Subong Jeon on 8/2/24.
//

import SwiftUI
import MapKit

struct MainView: View {
    
    @StateObject private var viewModel:MainViewModel = .init()
    @ObservedObject private var sessionManager = UserSessionManager.shared

    var body: some View {
        if viewModel.isLoading {
            Color(.systemBackground)
                .ignoresSafeArea()
        } else if viewModel.isSignedIn, !viewModel.currentUserId.isEmpty {
            switch sessionManager.profileStatus {
            case .ready:
                HomeView()
            // A first-time Apple/Google sign-in has no profile yet — pick a
            // username and name before entering the app.
            case .needsSetup:
                ProfileSetupView()
            // Still looking the profile up. Showing the app here is what made
            // first-time social sign-ups flash StoresView before setup appeared,
            // so wait for the answer. Only reached mid-sign-in or on an account
            // this device hasn't resolved before — a returning user routes
            // straight from the cached status.
            case .resolving:
                ZStack {
                    Color(.systemBackground)
                        .ignoresSafeArea()
                    ProgressView()
                        .scaleEffect(1.5)
                }
            }
        } else {
            LoginView()
        }
    }
}


#Preview {
    MainView()
}
