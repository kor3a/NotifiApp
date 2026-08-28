//
//  AppIconManager.swift
//  Geolocation_v1.0.0
//
//  Owns which home-screen icon the app is wearing.
//

import SwiftUI
import UIKit

/// One choice on the App Icons screen.
///
/// `alternateName` is the asset catalog name UIKit is handed — nil means the
/// icon the app ships with, which UIKit calls the primary icon and identifies
/// by the absence of a name.
struct AppIconOption: Identifiable, Equatable {
    let alternateName: String?
    let displayName: String
    /// Short line under the name on the picker.
    let subtitle: String
    /// The image drawn in the picker. The icon assets themselves aren't
    /// loadable by name at runtime, so every option carries a plain imageset
    /// holding the same artwork.
    let previewAssetName: String

    var id: String { alternateName ?? "primary" }
}

/// Reads and writes the app's icon.
///
/// iOS puts up its own "You have changed the icon" alert on every successful
/// change; that's the system's to show, so nothing here tries to confirm the
/// switch a second time.
@MainActor
final class AppIconManager: ObservableObject {

    static let shared = AppIconManager()

    /// The alternate icon in use, or nil for the icon the app ships with.
    @Published private(set) var currentIconName: String?
    /// Set when iOS refuses a change, so the screen can say what happened.
    @Published var errorMessage: String?

    /// Every icon the app offers. Order is the order they appear in the grid,
    /// with the shipped icon first.
    static let options: [AppIconOption] = [
        AppIconOption(
            alternateName: nil,
            displayName: "Allim",
            subtitle: "Default",
            previewAssetName: "AppIconPreview-Default"
        ),
        AppIconOption(
            alternateName: "AppIcon-Allim",
            displayName: "Cart",
            subtitle: "Classic",
            previewAssetName: "AppIconPreview-Allim"
        ),
        AppIconOption(
            alternateName: "AppIcon-Route",
            displayName: "Route",
            subtitle: "On the way",
            previewAssetName: "AppIconPreview-Route"
        ),
        AppIconOption(
            alternateName: "AppIcon-Notifi",
            displayName: "Notifi",
            subtitle: "Original",
            previewAssetName: "AppIconPreview-Notifi"
        )
    ]

    /// False on the handful of places alternate icons aren't allowed — an
    /// iPad's Home Screen in some configurations, and older simulators.
    var supportsAlternateIcons: Bool {
        UIApplication.shared.supportsAlternateIcons
    }

    private init() {
        currentIconName = UIApplication.shared.alternateIconName
    }

    func isSelected(_ option: AppIconOption) -> Bool {
        option.alternateName == currentIconName
    }

    /// Switches the home-screen icon. Tapping the icon already in use does
    /// nothing rather than asking iOS to set what's already set, which would
    /// put up the system alert for no change at all.
    func select(_ option: AppIconOption) {
        guard !isSelected(option) else { return }

        guard supportsAlternateIcons else {
            errorMessage = "This device doesn't allow changing the app icon."
            return
        }

        // Optimistic: the grid moves its checkmark now, and puts it back if
        // iOS turns the change down.
        let previous = currentIconName
        currentIconName = option.alternateName

        UIApplication.shared.setAlternateIconName(option.alternateName) { [weak self] error in
            Task { @MainActor in
                guard let self else { return }
                if let error {
                    self.currentIconName = previous
                    self.errorMessage = error.localizedDescription
                } else {
                    self.currentIconName = UIApplication.shared.alternateIconName
                }
            }
        }
    }
}
