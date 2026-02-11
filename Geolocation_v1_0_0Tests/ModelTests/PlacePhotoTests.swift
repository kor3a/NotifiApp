//
//  PlacePhotoTests.swift
//  Geolocation_v1_0_0Tests
//

import XCTest
@testable import Geolocation_v1_0_0

final class PlacePhotoTests: XCTestCase {

    private func makePhoto(width: Int, height: Int) -> PlacePhoto {
        return PlacePhoto(
            photoReference: "test_ref_\(width)x\(height)",
            height: height,
            width: width,
            htmlAttributions: nil
        )
    }

    // MARK: - aspectRatio

    func testAspectRatio_landscape() {
        let photo = makePhoto(width: 1600, height: 900)
        XCTAssertEqual(photo.aspectRatio, 1600.0 / 900.0, accuracy: 0.01)
    }

    func testAspectRatio_portrait() {
        let photo = makePhoto(width: 900, height: 1600)
        XCTAssertEqual(photo.aspectRatio, 900.0 / 1600.0, accuracy: 0.01)
    }

    func testAspectRatio_square() {
        let photo = makePhoto(width: 1000, height: 1000)
        XCTAssertEqual(photo.aspectRatio, 1.0, accuracy: 0.01)
    }

    // MARK: - isLandscape

    func testIsLandscape_true() {
        let photo = makePhoto(width: 1600, height: 900)
        XCTAssertTrue(photo.isLandscape)
    }

    func testIsLandscape_false_portrait() {
        let photo = makePhoto(width: 900, height: 1600)
        XCTAssertFalse(photo.isLandscape)
    }

    func testIsLandscape_false_square() {
        let photo = makePhoto(width: 1000, height: 1000)
        XCTAssertFalse(photo.isLandscape)
    }

    // MARK: - isLikelyStorefront

    func testIsLikelyStorefront_idealRatio() {
        // 1.5:1 ratio - ideal storefront
        let photo = makePhoto(width: 1500, height: 1000)
        XCTAssertTrue(photo.isLikelyStorefront)
    }

    func testIsLikelyStorefront_minBoundary() {
        // 1.2:1 ratio - minimum for storefront
        let photo = makePhoto(width: 1200, height: 1000)
        XCTAssertTrue(photo.isLikelyStorefront)
    }

    func testIsLikelyStorefront_maxBoundary() {
        // 2.0:1 ratio - maximum for storefront
        let photo = makePhoto(width: 2000, height: 1000)
        XCTAssertTrue(photo.isLikelyStorefront)
    }

    func testIsLikelyStorefront_false_tooWide() {
        // 2.5:1 ratio - too wide
        let photo = makePhoto(width: 2500, height: 1000)
        XCTAssertFalse(photo.isLikelyStorefront)
    }

    func testIsLikelyStorefront_false_portrait() {
        let photo = makePhoto(width: 900, height: 1600)
        XCTAssertFalse(photo.isLikelyStorefront)
    }

    func testIsLikelyStorefront_false_barelyLandscape() {
        // 1.1:1 - landscape but below minimum ratio
        let photo = makePhoto(width: 1100, height: 1000)
        XCTAssertFalse(photo.isLikelyStorefront)
    }

    // MARK: - storefrontScore

    func testStorefrontScore_idealPhoto() {
        // Landscape, ideal ratio (1.5:1), high res (>1.5MP)
        let photo = makePhoto(width: 1500, height: 1000)
        let score = photo.storefrontScore
        // landscape: 50, ideal ratio: 100, high res (1.5M pixels): 30
        XCTAssertEqual(score, 180.0)
    }

    func testStorefrontScore_goodPhoto() {
        // Landscape, acceptable ratio (1.9:1), medium res
        let photo = makePhoto(width: 950, height: 500)
        let score = photo.storefrontScore
        // landscape: 50, wider ratio (1.9 is in 1.2-2.0 range but also 1.3-1.8? Let me check: 950/500 = 1.9, not in 1.3-1.8, but in 1.2-2.0)
        // landscape: 50, acceptable ratio: 50, res = 475000 < 800000: 0
        XCTAssertEqual(score, 100.0)
    }

    func testStorefrontScore_portraitPhoto() {
        // Portrait, no landscape bonus, no ratio bonus
        let photo = makePhoto(width: 900, height: 1600)
        let score = photo.storefrontScore
        // No landscape: 0, ratio 0.5625 not in range: 0, 1440000 pixels medium: 15
        XCTAssertEqual(score, 15.0)
    }

    func testStorefrontScore_squarePhoto() {
        // Square - no landscape bonus
        let photo = makePhoto(width: 1000, height: 1000)
        let score = photo.storefrontScore
        // Not landscape: 0, ratio 1.0 not in range: 0, 1000000 pixels >= 800000: 15
        XCTAssertEqual(score, 15.0)
    }

    func testStorefrontScore_highResLandscapeNonIdealRatio() {
        // Very wide landscape, high res
        let photo = makePhoto(width: 3000, height: 1000)
        let score = photo.storefrontScore
        // landscape: 50, ratio 3.0 not in any range: 0, 3000000 pixels: 30
        XCTAssertEqual(score, 80.0)
    }

    func testStorefrontScore_lowResLandscapeIdealRatio() {
        // Small but ideal ratio
        let photo = makePhoto(width: 450, height: 300)
        let score = photo.storefrontScore
        // landscape: 50, ratio 1.5 in ideal range: 100, 135000 pixels: 0
        XCTAssertEqual(score, 150.0)
    }

    // MARK: - Codable

    func testCodable_roundTrip() throws {
        let photo = PlacePhoto(
            photoReference: "ref123",
            height: 900,
            width: 1600,
            htmlAttributions: ["<a>test</a>"]
        )
        let data = try JSONEncoder().encode(photo)
        let decoded = try JSONDecoder().decode(PlacePhoto.self, from: data)

        XCTAssertEqual(decoded.photoReference, photo.photoReference)
        XCTAssertEqual(decoded.height, photo.height)
        XCTAssertEqual(decoded.width, photo.width)
        XCTAssertEqual(decoded.htmlAttributions, photo.htmlAttributions)
    }

    func testCodable_decodesFromSnakeCaseKeys() throws {
        let json = """
        {
            "photo_reference": "ref456",
            "height": 800,
            "width": 1200,
            "html_attributions": []
        }
        """
        let data = json.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(PlacePhoto.self, from: data)

        XCTAssertEqual(decoded.photoReference, "ref456")
        XCTAssertEqual(decoded.height, 800)
        XCTAssertEqual(decoded.width, 1200)
    }
}
