//
//  StoresView.swift
//  Geolocation_v1.0.0
//
//  Created by James Jeon on 10/18/24.
//

import SwiftUI

struct StoresView: View {
    // TODO: get the actual stores added from the user database
//    let stores = [
//        Store(name: "Trader Joe's", address: "6401 Haven Ave, Rancho Cucamonga, CA 91737", reminderCount: 1),
//        Store(name: "Costco", address: "9404 Central Ave, Montclair, CA 91763", reminderCount: 0),
//        Store(name: "Wholefoods", address: "2153 West Baseline Road, Upland, CA 91784", reminderCount: 0)
//    ]
    // MARK: - PROPERTIES
    
    @ObservedObject private var viewModel = StoresViewModel()
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(viewModel.stores) { store in
                    NavigationLink(destination: ReminderView()) {
                        StoreItemView(store: store)
                    }
                }
            } //:LIST
            .listStyle(.grouped)
        }//:NAVIGATIONSTACK
        .onAppear() {
            self.viewModel.fetchData()
        }
    }//:BODY
}

#Preview {
    StoresView()
}
