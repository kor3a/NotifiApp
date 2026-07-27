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
            // A first-time Apple/Google sign-in has no profile yet — pick a
            // username and name before entering the app.
            if sessionManager.needsProfileSetup {
                ProfileSetupView()
            } else {
                HomeView()
            }
        } else {
            LoginView()
        }
    }
}


#Preview {
    MainView()
}
