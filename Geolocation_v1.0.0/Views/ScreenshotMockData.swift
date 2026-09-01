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
            requesterId: "screenshot_\(handle)",
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
}

// MARK: - Drawn Portraits

/// Draws the stand-in profile photos for the mock friends.
///
/// The Share Store rows fall back to a letter avatar whenever a friend has no
/// picture, which is not what a store screenshot should show, and real photos
/// of real people are not ours to ship. So each mock person gets a flat
/// portrait illustration drawn here: a seeded but fixed combination of skin
/// tone, hair, clothing and background, generated once per launch and cached.
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
        let parts = body.split(separator: "/", maxSplits: 1)
        guard let first = parts.first, let index = Int(first) else { return nil }

        if let cached = cache[index] { return cached }
        let image = render(traits(index: index))
        cache[index] = image
        return image
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
        let backgroundTop: UIColor
        let backgroundBottom: UIColor
        let style: HairStyle
        let glasses: Bool
        let beard: Bool
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
            backgroundTop: backdrop.0,
            backgroundBottom: backdrop.1,
            style: style,
            glasses: index % 4 == 1,
            beard: index % 5 == 2 && style != .bob && style != .long && style != .bun
        )
    }

    // MARK: - Drawing

    /// 240pt square: the avatars draw at 46pt, so this stays sharp on a 3x
    /// screen without holding a camera-sized bitmap per friend.
    private static let side: CGFloat = 240

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
            let ink = UIColor(red: 0.20, green: 0.15, blue: 0.13, alpha: 1)

            drawBackdrop(cg, traits: traits)

            // Neck first, then the shoulders that cut across it.
            cg.setFillColor(traits.skin.darkened(by: 0.88).cgColor)
            fill(cg, rounded: box(0.437, 0.555, 0.126, 0.23), radius: 0.05)

            cg.setFillColor(traits.clothing.cgColor)
            fill(cg, rounded: box(0.04, 0.755, 0.92, 0.45), radius: 0.24)

            drawBackHair(cg, traits: traits)

            // Head and ears.
            cg.setFillColor(traits.skin.cgColor)
            cg.fillEllipse(in: box(0.278, 0.425, 0.055, 0.078))
            cg.fillEllipse(in: box(0.667, 0.425, 0.055, 0.078))
            cg.fillEllipse(in: box(0.30, 0.205, 0.40, 0.47))

            drawHairCap(cg, traits: traits)
            drawFace(cg, traits: traits, ink: ink)
        }
    }

    private static func drawBackdrop(_ cg: CGContext, traits: Traits) {
        let space = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        let colors = [traits.backgroundTop.cgColor, traits.backgroundBottom.cgColor] as CFArray

        if let gradient = CGGradient(colorsSpace: space, colors: colors, locations: [0, 1]) {
            cg.drawLinearGradient(
                gradient,
                start: CGPoint(x: 0, y: 0),
                end: CGPoint(x: 0, y: side),
                options: []
            )
        } else {
            cg.setFillColor(traits.backgroundTop.cgColor)
            cg.fill(CGRect(x: 0, y: 0, width: side, height: side))
        }
    }

    /// The hair that sits behind the head: what falls past the jaw, and the
    /// silhouette that shows above it.
    private static func drawBackHair(_ cg: CGContext, traits: Traits) {
        cg.setFillColor(traits.hair.cgColor)

        switch traits.style {
        case .long:
            fill(cg, rounded: box(0.258, 0.235, 0.484, 0.60), radius: 0.20)
        case .bob:
            fill(cg, rounded: box(0.262, 0.245, 0.476, 0.40), radius: 0.21)
        case .curls:
            let center = CGPoint(x: 0.5, y: 0.44)
            for step in 0...6 {
                let angle = CGFloat.pi + CGFloat.pi * CGFloat(step) / 6
                let x = center.x + cos(angle) * 0.215
                let y = center.y + sin(angle) * 0.245
                cg.fillEllipse(in: box(x - 0.085, y - 0.085, 0.17, 0.17))
            }
        case .bun:
            cg.fillEllipse(in: box(0.42, 0.115, 0.16, 0.16))
        case .short, .buzz:
            break
        }
    }

    /// The hairline itself, clipped so it reads as hair lying over the skull
    /// rather than a hat.
    private static func drawHairCap(_ cg: CGContext, traits: Traits) {
        // A buzz sits tighter to the skull and starts a little lower, so it
        // reads as cropped hair rather than as a cap.
        let hairline: CGFloat = traits.style == .buzz ? 0.365 : 0.385
        let cap = traits.style == .buzz
            ? box(0.293, 0.199, 0.414, 0.45)
            : box(0.283, 0.19, 0.434, 0.47)

        cg.saveGState()
        cg.clip(to: box(0, 0, 1, hairline))
        cg.setFillColor(traits.hair.cgColor)
        cg.fillEllipse(in: cap)
        cg.restoreGState()

        // Temples, so the cap meets the ears instead of floating above them.
        if traits.style == .short || traits.style == .bob || traits.style == .curls {
            cg.setFillColor(traits.hair.cgColor)
            fill(cg, rounded: box(0.288, 0.345, 0.048, 0.115), radius: 0.024)
            fill(cg, rounded: box(0.664, 0.345, 0.048, 0.115), radius: 0.024)
        }
    }

    private static func drawFace(_ cg: CGContext, traits: Traits, ink: UIColor) {
        if traits.beard {
            cg.saveGState()
            cg.clip(to: box(0, 0.52, 1, 0.20))
            cg.setFillColor(traits.hair.cgColor)
            cg.fillEllipse(in: box(0.315, 0.25, 0.37, 0.42))
            cg.restoreGState()
        }

        // Brows, eyes, mouth.
        cg.setFillColor(traits.hair.darkened(by: 0.85).cgColor)
        fill(cg, rounded: box(0.392, 0.398, 0.068, 0.017), radius: 0.009)
        fill(cg, rounded: box(0.540, 0.398, 0.068, 0.017), radius: 0.009)

        cg.setFillColor(ink.cgColor)
        cg.fillEllipse(in: box(0.404, 0.432, 0.044, 0.054))
        cg.fillEllipse(in: box(0.552, 0.432, 0.044, 0.054))

        let mouth = UIBezierPath()
        mouth.move(to: point(0.452, 0.545))
        mouth.addQuadCurve(to: point(0.548, 0.545), controlPoint: point(0.5, 0.588))
        cg.setStrokeColor(ink.withAlphaComponent(0.85).cgColor)
        cg.setLineWidth(side * 0.016)
        cg.setLineCap(.round)
        cg.addPath(mouth.cgPath)
        cg.strokePath()

        if traits.glasses {
            cg.setStrokeColor(ink.withAlphaComponent(0.75).cgColor)
            cg.setLineWidth(side * 0.013)
            stroke(cg, rounded: box(0.368, 0.410, 0.116, 0.098), radius: 0.032)
            stroke(cg, rounded: box(0.516, 0.410, 0.116, 0.098), radius: 0.032)
            cg.move(to: point(0.484, 0.452))
            cg.addLine(to: point(0.516, 0.452))
            cg.strokePath()
        }
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
        let path = UIBezierPath(roundedRect: rect, cornerRadius: radius * side)
        cg.addPath(path.cgPath)
        cg.fillPath()
    }

    private static func stroke(_ cg: CGContext, rounded rect: CGRect, radius: CGFloat) {
        let path = UIBezierPath(roundedRect: rect, cornerRadius: radius * side)
        cg.addPath(path.cgPath)
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
