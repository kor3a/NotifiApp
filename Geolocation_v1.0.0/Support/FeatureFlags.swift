//
//  FeatureFlags.swift
//  Geolocation_v1.0.0
//
//  Created by Claude on 8/11/26.
//
//  Build-time switches for work that isn't ready to ship. Each flag is a
//  single place to flip when a feature graduates, rather than a `#if DEBUG`
//  scattered across every call site.
//

import Foundation

enum FeatureFlags {

    /// Voice commands on the store row's swipe actions.
    ///
    /// DEBUG only while the speech and intent-parsing behaviour is still being
    /// tuned — release builds don't show the swipe action or advertise it on
    /// the paywall. To ship it, return `true` unconditionally and delete the
    /// `#if`; every gate reads this one property.
    static var voiceCommands: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }
}
