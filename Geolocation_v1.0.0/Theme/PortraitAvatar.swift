//
//  PortraitAvatar.swift
//  Geolocation_v1.0.0
//
//  The illustrated portrait shown for anyone who hasn't set a profile photo,
//  in place of the letter avatar the app used to draw.
//

import UIKit

/// Draws the stand-in portraits, one per person.
///
/// Which of the eight portraits someone gets is derived from their name, so it is
/// the same on every screen, on every device, and across launches — and it
/// stays theirs until they upload a photo of their own. The portraits are
/// drawn once each and kept for the session; nothing is downloaded and nothing
/// is stored.
enum PortraitAvatar {

    /// How many distinct portraits there are to hand out.
    static var variantCount: Int { recipes.count }

    /// The portrait for a name, or nil for an empty one — a row with no name
    /// to draw from keeps the tinted circle.
    static func image(for name: String) -> UIImage? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return image(variant: variant(for: trimmed))
    }

    /// The portrait at a given position in the set.
    static func image(variant: Int) -> UIImage {
        let index = ((variant % variantCount) + variantCount) % variantCount
        let key = NSNumber(value: index)

        if let cached = cache.object(forKey: key) { return cached }
        let portrait = render(traits(variant: index))
        cache.setObject(portrait, forKey: key)
        return portrait
    }

    /// The portrait a name maps to. djb2 rather than `hashValue`, which is
    /// seeded per launch and would hand someone a new face every time the app
    /// opened.
    static func variant(for name: String) -> Int {
        var hash: UInt64 = 5381
        for scalar in name.unicodeScalars {
            hash = hash &* 33 &+ UInt64(scalar.value)
        }
        return Int(hash % UInt64(variantCount))
    }

    /// Drawn once each and kept for the session, with the OS free to reclaim
    /// them under memory pressure.
    private static let cache = NSCache<NSNumber, UIImage>()

    // MARK: - Traits

    /// Eight plain silhouettes. Anything with more character than this — a
    /// ponytail, twin tails, a blunt fringe — reads as a particular person
    /// rather than as a stand-in, so the set stays deliberately quiet.
    private enum HairStyle {
        case buzz, short, curls, afro, bob, wavy, long, bun

        /// Whether the cap needs sideburns to meet the ears. A buzz is already
        /// short enough, and an afro's silhouette covers them.
        var hasTemples: Bool {
            switch self {
            case .buzz, .afro: return false
            default: return true
            }
        }
    }

    private struct Traits {
        let skin: UIColor
        let hair: UIColor
        let clothing: UIColor
        let backdropCenter: UIColor
        let backdropEdge: UIColor
        let style: HairStyle
        let glasses: Bool
        /// Which way the hair is parted, so the hairline isn't the same band on
        /// every portrait.
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
        UIColor(red: 0.28, green: 0.18, blue: 0.12, alpha: 1),
        UIColor(red: 0.42, green: 0.28, blue: 0.16, alpha: 1),
        UIColor(red: 0.55, green: 0.38, blue: 0.22, alpha: 1),
        UIColor(red: 0.44, green: 0.20, blue: 0.12, alpha: 1),
        UIColor(red: 0.78, green: 0.62, blue: 0.36, alpha: 1),
        UIColor(red: 0.55, green: 0.54, blue: 0.56, alpha: 1),
    ]

    private static let clothingColors: [UIColor] = [
        UIColor(red: 0.79, green: 0.45, blue: 0.24, alpha: 1),
        UIColor(red: 0.42, green: 0.51, blue: 0.38, alpha: 1),
        UIColor(red: 0.31, green: 0.38, blue: 0.48, alpha: 1),
        UIColor(red: 0.85, green: 0.80, blue: 0.72, alpha: 1),
        UIColor(red: 0.57, green: 0.34, blue: 0.38, alpha: 1),
        UIColor(red: 0.33, green: 0.33, blue: 0.35, alpha: 1),
    ]

    /// Soft studio backdrops, one per category wash. The first colour pools
    /// behind the head, the second — a shade deeper — sits at the edges.
    ///
    /// Fixed values rather than dynamic tokens: a portrait is rendered once
    /// and cached as a bitmap, so it can't follow the user flipping appearance.
    /// The light washes are the ones that read behind a face in either scheme.
    private static let backdrops: [(UIColor, UIColor)] = [
        (UIColor(hex: 0xE7F4EC), UIColor(hex: 0xCFE8DA)), // produce
        (UIColor(hex: 0xE7F0FA), UIColor(hex: 0xCFE0F3)), // dairy
        (UIColor(hex: 0xF8EAE8), UIColor(hex: 0xEFD3CF)), // meat
        (UIColor(hex: 0xF8EFDD), UIColor(hex: 0xEEDFBD)), // pantry
        (UIColor(hex: 0xF8E9F0), UIColor(hex: 0xEED2E0)), // snacks
        (UIColor(hex: 0xEEEBF8), UIColor(hex: 0xDCD6F0)), // household
    ]

    /// One line per portrait, picked by hand rather than mixed from a seed:
    /// with only eight of them, every skin tone, hair colour and shirt is
    /// spoken for exactly where it reads best.
    private struct Recipe {
        let style: HairStyle
        let skin: Int
        let hair: Int
        let clothing: Int
        let backdrop: Int
        let glasses: Bool
    }

    private static let recipes: [Recipe] = [
        Recipe(style: .buzz,  skin: 1, hair: 0, clothing: 2, backdrop: 0, glasses: false),
        Recipe(style: .short, skin: 3, hair: 1, clothing: 1, backdrop: 4, glasses: false),
        Recipe(style: .curls, skin: 0, hair: 2, clothing: 4, backdrop: 2, glasses: true),
        Recipe(style: .afro,  skin: 4, hair: 0, clothing: 0, backdrop: 1, glasses: false),
        Recipe(style: .bob,   skin: 2, hair: 4, clothing: 5, backdrop: 3, glasses: false),
        Recipe(style: .wavy,  skin: 1, hair: 6, clothing: 3, backdrop: 5, glasses: true),
        Recipe(style: .long,  skin: 0, hair: 5, clothing: 2, backdrop: 2, glasses: false),
        Recipe(style: .bun,   skin: 3, hair: 3, clothing: 1, backdrop: 3, glasses: false),
    ]

    private static func traits(variant: Int) -> Traits {
        let recipe = recipes[variant % recipes.count]
        let backdrop = backdrops[recipe.backdrop]

        return Traits(
            skin: skinTones[recipe.skin],
            hair: hairColors[recipe.hair],
            clothing: clothingColors[recipe.clothing],
            backdropCenter: backdrop.0,
            backdropEdge: backdrop.1,
            style: recipe.style,
            glasses: recipe.glasses,
            partsLeft: variant % 2 == 0
        )
    }

    // MARK: - Drawing

    /// 240pt square: avatars draw at 92pt at the largest, so this stays sharp
    /// on a 3x screen without holding a camera-sized bitmap per person.
    private static let side: CGFloat = 240

    /// The palette's own near-black for the features, so a face doesn't run
    /// warmer than the type beside it.
    private static let ink = UIColor(hex: 0x16191C)

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
        let colors = [traits.backdropCenter.cgColor, traits.backdropEdge.cgColor] as CFArray

        guard let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0, 1]) else {
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
        cg.setFillColor(traits.skin.portraitShade(0.90).cgColor)
        fill(cg, rounded: box(0.437, 0.545, 0.126, 0.25), radius: 0.055)

        cg.setFillColor(traits.skin.portraitShade(0.82).cgColor)
        cg.fillEllipse(in: box(0.40, 0.50, 0.20, 0.13))

        cg.setFillColor(traits.clothing.cgColor)
        fill(cg, rounded: box(0.04, 0.76, 0.92, 0.45), radius: 0.24)

        // Collar: a darker crew neckline with the neck showing through it.
        cg.setFillColor(traits.clothing.portraitShade(0.86).cgColor)
        cg.fillEllipse(in: box(0.355, 0.715, 0.29, 0.16))
        cg.setFillColor(traits.skin.portraitShade(0.90).cgColor)
        cg.fillEllipse(in: box(0.383, 0.70, 0.234, 0.135))
    }

    /// Everything that sits behind the head: what falls past the jaw, and the
    /// silhouette that shows above it.
    private static func drawBackHair(_ cg: CGContext, traits: Traits) {
        cg.setFillColor(traits.hair.cgColor)

        switch traits.style {
        case .buzz, .short:
            break

        case .curls:
            for step in 0...6 {
                let angle = CGFloat.pi + CGFloat.pi * CGFloat(step) / 6
                let x = 0.5 + cos(angle) * 0.215
                let y = 0.44 + sin(angle) * 0.245
                cg.fillEllipse(in: box(x - 0.088, y - 0.088, 0.176, 0.176))
            }

        case .afro:
            cg.fillEllipse(in: box(0.195, 0.10, 0.61, 0.61))

        case .bob:
            fill(cg, rounded: box(0.264, 0.30, 0.472, 0.35), radius: 0.20)

        case .wavy:
            fill(cg, rounded: box(0.258, 0.30, 0.484, 0.38), radius: 0.20)
            for centerX in [0.31, 0.41, 0.59, 0.69] {
                cg.fillEllipse(in: box(CGFloat(centerX) - 0.06, 0.62, 0.12, 0.12))
            }

        case .long:
            fill(cg, rounded: box(0.262, 0.30, 0.476, 0.545), radius: 0.20)

        case .bun:
            cg.fillEllipse(in: box(0.425, 0.108, 0.15, 0.15))
        }
    }

    /// The hairline, clipped so it reads as hair lying over the skull rather
    /// than a hat.
    private static func drawHairCap(_ cg: CGContext, traits: Traits) {
        let part: CGFloat = traits.partsLeft ? 0.012 : -0.012

        // A buzz hugs the skull and starts lower, so it reads as cropped hair
        // rather than as a cap.
        let hairline: CGFloat = traits.style == .buzz ? 0.365 : 0.385
        let cap = traits.style == .buzz
            ? box(0.315 + part, 0.208, 0.37, 0.42)
            : box(0.289 + part, 0.19, 0.422, 0.47)

        cg.saveGState()
        cg.clip(to: box(0, 0, 1, hairline))
        cg.setFillColor(traits.hair.cgColor)
        cg.fillEllipse(in: cap)
        cg.restoreGState()

        if traits.style.hasTemples {
            cg.setFillColor(traits.hair.cgColor)
            fill(cg, rounded: box(0.292, 0.345, 0.045, 0.112), radius: 0.023)
            fill(cg, rounded: box(0.663, 0.345, 0.045, 0.112), radius: 0.023)
        }
    }

    private static func drawFace(_ cg: CGContext, traits: Traits) {
        drawCheek(cg, traits: traits, at: box(0.352, 0.478, 0.085, 0.055))
        drawCheek(cg, traits: traits, at: box(0.563, 0.478, 0.085, 0.055))

        // Brows.
        cg.setFillColor(traits.hair.portraitShade(0.80).cgColor)
        fill(cg, rounded: box(0.396, 0.401, 0.062, 0.014), radius: 0.008)
        fill(cg, rounded: box(0.542, 0.401, 0.062, 0.014), radius: 0.008)

        // Eyes.
        cg.setFillColor(ink.cgColor)
        cg.fillEllipse(in: box(0.408, 0.434, 0.038, 0.048))
        cg.fillEllipse(in: box(0.554, 0.434, 0.038, 0.048))

        // Nose: a shaded line rather than an outline, so it stays quiet at
        // avatar size.
        cg.setStrokeColor(traits.skin.portraitShade(0.78).cgColor)
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
        let warm = traits.skin.portraitShade(0.90)
        let colors = [
            warm.withAlphaComponent(0.45).cgColor,
            warm.withAlphaComponent(0).cgColor,
        ] as CFArray

        guard let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0, 1]) else { return }

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

    private static let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()

    /// A rect in fractions of the canvas, so the drawing above reads as
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

private extension UIColor {
    /// A shade of the same colour, for the neck under the chin and for brows
    /// that need to sit a little deeper than the hair.
    func portraitShade(_ factor: CGFloat) -> UIColor {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        guard getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return self }
        return UIColor(red: red * factor, green: green * factor, blue: blue * factor, alpha: alpha)
    }
}
