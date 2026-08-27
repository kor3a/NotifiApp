//
//  PremiumFeature.swift
//  Geolocation_v1.0.0
//

import Foundation

/// The one list of Premium features, shared by the paywall and the management
/// sheet. Both screens read it so what we advertise and what we confirm you
/// own can't drift apart.
struct PremiumFeature: Identifiable {
    let icon: String
    let title: String
    let description: String

    var id: String { title }

    static let all: [PremiumFeature] = [
        PremiumFeature(
            icon: "infinity",
            title: "Unlimited Stores",
            description: "Free accounts are limited to \(SubscriptionManager.freeStoreLimit) stores of your own — go unlimited with Premium"
        ),
        PremiumFeature(
            icon: "fork.knife",
            title: "Smart Recipe",
            description: "Ask for any recipe and add ingredients directly to your stores"
        ),
        PremiumFeature(
            icon: "sparkles",
            title: "Smart Category",
            description: "AI auto-categorizes every item you add to your shopping list"
        ),
        PremiumFeature(
            icon: "hand.thumbsup.fill",
            title: "Ad-Free Experience",
            description: "Enjoy the app without any banner advertisements"
        )
    ]
}
