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
/// Which of the 24 portraits someone gets is derived from their name, so it is
/// the same on every screen, on every device, and across launches — and it
/// stays theirs until they upload a photo of their own. The portraits are
/// drawn once each and kept for the session; nothing is downloaded and nothing
/// is stored.
enum PortraitAvatar {

    /// How many distinct portraits there are to hand out.
    static let variantCount = 24

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

    private enum HairStyle: CaseIterable {
        case short, long, buzz, bob, curls, bun, fringe, ponytail, wavy, afro, twintails, locs

        /// Styles that read wrong in blonde or grey — a buzz or a head of locs
        /// wants a colour with some weight behind it.
        var prefersDarkHair: Bool {
            switch self {
            case .buzz, .locs, .afro, .curls: return true
            default: return false
            }
        }

        var allowsBeard: Bool {
            switch self {
            case .short, .buzz, .curls, .locs, .afro: return true
            default: return false
            }
        }

        /// Whether the cap needs sideburns to meet the ears.
        var hasTemples: Bool {
            switch self {
            case .short, .bob, .curls, .fringe, .ponytail, .wavy, .twintails, .locs: return true
            default: return false
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
        let beard: Bool
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

    /// The first five are the dark half, which the styles above draw from.
    private static let hairColors: [UIColor] = [
        UIColor(red: 0.16, green: 0.12, blue: 0.10, alpha: 1),
        UIColor(red: 0.28, green: 0.18, blue: 0.12, alpha: 1),
        UIColor(red: 0.42, green: 0.28, blue: 0.16, alpha: 1),
        UIColor(red: 0.55, green: 0.38, blue: 0.22, alpha: 1),
        UIColor(red: 0.44, green: 0.20, blue: 0.12, alpha: 1),
        UIColor(red: 0.66, green: 0.36, blue: 0.18, alpha: 1),
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

    /// Soft studio backdrops in the app's own palette. The first colour pools
    /// behind the head, the second sits at the edges.
    private static let backdrops: [(UIColor, UIColor)] = [
        (UIColor(red: 0.98, green: 0.91, blue: 0.83, alpha: 1), UIColor(red: 0.94, green: 0.83, blue: 0.72, alpha: 1)),
        (UIColor(red: 0.89, green: 0.92, blue: 0.85, alpha: 1), UIColor(red: 0.78, green: 0.85, blue: 0.76, alpha: 1)),
        (UIColor(red: 0.93, green: 0.90, blue: 0.87, alpha: 1), UIColor(red: 0.84, green: 0.80, blue: 0.76, alpha: 1)),
        (UIColor(red: 0.97, green: 0.88, blue: 0.80, alpha: 1), UIColor(red: 0.91, green: 0.76, blue: 0.65, alpha: 1)),
        (UIColor(red: 0.87, green: 0.90, blue: 0.94, alpha: 1), UIColor(red: 0.76, green: 0.82, blue: 0.89, alpha: 1)),
        (UIColor(red: 0.95, green: 0.93, blue: 0.86, alpha: 1), UIColor(red: 0.88, green: 0.84, blue: 0.73, alpha: 1)),
    ]

    /// Every portrait gets its own combination: the style walks the list so all
    /// twelve appear, and the colours come off a mixed seed so neighbouring
    /// variants don't come out as near-twins.
    private static func traits(variant: Int) -> Traits {
        let mixed = (UInt64(variant) &* 2_654_435_761) % 1_000_003
        let style = HairStyle.allCases[variant % HairStyle.allCases.count]

        let hairIndex = style.prefersDarkHair
            ? Int((mixed / 5) % 5)
            : Int((mixed / 5) % UInt64(hairColors.count))
        let backdrop = backdrops[Int((mixed / 180) % UInt64(backdrops.count))]

        return Traits(
            skin: skinTones[Int(mixed % UInt64(skinTones.count))],
            hair: hairColors[hairIndex],
            clothing: clothingColors[Int((mixed / 30) % UInt64(clothingColors.count))],
            backdropCenter: backdrop.0,
            backdropEdge: backdrop.1,
            style: style,
            glasses: (mixed / 1_080) % 4 == 1,
            beard: (mixed / 4_320) % 3 == 0 && style.allowsBeard,
            partsLeft: variant % 2 == 0
        )
    }

    // MARK: - Drawing

    /// 240pt square: avatars draw at 92pt at the largest, so this stays sharp
    /// on a 3x screen without holding a camera-sized bitmap per person.
    private static let side: CGFloat = 240

    /// A warm near-black for the features, so faces don't go colder than the
    /// rest of the palette.
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
        case .short, .buzz:
            break

        case .long:
            fill(cg, rounded: box(0.262, 0.30, 0.476, 0.545), radius: 0.20)

        case .bob:
            fill(cg, rounded: box(0.264, 0.30, 0.472, 0.35), radius: 0.20)

        case .fringe:
            fill(cg, rounded: box(0.264, 0.30, 0.472, 0.37), radius: 0.20)

        case .curls:
            for step in 0...6 {
                let angle = CGFloat.pi + CGFloat.pi * CGFloat(step) / 6
                let x = 0.5 + cos(angle) * 0.215
                let y = 0.44 + sin(angle) * 0.245
                cg.fillEllipse(in: box(x - 0.088, y - 0.088, 0.176, 0.176))
            }

        case .afro:
            cg.fillEllipse(in: box(0.195, 0.10, 0.61, 0.61))

        case .bun:
            cg.fillEllipse(in: box(0.425, 0.108, 0.15, 0.15))

        case .ponytail:
            fill(cg, rounded: box(0.665, 0.285, 0.155, 0.34), radius: 0.075)
            cg.setFillColor(traits.hair.portraitShade(0.80).cgColor)
            cg.fillEllipse(in: box(0.645, 0.285, 0.09, 0.075))
            cg.setFillColor(traits.hair.cgColor)

        case .wavy:
            fill(cg, rounded: box(0.258, 0.30, 0.484, 0.38), radius: 0.20)
            for centerX in [0.31, 0.41, 0.59, 0.69] {
                cg.fillEllipse(in: box(CGFloat(centerX) - 0.06, 0.62, 0.12, 0.12))
            }

        case .twintails:
            cg.fillEllipse(in: box(0.178, 0.445, 0.15, 0.23))
            cg.fillEllipse(in: box(0.672, 0.445, 0.15, 0.23))
            fill(cg, rounded: box(0.268, 0.30, 0.464, 0.24), radius: 0.18)

        case .locs:
            for x in [0.225, 0.288, 0.651, 0.714] {
                fill(cg, rounded: box(CGFloat(x), 0.30, 0.062, 0.45), radius: 0.031)
            }
        }
    }

    /// The hairline, clipped so it reads as hair lying over the skull rather
    /// than a hat.
    private static func drawHairCap(_ cg: CGContext, traits: Traits) {
        let part: CGFloat = traits.partsLeft ? 0.012 : -0.012

        let hairline: CGFloat
        let cap: CGRect
        switch traits.style {
        case .buzz:
            // A buzz hugs the skull and starts lower, so it reads as cropped
            // hair rather than as a cap.
            hairline = 0.365
            cap = box(0.315 + part, 0.208, 0.37, 0.42)
        case .fringe:
            // Blunt bangs sit low and level — no parting.
            hairline = 0.428
            cap = box(0.286, 0.19, 0.428, 0.47)
        default:
            hairline = 0.385
            cap = box(0.289 + part, 0.19, 0.422, 0.47)
        }

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
        if traits.beard {
            cg.saveGState()
            cg.clip(to: box(0, 0.525, 1, 0.195))
            cg.setFillColor(traits.hair.cgColor)
            cg.fillEllipse(in: box(0.322, 0.25, 0.356, 0.42))
            cg.restoreGState()
        }

        drawCheek(cg, traits: traits, at: box(0.352, 0.478, 0.085, 0.055))
        drawCheek(cg, traits: traits, at: box(0.563, 0.478, 0.085, 0.055))

        // Brows — a blunt fringe covers them.
        if traits.style != .fringe {
            cg.setFillColor(traits.hair.portraitShade(0.80).cgColor)
            fill(cg, rounded: box(0.396, 0.401, 0.062, 0.014), radius: 0.008)
            fill(cg, rounded: box(0.542, 0.401, 0.062, 0.014), radius: 0.008)
        }

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
