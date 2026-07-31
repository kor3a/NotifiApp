//
//  BackgroundTheme.swift
//  Geolocation_v1.0.0
//
//  Per-screen custom backgrounds for subscribers.
//

import SwiftUI

// MARK: - Background Surface

/// A screen that can carry its own background.
///
/// Each surface stores its choice independently, so a user can give Stores a
/// warm sand background while Reminders stays on the default gradient.
enum BackgroundSurface: Hashable, Identifiable {
    case stores
    case reminders
    /// A single conversation. Backgrounds are per-conversation, so each chat
    /// carries its own look (matching how iMessage/WhatsApp handle this).
    case conversation(id: String)

    var id: String { storageSuffix }

    /// Surfaces that are offered as a single global choice. `.conversation`
    /// is excluded because it is picked per chat, not once for all chats.
    static let globalSurfaces: [BackgroundSurface] = [.stores, .reminders]

    var displayName: String {
        switch self {
        case .stores:       return "Stores"
        case .reminders:    return "Reminders"
        case .conversation: return "Conversation"
        }
    }

    private var storageSuffix: String {
        switch self {
        case .stores:              return "stores"
        case .reminders:           return "reminders"
        case .conversation(let id): return "conversation_\(id)"
        }
    }

    /// UserDefaults key holding the solid color chosen for this surface.
    var colorStorageKey: String { "backgroundColor_\(storageSuffix)" }
}

// MARK: - Background Color Palette

/// The solid background colors a subscriber can choose from.
///
/// Every color ships a light and a dark variant. The variants are deliberately
/// low-saturation — content sits on `.ultraThinMaterial` cards, which pick up
/// the backdrop, so anything vivid would bleed into the cards and hurt text
/// contrast. These stay light in light mode and deep in dark mode so
/// `.primary` / `.secondary` text keeps its system contrast on both.
enum AppBackgroundColor: String, CaseIterable, Identifiable {
    /// The app's original gradient. Also the fallback when a subscription lapses.
    case system

    case graphite
    case slate
    case midnight
    case ocean
    case teal
    case forest
    case sage
    case sand
    case apricot
    case rose
    case plum
    case lavender

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system:    return "Default"
        case .graphite:  return "Graphite"
        case .slate:     return "Slate"
        case .midnight:  return "Midnight"
        case .ocean:     return "Ocean"
        case .teal:      return "Teal"
        case .forest:    return "Forest"
        case .sage:      return "Sage"
        case .sand:      return "Sand"
        case .apricot:   return "Apricot"
        case .rose:      return "Rose"
        case .plum:      return "Plum"
        case .lavender:  return "Lavender"
        }
    }

    /// Every choice except the default gradient, in palette order.
    static var selectableColors: [AppBackgroundColor] {
        allCases.filter { $0 != .system }
    }

    /// The flat fill for this choice. `.system` has no flat fill — callers
    /// render `Color.backgroundGradient(for:)` for that case instead.
    func fill(for colorScheme: ColorScheme) -> Color {
        let isDark = colorScheme == .dark
        switch self {
        case .system:
            return isDark ? Color(red: 0.12, green: 0.12, blue: 0.17)
                          : Color(red: 0.92, green: 0.94, blue: 0.97)
        case .graphite:
            return isDark ? Color(red: 0.11, green: 0.11, blue: 0.12)
                          : Color(red: 0.93, green: 0.93, blue: 0.95)
        case .slate:
            return isDark ? Color(red: 0.12, green: 0.14, blue: 0.18)
                          : Color(red: 0.90, green: 0.92, blue: 0.95)
        case .midnight:
            return isDark ? Color(red: 0.05, green: 0.06, blue: 0.11)
                          : Color(red: 0.85, green: 0.87, blue: 0.94)
        case .ocean:
            return isDark ? Color(red: 0.06, green: 0.13, blue: 0.21)
                          : Color(red: 0.86, green: 0.92, blue: 0.98)
        case .teal:
            return isDark ? Color(red: 0.05, green: 0.16, blue: 0.16)
                          : Color(red: 0.85, green: 0.94, blue: 0.93)
        case .forest:
            return isDark ? Color(red: 0.06, green: 0.14, blue: 0.10)
                          : Color(red: 0.87, green: 0.94, blue: 0.88)
        case .sage:
            return isDark ? Color(red: 0.11, green: 0.14, blue: 0.11)
                          : Color(red: 0.91, green: 0.93, blue: 0.86)
        case .sand:
            return isDark ? Color(red: 0.15, green: 0.13, blue: 0.09)
                          : Color(red: 0.96, green: 0.93, blue: 0.86)
        case .apricot:
            return isDark ? Color(red: 0.18, green: 0.12, blue: 0.08)
                          : Color(red: 0.99, green: 0.91, blue: 0.84)
        case .rose:
            return isDark ? Color(red: 0.17, green: 0.10, blue: 0.12)
                          : Color(red: 0.98, green: 0.90, blue: 0.91)
        case .plum:
            return isDark ? Color(red: 0.16, green: 0.10, blue: 0.17)
                          : Color(red: 0.94, green: 0.88, blue: 0.95)
        case .lavender:
            return isDark ? Color(red: 0.13, green: 0.11, blue: 0.20)
                          : Color(red: 0.93, green: 0.91, blue: 0.98)
        }
    }
}

// MARK: - Preferences Store

/// Stores each surface's background choice locally on the device.
///
/// Kept in UserDefaults rather than Firestore: a background is a per-device
/// look, and writing it to Firestore on every tap would cost a network round
/// trip for a purely cosmetic setting.
final class BackgroundPreferences: ObservableObject {
    static let shared = BackgroundPreferences()

    private let defaults: UserDefaults

    /// Bumped on every change so views observing this object re-render.
    @Published private var revision: Int = 0

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// The color chosen for a surface, or `.system` if the user never picked one.
    func backgroundColor(for surface: BackgroundSurface) -> AppBackgroundColor {
        guard let raw = defaults.string(forKey: surface.colorStorageKey),
              let color = AppBackgroundColor(rawValue: raw) else {
            return .system
        }
        return color
    }

    func setBackgroundColor(_ color: AppBackgroundColor, for surface: BackgroundSurface) {
        if color == .system {
            defaults.removeObject(forKey: surface.colorStorageKey)
        } else {
            defaults.set(color.rawValue, forKey: surface.colorStorageKey)
        }
        revision &+= 1
    }

    /// Clears every stored background. Used when signing out so the next
    /// account on this device starts from the default look.
    func resetAll() {
        for surface in BackgroundSurface.globalSurfaces {
            defaults.removeObject(forKey: surface.colorStorageKey)
        }
        for key in defaults.dictionaryRepresentation().keys
        where key.hasPrefix("backgroundColor_conversation_") {
            defaults.removeObject(forKey: key)
        }
        revision &+= 1
    }
}

// MARK: - Background View

/// The background layer for a surface — the user's chosen color when they're
/// subscribed, the app's default gradient otherwise.
///
/// The subscription check lives here rather than at selection time so a lapsed
/// subscription falls back to the default look without erasing what the user
/// picked; resubscribing brings their color straight back.
struct SurfaceBackground: View {
    let surface: BackgroundSurface

    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var preferences = BackgroundPreferences.shared
    @ObservedObject private var subscriptionManager = SubscriptionManager.shared

    private var selection: AppBackgroundColor {
        guard subscriptionManager.isSubscribed else { return .system }
        return preferences.backgroundColor(for: surface)
    }

    var body: some View {
        Group {
            if selection == .system {
                Color.backgroundGradient(for: colorScheme)
            } else {
                selection.fill(for: colorScheme)
            }
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.25), value: selection)
    }
}

extension View {
    /// Places the surface's background behind this view.
    func surfaceBackground(_ surface: BackgroundSurface) -> some View {
        background(SurfaceBackground(surface: surface))
    }
}
