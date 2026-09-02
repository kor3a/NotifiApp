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
import UIKit

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
        // The offset lands this trio on faces that suit them — the traits are
        // fixed per index, and 51 puts the beard on Dad rather than on Mom.
        return people.enumerated().map { index, person in
            friendship(
                index: index + 51,
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
            // The chat header prints the other participant's id as their
            // handle, so these read as usernames rather than as row keys.
            requesterId: Self.username(for: handle),
            requesterName: name,
            requesterEmail: "\(handle)@example.com",
            // A drawn portrait rather than nil, so the rows show faces instead
            // of letter avatars in a store screenshot.
            requesterProfilePictureURL: ScreenshotAvatarFactory.url(index: index, handle: handle),
            receiverId: currentUserId,
            receiverName: "You",
            receiverEmail: "you@example.com",
            receiverProfilePictureURL: nil,
            status: .accepted,
            createdAt: now - age - 3_600,
            acceptedAt: now - age
        )
    }

    // MARK: - Mock Conversations

    /// The chat the conversation screenshot is taken in.
    static let openConversationId = "screenshot_conv_alex"

    /// A mock person's id, which the app also shows as their @handle.
    private static func username(for handle: String) -> String {
        handle.replacingOccurrences(of: ".", with: "")
    }

    private static let alexId = username(for: "alex.rivera")
    private static let priyaId = username(for: "priya.sharma")
    private static let momId = username(for: "mom")

    /// The Messages list: the chat below, plus two quieter ones behind it.
    func conversations(currentUserId: String) -> [Conversation] {
        let now = Date().timeIntervalSince1970

        return [
            Conversation(
                id: Self.openConversationId,
                participantIds: [currentUserId, Self.alexId],
                participantNames: [currentUserId: "You", Self.alexId: "Alex Rivera"],
                createdAt: now - 7_200,
                lastMessageContent: "All done ✅ Home by 6.",
                lastMessageAt: now - 360,
                lastMessageSenderId: Self.alexId,
                unreadCount: [currentUserId: 0]
            ),
            Conversation(
                id: "screenshot_conv_priya",
                participantIds: [currentUserId, Self.priyaId],
                participantNames: [currentUserId: "You", Self.priyaId: "Priya Sharma"],
                createdAt: now - 200_000,
                lastMessageContent: "Picked them up on the way home 🙌",
                lastMessageAt: now - 10_680,
                lastMessageSenderId: currentUserId,
                unreadCount: [currentUserId: 0]
            ),
            Conversation(
                id: "screenshot_conv_mom",
                participantIds: [currentUserId, Self.momId],
                participantNames: [currentUserId: "You", Self.momId: "Mom"],
                createdAt: now - 400_000,
                lastMessageContent: "Don't forget the milk! 🥛",
                lastMessageAt: now - 90_000,
                lastMessageSenderId: Self.momId,
                unreadCount: [currentUserId: 2]
            ),
        ]
    }

    /// The portraits the conversation list and chat headers draw, keyed by the
    /// participant they belong to.
    var conversationAvatarURLs: [String: String] {
        [
            Self.alexId: ScreenshotAvatarFactory.url(index: 0, handle: "alex.rivera"),
            Self.priyaId: ScreenshotAvatarFactory.url(index: 1, handle: "priya.sharma"),
            Self.momId: ScreenshotAvatarFactory.url(index: 51, handle: "mom"),
        ]
    }

    /// Unread messages across the mock list, for the tab badge.
    var unreadCount: Int { 2 }

    /// The chat with a mock contact. Anyone without a scripted conversation
    /// gets a fresh empty one, so messaging any mock friend opens a chat
    /// rather than doing nothing.
    func conversation(with contact: Contact, currentUserId: String) -> Conversation {
        if let scripted = conversations(currentUserId: currentUserId)
            .first(where: { $0.participantIds.contains(contact.id) }) {
            return scripted
        }

        return Conversation(
            id: "screenshot_conv_\(contact.id)",
            participantIds: [currentUserId, contact.id],
            participantNames: [currentUserId: "You", contact.id: contact.name],
            createdAt: Date().timeIntervalSince1970,
            lastMessageContent: nil,
            lastMessageAt: nil,
            lastMessageSenderId: nil,
            unreadCount: [currentUserId: 0]
        )
    }

    /// One line of a scripted chat: who sent it, how long ago, what it says and
    /// what it carries.
    private struct Line {
        let fromFriend: Bool
        let minutesAgo: Double
        let content: String
        var photos: [ScreenshotPhotoFactory.Shot] = []
    }

    /// The messages in a mock chat, oldest first — the order the real listener
    /// hands them over in.
    func messages(for conversationId: String, currentUserId: String) -> [Message] {
        let script: [Line]
        let friendId: String
        let friendName: String

        switch conversationId {
        case Self.openConversationId:
            friendId = Self.alexId
            friendName = "Alex Rivera"
            script = [
                Line(fromFriend: true, minutesAgo: 62, content: "Heading to Whole Foods in 20 — need anything?"),
                Line(fromFriend: false, minutesAgo: 61, content: "Yes please 🙏 oat milk and a sourdough loaf if they have it"),
                Line(fromFriend: true, minutesAgo: 58, content: "These two?", photos: [.shelf, .bread]),
                Line(fromFriend: false, minutesAgo: 57, content: "Perfect — that's the ones 👌"),
                Line(fromFriend: false, minutesAgo: 55, content: "Here's the rest of the list if you're up for it", photos: [.list]),
                Line(fromFriend: true, minutesAgo: 54, content: "Easy. I'll add them to the Whole Foods list so it pings you there"),
                Line(fromFriend: false, minutesAgo: 53, content: "You're a lifesaver"),
                Line(fromFriend: true, minutesAgo: 6, content: "All done ✅ Home by 6."),
            ]
        case "screenshot_conv_priya":
            friendId = Self.priyaId
            friendName = "Priya Sharma"
            script = [
                Line(fromFriend: true, minutesAgo: 182, content: "Did you get the eggs?"),
                Line(fromFriend: false, minutesAgo: 178, content: "Picked them up on the way home 🙌"),
            ]
        case "screenshot_conv_mom":
            friendId = Self.momId
            friendName = "Mom"
            script = [
                Line(fromFriend: false, minutesAgo: 1_520, content: "At the store now — anything you need?"),
                Line(fromFriend: true, minutesAgo: 1_500, content: "Don't forget the milk! 🥛"),
            ]
        default:
            return []
        }

        let now = Date().timeIntervalSince1970

        return script.enumerated().map { index, line in
            Message(
                id: "\(conversationId)_m\(index)",
                conversationId: conversationId,
                senderId: line.fromFriend ? friendId : currentUserId,
                senderName: line.fromFriend ? friendName : "You",
                content: line.content,
                createdAt: now - line.minutesAgo * 60,
                isRead: true,
                photoURLs: line.photos.isEmpty ? nil : line.photos.map { ScreenshotPhotoFactory.url($0) },
                linkedReminder: nil,
                linkedStore: nil
            )
        }
    }
}

// MARK: - Drawn Portraits

/// Draws the stand-in profile photos for the mock friends.
///
/// The Share Store rows fall back to a letter avatar whenever a friend has no
/// picture, which is not what a store screenshot should show, and real photos
/// of real people are not ours to ship. So each mock person gets a flat
/// portrait illustration drawn here: a fixed combination of skin tone, hair,
/// clothing and backdrop, generated once per launch and cached.
///
/// `ProfileImageCache` recognises the `mock-avatar://` URLs these portraits are
/// addressed by and hands the drawn image straight back, so every screen that
/// already shows a friend's picture shows the portrait with no extra wiring.
enum ScreenshotAvatarFactory {

    static let urlScheme = "mock-avatar"

    /// The URL a mock friendship carries as its profile picture.
    static func url(index: Int, handle: String) -> String {
        "\(urlScheme)://\(index)/\(handle)"
    }

    /// The portrait for one of those URLs, or nil for any other string.
    static func image(forMockURL urlString: String) -> UIImage? {
        let prefix = "\(urlScheme)://"
        guard urlString.hasPrefix(prefix) else { return nil }

        let body = urlString.dropFirst(prefix.count)
        guard let first = body.split(separator: "/", maxSplits: 1).first,
              let index = Int(first) else { return nil }

        if let cached = cache[index] { return cached }
        let portrait = render(traits(index: index))
        cache[index] = portrait
        return portrait
    }

    private static var cache: [Int: UIImage] = [:]

    // MARK: - Traits

    private enum HairStyle {
        case buzz, short, bob, long, bun, curls
    }

    private struct Traits {
        let skin: UIColor
        let hair: UIColor
        let clothing: UIColor
        let backdropCenter: UIColor
        let backdropEdge: UIColor
        let style: HairStyle
        let glasses: Bool
        let beard: Bool
        /// Which way the hair is parted, so the hairline isn't a flat band on
        /// every face in the list.
        let partsLeft: Bool
    }

    private static let skinTones: [UIColor] = [
        UIColor(red: 0.96, green: 0.82, blue: 0.72, alpha: 1),
        UIColor(red: 0.89, green: 0.71, blue: 0.57, alpha: 1),
        UIColor(red: 0.78, green: 0.58, blue: 0.44, alpha: 1),
        UIColor(red: 0.62, green: 0.43, blue: 0.31, alpha: 1),
        UIColor(red: 0.45, green: 0.30, blue: 0.22, alpha: 1),
    ]

    private static let hairColors: [UIColor] = [
        UIColor(red: 0.16, green: 0.12, blue: 0.10, alpha: 1),
        UIColor(red: 0.35, green: 0.22, blue: 0.13, alpha: 1),
        UIColor(red: 0.53, green: 0.35, blue: 0.19, alpha: 1),
        UIColor(red: 0.72, green: 0.55, blue: 0.31, alpha: 1),
        UIColor(red: 0.44, green: 0.20, blue: 0.12, alpha: 1),
        UIColor(red: 0.42, green: 0.42, blue: 0.44, alpha: 1),
    ]

    private static let clothingColors: [UIColor] = [
        UIColor(red: 0.79, green: 0.45, blue: 0.24, alpha: 1),
        UIColor(red: 0.42, green: 0.51, blue: 0.38, alpha: 1),
        UIColor(red: 0.31, green: 0.38, blue: 0.48, alpha: 1),
        UIColor(red: 0.85, green: 0.80, blue: 0.72, alpha: 1),
        UIColor(red: 0.57, green: 0.34, blue: 0.38, alpha: 1),
        UIColor(red: 0.33, green: 0.33, blue: 0.35, alpha: 1),
    ]

    /// Soft studio backdrops, in the same earthy family as the rest of the app.
    /// The first colour sits behind the head, the second at the edges.
    private static let backdrops: [(UIColor, UIColor)] = [
        (UIColor(red: 0.98, green: 0.91, blue: 0.83, alpha: 1), UIColor(red: 0.94, green: 0.83, blue: 0.72, alpha: 1)),
        (UIColor(red: 0.89, green: 0.92, blue: 0.85, alpha: 1), UIColor(red: 0.78, green: 0.85, blue: 0.76, alpha: 1)),
        (UIColor(red: 0.93, green: 0.90, blue: 0.87, alpha: 1), UIColor(red: 0.84, green: 0.80, blue: 0.76, alpha: 1)),
        (UIColor(red: 0.97, green: 0.88, blue: 0.80, alpha: 1), UIColor(red: 0.91, green: 0.76, blue: 0.65, alpha: 1)),
        (UIColor(red: 0.87, green: 0.90, blue: 0.94, alpha: 1), UIColor(red: 0.76, green: 0.82, blue: 0.89, alpha: 1)),
        (UIColor(red: 0.95, green: 0.93, blue: 0.86, alpha: 1), UIColor(red: 0.88, green: 0.84, blue: 0.73, alpha: 1)),
    ]

    private static let hairStyles: [HairStyle] = [.short, .long, .buzz, .bob, .curls, .bun]

    /// Fixed per position in the mock list, so a given friend keeps their face
    /// between launches and between screenshots.
    private static func traits(index: Int) -> Traits {
        let backdrop = backdrops[index % backdrops.count]
        let style = hairStyles[index % hairStyles.count]

        return Traits(
            skin: skinTones[(index * 3 + 1) % skinTones.count],
            hair: hairColors[(index * 5 + 1) % hairColors.count],
            clothing: clothingColors[(index * 4 + 2) % clothingColors.count],
            backdropCenter: backdrop.0,
            backdropEdge: backdrop.1,
            style: style,
            glasses: index % 4 == 1,
            beard: index % 5 == 2 && style != .bob && style != .long && style != .bun,
            partsLeft: index % 2 == 0
        )
    }

    // MARK: - Drawing

    /// 240pt square: the avatars draw at 46pt, so this stays sharp on a 3x
    /// screen without holding a camera-sized bitmap per friend.
    private static let side: CGFloat = 240

    /// The ink the features are drawn in — a warm near-black, so the faces
    /// don't go colder than the rest of the palette.
    private static let ink = UIColor(red: 0.22, green: 0.16, blue: 0.14, alpha: 1)

    private static func render(_ traits: Traits) -> UIImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true

        let renderer = UIGraphicsImageRenderer(
            size: CGSize(width: side, height: side),
            format: format
        )

        return renderer.image { context in
            let cg = context.cgContext

            drawBackdrop(cg, traits: traits)
            drawNeckAndShoulders(cg, traits: traits)
            drawBackHair(cg, traits: traits)

            // Ears, then the head over them.
            cg.setFillColor(traits.skin.cgColor)
            cg.fillEllipse(in: box(0.281, 0.428, 0.053, 0.075))
            cg.fillEllipse(in: box(0.666, 0.428, 0.053, 0.075))
            cg.fillEllipse(in: box(0.307, 0.205, 0.386, 0.47))

            drawHairCap(cg, traits: traits)
            drawFace(cg, traits: traits)
        }
    }

    /// A soft pool of light behind the head, rather than a flat wash.
    private static func drawBackdrop(_ cg: CGContext, traits: Traits) {
        let space = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        let colors = [traits.backdropCenter.cgColor, traits.backdropEdge.cgColor] as CFArray

        guard let gradient = CGGradient(colorsSpace: space, colors: colors, locations: [0, 1]) else {
            cg.setFillColor(traits.backdropCenter.cgColor)
            cg.fill(CGRect(x: 0, y: 0, width: side, height: side))
            return
        }

        let center = point(0.5, 0.42)
        cg.drawRadialGradient(
            gradient,
            startCenter: center,
            startRadius: 0,
            endCenter: center,
            endRadius: side * 0.78,
            options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
        )
    }

    /// The neck, the shadow the chin casts on it, and the shirt that cuts
    /// across the bottom of the frame.
    private static func drawNeckAndShoulders(_ cg: CGContext, traits: Traits) {
        cg.setFillColor(traits.skin.darkened(by: 0.90).cgColor)
        fill(cg, rounded: box(0.437, 0.545, 0.126, 0.25), radius: 0.055)

        cg.setFillColor(traits.skin.darkened(by: 0.82).cgColor)
        cg.fillEllipse(in: box(0.40, 0.50, 0.20, 0.13))

        cg.setFillColor(traits.clothing.cgColor)
        fill(cg, rounded: box(0.04, 0.76, 0.92, 0.45), radius: 0.24)

        // Collar: a darker crew neckline with the shoulder line of the neck
        // showing through it.
        cg.setFillColor(traits.clothing.darkened(by: 0.86).cgColor)
        cg.fillEllipse(in: box(0.355, 0.715, 0.29, 0.16))
        cg.setFillColor(traits.skin.darkened(by: 0.90).cgColor)
        cg.fillEllipse(in: box(0.383, 0.70, 0.234, 0.135))
    }

    /// The hair that sits behind the head: what falls past the jaw, and the
    /// silhouette that shows above it.
    private static func drawBackHair(_ cg: CGContext, traits: Traits) {
        cg.setFillColor(traits.hair.cgColor)

        switch traits.style {
        case .long:
            fill(cg, rounded: box(0.252, 0.235, 0.496, 0.60), radius: 0.21)
        case .bob:
            fill(cg, rounded: box(0.258, 0.245, 0.484, 0.40), radius: 0.22)
        case .curls:
            for step in 0...6 {
                let angle = CGFloat.pi + CGFloat.pi * CGFloat(step) / 6
                let x = 0.5 + cos(angle) * 0.215
                let y = 0.44 + sin(angle) * 0.245
                cg.fillEllipse(in: box(x - 0.088, y - 0.088, 0.176, 0.176))
            }
        case .bun:
            cg.fillEllipse(in: box(0.425, 0.108, 0.15, 0.15))
        case .short, .buzz:
            break
        }
    }

    /// The hairline itself, clipped so it reads as hair lying over the skull
    /// rather than a hat.
    private static func drawHairCap(_ cg: CGContext, traits: Traits) {
        let part: CGFloat = traits.partsLeft ? 0.012 : -0.012
        // A buzz hugs the skull and starts a little lower, so it reads as
        // cropped hair rather than as a cap.
        let hairline: CGFloat = traits.style == .buzz ? 0.368 : 0.388
        let cap = traits.style == .buzz
            ? box(0.315 + part, 0.208, 0.37, 0.42)
            : box(0.289 + part, 0.19, 0.422, 0.47)

        cg.saveGState()
        cg.clip(to: box(0, 0, 1, hairline))
        cg.setFillColor(traits.hair.cgColor)
        cg.fillEllipse(in: cap)
        cg.restoreGState()

        // Temples, so the cap meets the ears instead of floating above them.
        if traits.style == .short || traits.style == .bob || traits.style == .curls {
            cg.setFillColor(traits.hair.cgColor)
            fill(cg, rounded: box(0.292, 0.345, 0.045, 0.112), radius: 0.023)
            fill(cg, rounded: box(0.663, 0.345, 0.045, 0.112), radius: 0.023)
        }
    }

    private static func drawFace(_ cg: CGContext, traits: Traits) {
        if traits.beard {
            cg.saveGState()
            cg.clip(to: box(0, 0.525, 1, 0.195))
            cg.setFillColor(traits.hair.cgColor)
            cg.fillEllipse(in: box(0.322, 0.25, 0.356, 0.42))
            cg.restoreGState()
        }

        drawCheek(cg, traits: traits, at: box(0.352, 0.478, 0.085, 0.055))
        drawCheek(cg, traits: traits, at: box(0.563, 0.478, 0.085, 0.055))

        // Brows.
        cg.setFillColor(traits.hair.darkened(by: 0.80).cgColor)
        fill(cg, rounded: box(0.396, 0.401, 0.062, 0.014), radius: 0.008)
        fill(cg, rounded: box(0.542, 0.401, 0.062, 0.014), radius: 0.008)

        // Eyes.
        cg.setFillColor(ink.cgColor)
        cg.fillEllipse(in: box(0.408, 0.434, 0.038, 0.048))
        cg.fillEllipse(in: box(0.554, 0.434, 0.038, 0.048))

        // Nose: a shaded line rather than an outline, so it stays quiet at
        // avatar size.
        cg.setStrokeColor(traits.skin.darkened(by: 0.78).cgColor)
        cg.setLineWidth(side * 0.012)
        cg.setLineCap(.round)
        cg.move(to: point(0.5, 0.487))
        cg.addLine(to: point(0.5, 0.517))
        cg.strokePath()

        // Mouth.
        let mouth = UIBezierPath()
        mouth.move(to: point(0.449, 0.552))
        mouth.addQuadCurve(to: point(0.551, 0.552), controlPoint: point(0.5, 0.596))
        cg.setStrokeColor(ink.withAlphaComponent(0.85).cgColor)
        cg.setLineWidth(side * 0.015)
        cg.addPath(mouth.cgPath)
        cg.strokePath()

        if traits.glasses {
            cg.setStrokeColor(ink.withAlphaComponent(0.75).cgColor)
            cg.setLineWidth(side * 0.012)
            stroke(cg, rounded: box(0.368, 0.412, 0.114, 0.094), radius: 0.032)
            stroke(cg, rounded: box(0.518, 0.412, 0.114, 0.094), radius: 0.032)
            cg.move(to: point(0.482, 0.452))
            cg.addLine(to: point(0.518, 0.452))
            cg.strokePath()
        }
    }

    /// A blush that fades out at its edge — a hard-edged circle would read as a
    /// blemish at full size.
    private static func drawCheek(_ cg: CGContext, traits: Traits, at rect: CGRect) {
        let space = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        let warm = traits.skin.darkened(by: 0.90)
        let colors = [
            warm.withAlphaComponent(0.45).cgColor,
            warm.withAlphaComponent(0).cgColor,
        ] as CFArray

        guard let gradient = CGGradient(colorsSpace: space, colors: colors, locations: [0, 1]) else { return }

        cg.saveGState()
        cg.clip(to: rect)
        let center = CGPoint(x: rect.midX, y: rect.midY)
        cg.drawRadialGradient(
            gradient,
            startCenter: center,
            startRadius: 0,
            endCenter: center,
            endRadius: rect.width / 2,
            options: []
        )
        cg.restoreGState()
    }

    // MARK: - Geometry Helpers

    /// A rect given in fractions of the canvas, so the drawing above reads as
    /// proportions rather than pixel counts.
    private static func box(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat) -> CGRect {
        CGRect(x: x * side, y: y * side, width: width * side, height: height * side)
    }

    private static func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
        CGPoint(x: x * side, y: y * side)
    }

    private static func fill(_ cg: CGContext, rounded rect: CGRect, radius: CGFloat) {
        cg.addPath(UIBezierPath(roundedRect: rect, cornerRadius: radius * side).cgPath)
        cg.fillPath()
    }

    private static func stroke(_ cg: CGContext, rounded rect: CGRect, radius: CGFloat) {
        cg.addPath(UIBezierPath(roundedRect: rect, cornerRadius: radius * side).cgPath)
        cg.strokePath()
    }
}

// MARK: - Drawn Chat Photos

/// Draws the photos the mock friends "send" in a conversation.
///
/// Same bargain as the portraits: a chat screenshot needs pictures in the
/// bubbles, and shipping someone's real kitchen photos isn't an option, so the
/// three shots below are drawn from primitives in the app's own palette.
/// `PhotoAttachmentsView` recognises the `mock-photo://` URLs and draws these
/// instead of reaching for the network.
enum ScreenshotPhotoFactory {

    static let urlScheme = "mock-photo"

    /// The three shots a mock conversation can attach.
    enum Shot: String, CaseIterable {
        /// Cartons on a shelf, for "is this the oat milk you meant?".
        case shelf
        /// A loaf on a board.
        case bread
        /// A handwritten-looking shopping list.
        case list
    }

    static func url(_ shot: Shot) -> String {
        "\(urlScheme)://\(shot.rawValue)"
    }

    /// The photo for one of those URLs, or nil for any other string.
    static func image(forMockURL urlString: String) -> UIImage? {
        let prefix = "\(urlScheme)://"
        guard urlString.hasPrefix(prefix),
              let shot = Shot(rawValue: String(urlString.dropFirst(prefix.count))) else { return nil }

        if let cached = cache[shot] { return cached }
        let photo = render(shot)
        cache[shot] = photo
        return photo
    }

    private static var cache: [Shot: UIImage] = [:]

    // MARK: - Drawing

    private static let width: CGFloat = 480
    private static let height: CGFloat = 360

    private static func render(_ shot: Shot) -> UIImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true

        let renderer = UIGraphicsImageRenderer(
            size: CGSize(width: width, height: height),
            format: format
        )

        return renderer.image { context in
            let cg = context.cgContext
            switch shot {
            case .shelf: drawShelf(cg)
            case .bread: drawBread(cg)
            case .list:  drawList(cg)
            }
        }
    }

    /// Cartons and a jar on a kitchen shelf.
    private static func drawShelf(_ cg: CGContext) {
        drawBackdrop(cg, top: rgb(0.95, 0.91, 0.85), bottom: rgb(0.87, 0.81, 0.73))

        // Shelf, its front edge, and the wall below it.
        cg.setFillColor(rgb(0.70, 0.52, 0.35).cgColor)
        cg.fill(box(0, 0.70, 1, 0.06))
        cg.setFillColor(rgb(0.55, 0.39, 0.26).cgColor)
        cg.fill(box(0, 0.76, 1, 0.03))
        cg.setFillColor(rgb(0.83, 0.77, 0.70).cgColor)
        cg.fill(box(0, 0.79, 1, 0.21))

        // What each item casts back onto the shelf.
        cg.setFillColor(rgb(0.78, 0.70, 0.62).cgColor)
        cg.fillEllipse(in: box(0.22, 0.665, 0.16, 0.05))
        cg.fillEllipse(in: box(0.36, 0.665, 0.26, 0.05))
        cg.fillEllipse(in: box(0.63, 0.665, 0.16, 0.05))

        // Jar.
        cg.setFillColor(rgb(0.86, 0.63, 0.31).cgColor)
        fill(cg, rounded: box(0.22, 0.38, 0.14, 0.32), radius: 0.03)
        cg.setFillColor(rgb(0.45, 0.42, 0.38).cgColor)
        fill(cg, rounded: box(0.235, 0.335, 0.11, 0.06), radius: 0.02)
        cg.setFillColor(rgb(0.95, 0.92, 0.86).cgColor)
        fill(cg, rounded: box(0.245, 0.47, 0.09, 0.10), radius: 0.015)

        // The carton in the middle — the one being asked about.
        cg.setFillColor(rgb(0.97, 0.96, 0.92).cgColor)
        fill(cg, rounded: box(0.375, 0.28, 0.23, 0.42), radius: 0.015)
        cg.setFillColor(rgb(0.93, 0.91, 0.87).cgColor)
        cg.move(to: point(0.375, 0.30))
        cg.addLine(to: point(0.49, 0.185))
        cg.addLine(to: point(0.605, 0.30))
        cg.closePath()
        cg.fillPath()
        cg.setFillColor(rgb(0.64, 0.74, 0.53).cgColor)
        fill(cg, rounded: box(0.468, 0.165, 0.045, 0.045), radius: 0.012)
        fill(cg, rounded: box(0.405, 0.375, 0.17, 0.19), radius: 0.02)

        // Label: a couple of bars and a mark standing in for the print.
        cg.setFillColor(rgb(0.96, 0.96, 0.93).cgColor)
        fill(cg, rounded: box(0.425, 0.405, 0.13, 0.022), radius: 0.01)
        cg.setFillColor(rgb(0.90, 0.93, 0.86).cgColor)
        fill(cg, rounded: box(0.425, 0.445, 0.09, 0.018), radius: 0.009)
        cg.setFillColor(rgb(0.96, 0.96, 0.93).cgColor)
        cg.fillEllipse(in: box(0.44, 0.485, 0.07, 0.05))

        // Carton behind it on the right.
        cg.setFillColor(rgb(0.57, 0.66, 0.75).cgColor)
        fill(cg, rounded: box(0.63, 0.34, 0.15, 0.36), radius: 0.015)
        cg.setFillColor(rgb(0.42, 0.50, 0.58).cgColor)
        fill(cg, rounded: box(0.665, 0.305, 0.055, 0.05), radius: 0.012)
        cg.setFillColor(rgb(0.86, 0.90, 0.93).cgColor)
        fill(cg, rounded: box(0.655, 0.44, 0.10, 0.10), radius: 0.02)
    }

    /// A round loaf on a wooden board.
    private static func drawBread(_ cg: CGContext) {
        drawBackdrop(cg, top: rgb(0.94, 0.92, 0.88), bottom: rgb(0.85, 0.82, 0.77))

        cg.setFillColor(rgb(0.80, 0.77, 0.72).cgColor)
        cg.fillEllipse(in: box(0.16, 0.60, 0.68, 0.16))

        cg.setFillColor(rgb(0.72, 0.53, 0.34).cgColor)
        fill(cg, rounded: box(0.14, 0.55, 0.72, 0.22), radius: 0.04)
        cg.setFillColor(rgb(0.79, 0.60, 0.40).cgColor)
        fill(cg, rounded: box(0.14, 0.55, 0.72, 0.05), radius: 0.02)

        cg.setFillColor(rgb(0.80, 0.56, 0.30).cgColor)
        cg.fillEllipse(in: box(0.26, 0.26, 0.48, 0.36))
        cg.setFillColor(rgb(0.87, 0.66, 0.40).cgColor)
        cg.fillEllipse(in: box(0.30, 0.29, 0.40, 0.26))

        // Scoring across the crust.
        cg.setStrokeColor(rgb(0.60, 0.38, 0.19).cgColor)
        cg.setLineWidth(width * 0.012)
        cg.setLineCap(.round)
        for start in [0.40, 0.47, 0.54] {
            cg.move(to: point(CGFloat(start), 0.335))
            cg.addLine(to: point(CGFloat(start) + 0.06, 0.415))
            cg.strokePath()
        }

        // Crumbs.
        cg.setFillColor(rgb(0.72, 0.55, 0.36).cgColor)
        cg.fillEllipse(in: box(0.20, 0.70, 0.03, 0.02))
        cg.fillEllipse(in: box(0.79, 0.71, 0.025, 0.018))
    }

    /// A shopping list on a table, a couple of lines already ticked off.
    private static func drawList(_ cg: CGContext) {
        drawBackdrop(cg, top: rgb(0.60, 0.44, 0.31), bottom: rgb(0.48, 0.34, 0.24))

        // The paper, with its own shadow offset behind it.
        cg.setFillColor(rgb(0.72, 0.62, 0.52).cgColor)
        fill(cg, rounded: box(0.185, 0.10, 0.63, 0.81), radius: 0.025)
        cg.setFillColor(rgb(0.98, 0.97, 0.94).cgColor)
        fill(cg, rounded: box(0.17, 0.08, 0.63, 0.81), radius: 0.025)

        // Title bar.
        cg.setFillColor(rgb(0.79, 0.45, 0.24).cgColor)
        fill(cg, rounded: box(0.215, 0.145, 0.30, 0.05), radius: 0.012)

        // Rows: a box, a tick on the ones already bought, and a line of "text".
        let rows: [(y: CGFloat, width: CGFloat, isDone: Bool)] = [
            (0.26, 0.34, true),
            (0.35, 0.28, true),
            (0.44, 0.36, false),
            (0.53, 0.31, false),
            (0.62, 0.38, false),
            (0.71, 0.26, false),
        ]

        for row in rows {
            cg.setStrokeColor(rgb(0.55, 0.52, 0.49).cgColor)
            cg.setLineWidth(width * 0.006)
            stroke(cg, rounded: box(0.215, row.y, 0.045, 0.045), radius: 0.01)

            if row.isDone {
                cg.setStrokeColor(rgb(0.42, 0.51, 0.38).cgColor)
                cg.setLineWidth(width * 0.009)
                cg.setLineCap(.round)
                cg.setLineJoin(.round)
                cg.move(to: point(0.225, row.y + 0.024))
                cg.addLine(to: point(0.2375, row.y + 0.036))
                cg.addLine(to: point(0.2525, row.y + 0.011))
                cg.strokePath()
            }

            cg.setFillColor((row.isDone ? rgb(0.72, 0.70, 0.68) : rgb(0.40, 0.38, 0.36)).cgColor)
            fill(cg, rounded: box(0.28, row.y + 0.013, row.width, 0.019), radius: 0.009)

            // Struck through once it's in the basket.
            if row.isDone {
                cg.setStrokeColor(rgb(0.72, 0.70, 0.68).cgColor)
                cg.setLineWidth(width * 0.005)
                cg.move(to: point(0.28, row.y + 0.0225))
                cg.addLine(to: point(0.28 + row.width, row.y + 0.0225))
                cg.strokePath()
            }
        }
    }

    // MARK: - Helpers

    private static func drawBackdrop(_ cg: CGContext, top: UIColor, bottom: UIColor) {
        let space = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        let colors = [top.cgColor, bottom.cgColor] as CFArray

        guard let gradient = CGGradient(colorsSpace: space, colors: colors, locations: [0, 1]) else {
            cg.setFillColor(top.cgColor)
            cg.fill(CGRect(x: 0, y: 0, width: width, height: height))
            return
        }

        cg.drawLinearGradient(
            gradient,
            start: CGPoint(x: 0, y: 0),
            end: CGPoint(x: 0, y: height),
            options: []
        )
    }

    private static func rgb(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat) -> UIColor {
        UIColor(red: red, green: green, blue: blue, alpha: 1)
    }

    /// A rect in fractions of the canvas, so the drawing reads as proportions.
    private static func box(_ x: CGFloat, _ y: CGFloat, _ boxWidth: CGFloat, _ boxHeight: CGFloat) -> CGRect {
        CGRect(x: x * width, y: y * height, width: boxWidth * width, height: boxHeight * height)
    }

    private static func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
        CGPoint(x: x * width, y: y * height)
    }

    /// Corner radii are fractions of the width, so a rounded rect keeps the
    /// same corner whatever its own proportions.
    private static func fill(_ cg: CGContext, rounded rect: CGRect, radius: CGFloat) {
        cg.addPath(UIBezierPath(roundedRect: rect, cornerRadius: radius * width).cgPath)
        cg.fillPath()
    }

    private static func stroke(_ cg: CGContext, rounded rect: CGRect, radius: CGFloat) {
        cg.addPath(UIBezierPath(roundedRect: rect, cornerRadius: radius * width).cgPath)
        cg.strokePath()
    }
}

private extension UIColor {
    /// A shade of the same colour, for the neck under the chin and for brows
    /// that need to sit a little deeper than the hair.
    func darkened(by factor: CGFloat) -> UIColor {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        guard getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return self }
        return UIColor(red: red * factor, green: green * factor, blue: blue * factor, alpha: alpha)
    }
}

#endif
