//
//  ScreenshotMockData.swift
//  Geolocation_v1.0.0
//
//  Debug-only stand-in friends and family used to fill the Share Store sheet
//  for App Store screenshots. None of this data is written to Firestore, and
//  the whole file compiles out of Release builds.
//

#if DEBUG
import Foundation
import Combine

/// Holds the debug switch for the mock recipient lists, and builds them.
///
/// Turn it on from Profile → Debug → "Mock Friends (Screenshots)", then open
/// Share Store on any store: the Friends tab shows the names below instead of
/// the account's real friendships. The switch is remembered across launches so
/// a screenshot run survives a rebuild.
final class ScreenshotMockStore: ObservableObject {
    static let shared = ScreenshotMockStore()

    private static let defaultsKey = "debug.mockFriendsEnabled"

    @Published var isEnabled: Bool {
        didSet { UserDefaults.standard.set(isEnabled, forKey: Self.defaultsKey) }
    }

    private init() {
        // The launch argument lets a screenshot scheme switch the mocks on
        // without going through Profile first.
        isEnabled = UserDefaults.standard.bool(forKey: Self.defaultsKey)
            || ProcessInfo.processInfo.arguments.contains("-mockFriends")
    }

    // MARK: - Mock Friendships

    /// Nine friends, enough to fill the Friends tab past the fold.
    func friends(currentUserId: String) -> [Friendship] {
        let people: [(String, String)] = [
            ("Alex Rivera",     "alex.rivera"),
            ("Priya Sharma",    "priya.sharma"),
            ("Jordan Lee",      "jordan.lee"),
            ("Sofia Martinez",  "sofia.martinez"),
            ("Daniel Kim",      "daniel.kim"),
            ("Emma Chen",       "emma.chen"),
            ("Marcus Johnson",  "marcus.johnson"),
            ("Olivia Brooks",   "olivia.brooks"),
            ("Noah Patel",      "noah.patel"),
        ]
        return people.enumerated().map { index, person in
            friendship(
                index: index,
                name: person.0,
                handle: person.1,
                currentUserId: currentUserId
            )
        }
    }

    /// A small family list, so the other tab isn't empty behind the screenshot.
    func family(currentUserId: String) -> [Friendship] {
        let people: [(String, String)] = [
            ("Mom",             "mom"),
            ("Dad",             "dad"),
            ("Hannah Brooks",   "hannah.brooks"),
        ]
        return people.enumerated().map { index, person in
            friendship(
                index: index + 100,
                name: person.0,
                handle: person.1,
                currentUserId: currentUserId
            )
        }
    }

    /// The mock is always the requester and the signed-in user the receiver, so
    /// `friendName(currentUserId:)` resolves to the mock's name on every screen.
    private func friendship(
        index: Int,
        name: String,
        handle: String,
        currentUserId: String
    ) -> Friendship {
        let now = Date().timeIntervalSince1970
        let age = Double(index + 1) * 86_400

        return Friendship(
            id: "screenshot_fs_\(handle)",
            requesterId: "screenshot_\(handle)",
            requesterName: name,
            requesterEmail: "\(handle)@example.com",
            requesterProfilePictureURL: nil,
            receiverId: currentUserId,
            receiverName: "You",
            receiverEmail: "you@example.com",
            receiverProfilePictureURL: nil,
            status: .accepted,
            createdAt: now - age - 3_600,
            acceptedAt: now - age
        )
    }
}
#endif
