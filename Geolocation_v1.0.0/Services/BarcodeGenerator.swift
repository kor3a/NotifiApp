//
//  BarcodeGenerator.swift
//  Geolocation_v1.0.0
//
//  Created on 7/27/26.
//

import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

/// Renders a membership number into a scannable barcode image using Core Image.
///
/// Core Image emits the code at its natural (tiny) module size, so the result is
/// scaled up with interpolation disabled — smoothing the edges is what makes a
/// rendered barcode unreadable to a scanner.
enum BarcodeGenerator {
    private static let context = CIContext(options: [.useSoftwareRenderer: false])
    private static let cache = NSCache<NSString, UIImage>()

    /// Whether `value` can be encoded in `symbology`.
    static func canEncode(_ value: String, symbology: BarcodeSymbology) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        guard symbology.requiresASCII else { return true }
        return trimmed.data(using: .ascii) != nil
    }

    /// A black-on-white barcode for `value`, or `nil` when the value can't be
    /// encoded in the requested symbology.
    ///
    /// - Parameter scale: pixels per barcode module. 10 keeps a typical loyalty
    ///   number crisp at the width this app renders it.
    static func image(for value: String, symbology: BarcodeSymbology, scale: CGFloat = 10) -> UIImage? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard canEncode(trimmed, symbology: symbology) else { return nil }

        let cacheKey = "\(symbology.rawValue)|\(Int(scale))|\(trimmed)" as NSString
        if let cached = cache.object(forKey: cacheKey) {
            return cached
        }

        // Code 128 needs ASCII; the 2D generators take UTF-8.
        let messageData: Data
        if symbology.requiresASCII {
            guard let ascii = trimmed.data(using: .ascii) else { return nil }
            messageData = ascii
        } else {
            messageData = Data(trimmed.utf8)
        }

        guard let output = ciImage(from: messageData, symbology: symbology),
              let cgImage = context.createCGImage(output, from: output.extent) else {
            return nil
        }

        let rendered = upscale(UIImage(cgImage: cgImage), by: scale)
        cache.setObject(rendered, forKey: cacheKey)
        return rendered
    }

    // MARK: - Private

    private static func ciImage(from message: Data, symbology: BarcodeSymbology) -> CIImage? {
        switch symbology {
        case .code128:
            let filter = CIFilter.code128BarcodeGenerator()
            filter.message = message
            // Quiet zone on both ends — scanners need it to find the code.
            filter.quietSpace = 8
            return filter.outputImage
        case .qr:
            let filter = CIFilter.qrCodeGenerator()
            filter.message = message
            filter.correctionLevel = "M"
            return filter.outputImage
        case .pdf417:
            let filter = CIFilter.pdf417BarcodeGenerator()
            filter.message = message
            return filter.outputImage
        case .aztec:
            let filter = CIFilter.aztecCodeGenerator()
            filter.message = message
            return filter.outputImage
        }
    }

    /// Nearest-neighbour upscale. `UIImage.draw` is used rather than
    /// `CGContext.draw` so the flipped renderer context doesn't mirror 2D codes.
    private static func upscale(_ image: UIImage, by scale: CGFloat) -> UIImage {
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true

        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            context.cgContext.setFillColor(UIColor.white.cgColor)
            context.cgContext.fill(CGRect(origin: .zero, size: size))
            context.cgContext.interpolationQuality = .none
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
