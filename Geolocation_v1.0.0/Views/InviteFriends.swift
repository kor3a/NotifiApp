//
//  InviteFriends.swift
//  Geolocation_v1.0.0
//

import UIKit

/// Shared helper for inviting friends to download Allim.
enum AppInvite {
    /// Allim's public App Store page.
    static let appStoreLink = "https://apps.apple.com/us/app/allim-smart-shopping-list/id6758680783"

    /// Message shown after the link is copied.
    static let linkCopiedMessage = "Allim's App Store link has been copied to your clipboard. Paste it anywhere to share the app with friends!"

    /// Copies the App Store link to the clipboard so the user can paste it anywhere.
    static func copyLinkToClipboard() {
        UIPasteboard.general.string = appStoreLink
    }
}
