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
    
    var body: some View {
        if viewModel.isLoading {
            Color(.systemBackground)
                .ignoresSafeArea()
        } else if viewModel.isSignedIn, !viewModel.currentUserId.isEmpty {
            HomeView()
        } else {
            LoginView()
        }
    }
}


#Preview {
    MainView()
}
