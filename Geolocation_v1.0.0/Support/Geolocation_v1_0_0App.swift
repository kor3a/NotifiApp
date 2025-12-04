//
//  Geolocation_v1_0_0App.swift
//  Geolocation_v1.0.0
//
//  Created by Subong Jeon on 8/2/24.
//

import SwiftUI
import FirebaseCore
import AVFoundation

@main
struct Geolocation_v1_0_0App: App {

    init() {
        FirebaseApp.configure()
        configureAudioSession()
    }

    private func configureAudioSession() {
        do {
            // Configure audio session for CarPlay compatibility
            // Using .ambient category so audio doesn't interrupt other apps
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try audioSession.setActive(true)
            print("✅ Audio session configured for CarPlay compatibility")
        } catch {
            print("⚠️ Failed to configure audio session: \(error)")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            MainView()
        }
    }
}
