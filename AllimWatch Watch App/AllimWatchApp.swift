//
//  AllimWatchApp.swift
//  AllimWatch Watch App
//
//  Entry point for the Allim watch app.
//

import SwiftUI

@main
struct AllimWatchApp: App {

    @StateObject private var dataStore = WatchDataStore.shared

    init() {
        // Activate the link to the phone before any view asks for data — the
        // store list the phone already pushed is waiting in the session's
        // application context and arrives as soon as the delegate is set.
        WatchDataStore.shared.activate()
    }

    var body: some Scene {
        WindowGroup {
            WatchStoreListView()
                .environmentObject(dataStore)
        }
    }
}
