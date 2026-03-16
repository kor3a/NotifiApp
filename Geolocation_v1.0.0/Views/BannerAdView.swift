//
//  BannerAdView.swift
//  Geolocation_v1.0.0
//
//  Created for Google AdMob banner ad integration.
//

import SwiftUI
import GoogleMobileAds

// MARK: - AdMob Ad Unit IDs
// TODO: Replace with your real Ad Unit ID from https://admob.google.com
// Test banner Ad Unit ID (safe to use during development/testing):
let kBannerAdUnitID = "ca-app-pub-3940256099942544/2934735716"

// MARK: - BannerAdView

/// A SwiftUI-compatible wrapper around GADBannerView (Google AdMob banner).
struct BannerAdView: UIViewRepresentable {
    let adUnitID: String

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> BannerView {
        let bannerView = BannerView(adSize: AdSizeBanner)
        bannerView.adUnitID = adUnitID
        bannerView.delegate = context.coordinator
        bannerView.rootViewController = topViewController()
        bannerView.load(Request())
        return bannerView
    }

    func updateUIView(_ uiView: BannerView, context: Context) {}

    // MARK: - Coordinator

    class Coordinator: NSObject, BannerViewDelegate {
        func bannerViewDidReceiveAd(_ bannerView: BannerView) {
            #if DEBUG
            print("✅ AdMob: Banner ad loaded successfully.")
            #endif
        }

        func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
            #if DEBUG
            print("❌ AdMob: Banner ad failed to load — \(error.localizedDescription)")
            #endif
        }
    }

    // MARK: - Helpers

    /// Returns the topmost UIViewController, needed for ad presentation.
    private func topViewController() -> UIViewController? {
        guard
            let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive }),
            let root = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController
        else { return nil }

        var top = root
        while let presented = top.presentedViewController {
            top = presented
        }
        return top
    }
}
