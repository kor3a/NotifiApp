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
    /// Not drawn — the picker shows the artwork alone — but VoiceOver reads
    /// it, so every option still needs a name.
    let displayName: String
    /// The image drawn in the picker. The icon assets themselves aren't
    /// loadable by name at runtime, so every option carries a plain imageset
    /// holding the same artwork.
    let previewAssetName: String
    /// The same artwork at banner size, for the notifications that lead with
    /// the app's mark rather than the system's grey silhouette.
    let notificationAvatarAssetName: String

    var id: String { alternateName ?? "primary" }
}

/// Where the notification banners read the current icon's mark from.
///
/// Neither reader can ask UIKit which icon is on. `NotificationManager`
/// schedules its banners from Firestore listener callbacks, off the main
/// thread; `NotifiNotificationService` is a separate process with no
/// `UIApplication` at all. So the app exports the chosen mark into the shared
/// App Group container — the same route `WidgetDataStore` sends store logos —
/// and both read the file from there.
///
/// The reading half of this lives in `NotificationService.swift` too, and the
/// two have to keep naming the same file.
enum NotificationAvatarStore {

    private static let appGroupSuite = "group.com.kor3a.nearbuy"
    /// Deliberately one fixed name rather than one file per icon: the reader
    /// wants the current mark, not a choice, and a single file leaves nothing
    /// behind when the user switches icons.
    static let fileName = "NotificationAvatar.png"

    static var fileURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupSuite)?
            .appendingPathComponent(fileName)
    }

    /// The exported mark, or nil before the first export — on a fresh install,
    /// or when the container is unavailable. Callers fall back to the artwork
    /// they ship with.
    static var currentAvatarData: Data? {
        guard let fileURL else { return nil }
        return try? Data(contentsOf: fileURL)
    }

    /// Writes `assetName`'s artwork out as the mark banners will wear.
    ///
    /// Off the main thread: the caller is a launch path or an icon tap, and
    /// neither should wait on a file write. Failing is quiet — a banner with
    /// the previously exported mark, or the shipped one, beats no banner.
    static func export(assetName: String) {
        DispatchQueue.global(qos: .utility).async {
            guard
                let fileURL,
                let data = UIImage(named: assetName)?.pngData()
            else { return }

            try? data.write(to: fileURL, options: .atomic)
        }
    }
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
    ///
    /// All three wear the same storefront mark and differ only in colour, so
    /// the names are colours rather than shapes.
    ///
    /// Pink's `alternateName` still says "Storefront" — that is the name iOS
    /// has recorded for everyone already using it, and renaming the asset would
    /// quietly reset them to the shipped icon on the next launch. The asset
    /// keeps the old name; only what the user hears changed.
    static let options: [AppIconOption] = [
        AppIconOption(
            alternateName: nil,
            displayName: "Teal",
            previewAssetName: "AppIconPreview-Default",
            notificationAvatarAssetName: "AllimNotificationAvatar"
        ),
        AppIconOption(
            alternateName: "AppIcon-Storefront",
            displayName: "Pink",
            previewAssetName: "AppIconPreview-Storefront",
            notificationAvatarAssetName: "AllimNotificationAvatar-Storefront"
        ),
        AppIconOption(
            alternateName: "AppIcon-Wash",
            displayName: "Wash",
            previewAssetName: "AppIconPreview-Wash",
            notificationAvatarAssetName: "AllimNotificationAvatar-Wash"
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

    /// Re-exports the current icon's mark for the notification banners.
    ///
    /// Called at launch as well as on every change: the picker is not the only
    /// way an icon arrives — someone already wearing Pink before the banners
    /// followed the icon has never tapped anything for this to hang off, and a
    /// reinstall empties the container.
    func exportNotificationAvatar() {
        let option = Self.options.first { $0.alternateName == currentIconName }
            ?? Self.options[0]
        NotificationAvatarStore.export(assetName: option.notificationAvatarAssetName)
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
                // Either way: the notification banners follow whichever icon
                // the app actually ended up wearing.
                self.exportNotificationAvatar()
            }
        }
    }
}
