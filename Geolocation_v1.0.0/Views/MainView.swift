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
    @ObservedObject private var permissionOnboarding = PermissionOnboardingManager.shared

    var body: some View {
        if viewModel.isLoading {
            Color(.systemBackground)
                .ignoresSafeArea()
        } else if viewModel.isSignedIn, !viewModel.currentUserId.isEmpty {
            switch sessionManager.profileStatus {
            case .ready:
                // A brand-new account is walked through location and notification
                // permissions before it lands in the app, so the one-shot system
                // prompts arrive with an explanation attached. Accounts that have
                // already answered (or already been walked through) resolve to
                // `.finished` and go straight to HomeView.
                switch permissionOnboarding.state {
                case .finished:
                    HomeView()
                case .active:
                    PermissionOnboardingView()
                case .evaluating:
                    loadingScreen
                }
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
                loadingScreen
            }
        } else {
            LoginView()
        }
    }

    /// Neutral hold used whenever the app knows the user is signed in but not yet
    /// where they belong — during the profile lookup, and while the permission
    /// walkthrough works out whether it has anything to show.
    private var loadingScreen: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()
            ProgressView()
                .scaleEffect(1.5)
        }
    }
}


#Preview {
    MainView()
}
