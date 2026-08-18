//
//  NavigationLauncher.swift
//  Geolocation_v1.0.0
//
//  Hands a store off to a map app with driving directions, so tapping "Go" on a
//  store proximity notification (including on the CarPlay screen) starts a route
//  the same way asking for directions inside Maps does.
//

import Foundation
import CoreLocation
import MapKit
import UIKit

/// A map app Allim can hand navigation off to.
///
/// iOS deliberately exposes no "user's default map app" API — there is no
/// setting to read — so the choice is a preference the user makes in Allim,
/// resolved against what's actually installed at launch time.
enum MapsApp: String, CaseIterable, Identifiable {
    case appleMaps
    case googleMaps
    case waze

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .appleMaps:  return "Apple Maps"
        case .googleMaps: return "Google Maps"
        case .waze:       return "Waze"
        }
    }

    /// URL used only to test whether the app is installed. Every scheme here must
    /// also be listed under `LSApplicationQueriesSchemes` in Info.plist, or
    /// `canOpenURL` answers `false` no matter what the user has installed.
    var probeURL: URL? {
        switch self {
        case .appleMaps:  return URL(string: "maps://")
        case .googleMaps: return URL(string: "comgooglemaps://")
        case .waze:       return URL(string: "waze://")
        }
    }

    var isInstalled: Bool {
        guard let probeURL else { return false }
        return UIApplication.shared.canOpenURL(probeURL)
    }
}

/// Where the user is being sent. The coordinate is optional because a
/// notification can outlive the geofence that produced it — without one we fall
/// back to searching the store by name, which is what Maps does anyway.
struct NavigationDestination: Equatable {
    let name: String
    let latitude: Double?
    let longitude: Double?

    init(name: String, latitude: Double? = nil, longitude: Double? = nil) {
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
    }

    init(name: String, coordinate: CLLocationCoordinate2D) {
        self.init(name: name, latitude: coordinate.latitude, longitude: coordinate.longitude)
    }

    var coordinate: CLLocationCoordinate2D? {
        guard let latitude, let longitude else { return nil }
        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        return CLLocationCoordinate2DIsValid(coordinate) ? coordinate : nil
    }
}

final class NavigationLauncher: ObservableObject {
    static let shared = NavigationLauncher()

    private static let preferenceKey = "preferredMapsApp"

    /// The app the user picked in Profile. Not necessarily the one directions open
    /// in — see `resolvedApp`.
    @Published var preferredApp: MapsApp {
        didSet { UserDefaults.standard.set(preferredApp.rawValue, forKey: Self.preferenceKey) }
    }

    /// A destination that arrived while the app was still coming to the foreground.
    /// Opening a URL only works from an active app, and a notification action is
    /// delivered before the launch finishes, so the hand-off waits here.
    private var pendingDestination: (destination: NavigationDestination, queuedAt: Date)?
    private var activationObserver: NSObjectProtocol?

    /// How long a deferred hand-off stays valid. Long enough to cover unlocking
    /// the phone at the wheel, short enough that opening Allim an hour later
    /// doesn't suddenly throw the user into turn-by-turn directions.
    private static let pendingDestinationLifetime: TimeInterval = 120

    private init() {
        let stored = UserDefaults.standard.string(forKey: Self.preferenceKey)
        preferredApp = stored.flatMap(MapsApp.init(rawValue:)) ?? .appleMaps
    }

    deinit {
        if let activationObserver {
            NotificationCenter.default.removeObserver(activationObserver)
        }
    }

    /// The app directions actually open in: the user's pick when it's installed,
    /// otherwise whatever else is on the device. Apple Maps is the last resort
    /// because it still has a web fallback when the app itself has been deleted.
    var resolvedApp: MapsApp {
        if preferredApp.isInstalled { return preferredApp }
        if let installed = MapsApp.allCases.first(where: { $0.isInstalled }) { return installed }
        return .appleMaps
    }

    /// What the Profile picker offers: everything installed, plus Apple Maps and
    /// the current pick so the picker always has a row matching the selection.
    var availableApps: [MapsApp] {
        MapsApp.allCases.filter { $0.isInstalled || $0 == .appleMaps || $0 == preferredApp }
    }

    // MARK: - Launching

    /// Opens driving directions to `destination` in the resolved map app.
    ///
    /// - Parameter allowDeferral: when the app isn't active yet, wait for it to
    ///   become active rather than opening now. Right for a `.foreground`
    ///   notification action, which is bringing the app up anyway; wrong for a
    ///   background one, where nothing is going to activate and the attempt has
    ///   to be made immediately even though iOS may refuse it.
    func startDirections(to destination: NavigationDestination, allowDeferral: Bool = true) {
        guard UIApplication.shared.applicationState == .active else {
            if allowDeferral {
                queue(destination)
            } else {
                #if DEBUG
                print("🧭 NavigationLauncher: attempting hand-off from the background")
                #endif
                open(destination, in: resolvedApp)
            }
            return
        }
        open(destination, in: resolvedApp)
    }

    private func queue(_ destination: NavigationDestination) {
        pendingDestination = (destination, Date())

        guard activationObserver == nil else { return }
        activationObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self, let pending = self.pendingDestination else { return }
            self.pendingDestination = nil
            if let activationObserver = self.activationObserver {
                NotificationCenter.default.removeObserver(activationObserver)
                self.activationObserver = nil
            }

            guard Date().timeIntervalSince(pending.queuedAt) <= Self.pendingDestinationLifetime else {
                #if DEBUG
                print("🧭 NavigationLauncher: discarding stale hand-off to '\(pending.destination.name)'")
                #endif
                return
            }
            self.open(pending.destination, in: self.resolvedApp)
        }
    }

    private func open(_ destination: NavigationDestination, in app: MapsApp) {
        #if DEBUG
        print("🧭 NavigationLauncher: directions to '\(destination.name)' via \(app.displayName)")
        #endif

        guard app != .appleMaps else {
            openInAppleMaps(destination)
            return
        }

        guard let url = Self.directionsURL(for: destination, in: app),
              UIApplication.shared.canOpenURL(url) else {
            openInAppleMaps(destination)
            return
        }

        UIApplication.shared.open(url, options: [:]) { [weak self] success in
            guard !success else { return }
            #if DEBUG
            print("   ⚠️ \(app.displayName) refused the URL, falling back to Apple Maps")
            #endif
            self?.openInAppleMaps(destination)
        }
    }

    private func openInAppleMaps(_ destination: NavigationDestination) {
        let launchOptions: [String: Any] = [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ]

        // With a coordinate, MKMapItem keeps the store's name on the destination
        // pin. Without one, the URL scheme lets Maps resolve the name to the
        // nearest branch itself.
        if let coordinate = destination.coordinate {
            let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
            mapItem.name = destination.name
            mapItem.openInMaps(launchOptions: launchOptions)
        } else if let url = Self.directionsURL(for: destination, in: .appleMaps) {
            UIApplication.shared.open(url)
        }
    }

    // MARK: - URL Construction

    /// Builds the directions URL for a map app. Pure and side-effect free so the
    /// query formats stay unit-testable.
    static func directionsURL(for destination: NavigationDestination, in app: MapsApp) -> URL? {
        let coordinate = destination.coordinate
        let query = destination.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

        switch app {
        case .appleMaps:
            // https://developer.apple.com/library/archive/featuredarticles/iPhoneURLScheme_Reference
            if let coordinate {
                return URL(string: "https://maps.apple.com/?daddr=\(coordinate.latitude),\(coordinate.longitude)&dirflg=d")
            }
            guard !encodedQuery.isEmpty else { return nil }
            return URL(string: "https://maps.apple.com/?daddr=\(encodedQuery)&dirflg=d")

        case .googleMaps:
            // comgooglemaps:// opens the installed Google Maps app straight into
            // the directions card; there is no web fallback here because
            // `resolvedApp` never picks an app that isn't installed.
            if let coordinate {
                return URL(string: "comgooglemaps://?daddr=\(coordinate.latitude),\(coordinate.longitude)&directionsmode=driving")
            }
            guard !encodedQuery.isEmpty else { return nil }
            return URL(string: "comgooglemaps://?daddr=\(encodedQuery)&directionsmode=driving")

        case .waze:
            if let coordinate {
                return URL(string: "waze://?ll=\(coordinate.latitude),\(coordinate.longitude)&navigate=yes")
            }
            guard !encodedQuery.isEmpty else { return nil }
            return URL(string: "waze://?q=\(encodedQuery)&navigate=yes")
        }
    }
}
