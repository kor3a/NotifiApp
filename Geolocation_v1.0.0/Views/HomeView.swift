//
//  HomeView.swift
//  Geolocation_v1.0.0
//
//  Created by James Jeon on 10/8/24.
//

import SwiftUI

struct HomeView: View {
    @State private var showSheet = false
    
    var body: some View {
        TabView {
            NavigationStack {
                StoresView()
                    .navigationTitle("Hi, James")
                    .navigationBarTitleDisplayMode(.large)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            NavigationLink(destination: ProfileView(), label: {
                                Image(systemName: "person")
                                    .imageScale(.large)
                            })
                        }
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button {
                                showSheet.toggle()
                            } label: {
                                Image(systemName: "plus")
                                    .imageScale(.large)
                            }
                            
                            }
                        }
            }.sheet(isPresented: $showSheet) {
                AddStoreView()
            }//:NAVIGATIONSTACK
            .tabItem {
                Image(systemName: "storefront")
                Text("Stores")
            }
            
            
            NavigationStack {
                MapView()
            }//:NAVIGATIONSTACK
            .tabItem {
                Image(systemName: "map")
                Text("Search")
            }
        }
    }
}

#Preview {
    HomeView()
}
