//
//  RetailBarcode.swift
//  Geolocation_v1.0.0
//
//  Created on 7/27/26.
//

import UIKit

/// Encoder and renderer for the EAN-13 barcode family (EAN-13 and UPC-A).
///
/// Core Image can't generate these — it only ships Code 128, QR, PDF417 and
/// Aztec — but they're what retail loyalty cards actually carry. A scanner at
/// the register decodes a *symbology*, not just digits: the same number encoded
/// as Code 128 produces a different bar pattern and a POS expecting a UPC-A
/// member number will not read it. So the pattern is built here from the spec.
///
/// The output includes the classic print layout — extended guard bars and the
/// human-readable digits sitting in the gaps they create — because that's what
/// the physical card looks like.
enum RetailBarcode {

    /// The two members of the EAN-13 family this renders. UPC-A is EAN-13 with
    /// an implicit leading zero; only the printed digit layout differs.
    enum Kind {
        case upcA   // 12 digits: first and last printed outside the bars
        case ean13  // 13 digits: first printed outside the bars

        var digitCount: Int {
            switch self {
            case .upcA: return 12
            case .ean13: return 13
            }
        }
    }

    // MARK: - Public API

    /// Digits of `value` with separators (spaces, dashes) removed, or `nil` if
    /// it contains anything else.
    static func digits(in value: String) -> [Int]? {
        var result: [Int] = []
        for character in value {
            if let digit = character.wholeNumberValue, character.isNumber {
                result.append(digit)
            } else if character.isWhitespace || character == "-" {
                continue
            } else {
                return nil
            }
        }
        return result.isEmpty ? nil : result
    }

    /// Whether `value` is a well-formed number for `kind`, check digit included.
    /// A barcode with a wrong check digit is refused by the scanner, so an
    /// invalid number is never rendered.
    static func isValid(_ value: String, kind: Kind) -> Bool {
        guard let digits = digits(in: value), digits.count == kind.digitCount else { return false }
        return hasValidCheckDigit(digits)
    }

    /// The family member `value` belongs to, if any. Used to pick the format
    /// automatically from what the user typed.
    static func detectedKind(for value: String) -> Kind? {
        guard let digits = digits(in: value), hasValidCheckDigit(digits) else { return nil }
        switch digits.count {
        case 12: return .upcA
        case 13: return .ean13
        default: return nil
        }
    }

    /// The check digit for a number that's missing one (11 digits for UPC-A,
    /// 12 for EAN-13), so a partially typed number can be completed.
    static func checkDigit(forPartial value: String) -> Int? {
        guard let digits = digits(in: value), digits.count == 11 || digits.count == 12 else {
            return nil
        }
        return computedCheckDigit(forLeading: digits)
    }

    /// Renders the barcode. `targetWidth` is the pixel width to aim for; the
    /// module size is rounded to a whole number of pixels so every bar lands on
    /// exact pixel boundaries and none of them get lost to rounding.
    static func image(for value: String, kind: Kind, targetWidth: CGFloat = 1200) -> UIImage? {
        guard let digits = digits(in: value),
              digits.count == kind.digitCount,
              hasValidCheckDigit(digits) else {
            return nil
        }

        // UPC-A is EAN-13 with a leading zero, which makes its left-hand parity
        // pattern all-odd — exactly the UPC-A encoding.
        let ean13Digits = kind == .upcA ? [0] + digits : digits
        guard let modules = modulePattern(for: ean13Digits) else { return nil }

        let layout = Layout(kind: kind)
        let scale = max(1, (targetWidth / layout.totalModules).rounded())
        return draw(modules: modules, displayDigits: digits, layout: layout, scale: scale)
    }

    // MARK: - Encoding tables

    /// Left-hand odd parity ("L") patterns, digits 0-9.
    private static let leftOdd: [[Bool]] = [
        "0001101", "0011001", "0010011", "0111101", "0100011",
        "0110001", "0101111", "0111011", "0110111", "0001011"
    ].map { $0.map { $0 == "1" } }

    /// Left-hand even parity ("G") patterns, digits 0-9.
    private static let leftEven: [[Bool]] = [
        "0100111", "0110011", "0011011", "0100001", "0011101",
        "0111001", "0000101", "0010001", "0001001", "0010111"
    ].map { $0.map { $0 == "1" } }

    /// Right-hand ("R") patterns, digits 0-9.
    private static let rightHand: [[Bool]] = [
        "1110010", "1100110", "1101100", "1000010", "1011100",
        "1001110", "1010000", "1000100", "1001000", "1110100"
    ].map { $0.map { $0 == "1" } }

    /// Which of the six left-hand digits use even parity, keyed by the first
    /// digit. This is how EAN-13 encodes a 13th digit into 12 digits of bars.
    private static let parityByFirstDigit: [[Bool]] = [
        "000000", "001011", "001101", "001110", "010011",
        "011001", "011100", "010101", "010110", "011010"
    ].map { $0.map { $0 == "1" } }

    private static let startGuard: [Bool] = [true, false, true]
    private static let centerGuard: [Bool] = [false, true, false, true, false]
    private static let endGuard: [Bool] = [true, false, true]

    /// The 95 modules of an EAN-13 symbol: start guard, six left digits,
    /// center guard, six right digits, end guard.
    private static func modulePattern(for digits: [Int]) -> [Bool]? {
        guard digits.count == 13, digits.allSatisfy({ (0...9).contains($0) }) else { return nil }

        let parity = parityByFirstDigit[digits[0]]
        var modules = startGuard

        for (offset, digit) in digits[1...6].enumerated() {
            modules += parity[offset] ? leftEven[digit] : leftOdd[digit]
        }
        modules += centerGuard
        for digit in digits[7...12] {
            modules += rightHand[digit]
        }
        modules += endGuard

        return modules.count == 95 ? modules : nil
    }

    // MARK: - Check digit

    /// EAN-13 check digit rule, applied to the leading digits (all but the
    /// check digit itself). Weights alternate 1,3 from the left of the
    /// zero-padded 13-digit form, which is why UPC-A works through it too.
    private static func computedCheckDigit(forLeading leading: [Int]) -> Int {
        // Pad to 12 leading digits so UPC-A's 11 line up with EAN-13's weights.
        let padded = Array(repeating: 0, count: max(0, 12 - leading.count)) + leading
        let sum = padded.enumerated().reduce(0) { total, pair in
            total + pair.element * (pair.offset.isMultiple(of: 2) ? 1 : 3)
        }
        return (10 - (sum % 10)) % 10
    }

    private static func hasValidCheckDigit(_ digits: [Int]) -> Bool {
        guard digits.count == 12 || digits.count == 13, let check = digits.last else { return false }
        return computedCheckDigit(forLeading: Array(digits.dropLast())) == check
    }

    // MARK: - Layout

    /// Geometry in module units (one module = one narrow bar width).
    private struct Layout {
        let kind: Kind
        /// Quiet zones. The spec's minimums — a scanner needs the blank margin
        /// to find the symbol's edges.
        let quietLeft: CGFloat
        let quietRight: CGFloat
        let barHeight: CGFloat = 30
        /// How far the guard bars drop past the data bars, forming the gaps the
        /// human-readable digits sit in.
        let guardDescent: CGFloat = 6
        let textBandHeight: CGFloat = 12
        let fontSize: CGFloat = 9

        init(kind: Kind) {
            self.kind = kind
            switch kind {
            case .upcA:
                quietLeft = 9
                quietRight = 9
            case .ean13:
                quietLeft = 11
                quietRight = 7
            }
        }

        var totalModules: CGFloat { quietLeft + 95 + quietRight }
        var totalHeight: CGFloat { barHeight + textBandHeight }

        /// Module indices (within the 95) whose bars extend below the rest.
        var guardModules: Set<Int> {
            Set([0, 1, 2] + [45, 46, 47, 48, 49] + [92, 93, 94])
        }

        /// Where each run of human-readable digits sits, as (start, width) in
        /// absolute module units from the left edge of the image.
        func textRuns(for digits: [Int]) -> [(text: String, start: CGFloat, width: CGFloat)] {
            let text = digits.map(String.init)
            let leftDataStart = quietLeft + 3
            let rightDataStart = quietLeft + 50

            switch kind {
            case .upcA:
                // First and last digits print outside the bars; the ten in
                // between split five under each half.
                return [
                    (text[0], 0, quietLeft),
                    (text[1...5].joined(), leftDataStart, 42),
                    (text[6...10].joined(), rightDataStart, 42),
                    (text[11], quietLeft + 95, quietRight)
                ]
            case .ean13:
                // Only the first digit prints outside; six under each half.
                return [
                    (text[0], 0, quietLeft),
                    (text[1...6].joined(), leftDataStart, 42),
                    (text[7...12].joined(), rightDataStart, 42)
                ]
            }
        }
    }

    // MARK: - Drawing

    private static func draw(
        modules: [Bool],
        displayDigits: [Int],
        layout: Layout,
        scale: CGFloat
    ) -> UIImage {
        let size = CGSize(width: layout.totalModules * scale, height: layout.totalHeight * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true

        let guardModules = layout.guardModules

        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            let cgContext = context.cgContext
            cgContext.setFillColor(UIColor.white.cgColor)
            cgContext.fill(CGRect(origin: .zero, size: size))

            cgContext.setFillColor(UIColor.black.cgColor)
            for (index, isBar) in modules.enumerated() where isBar {
                let height = guardModules.contains(index)
                    ? layout.barHeight + layout.guardDescent
                    : layout.barHeight
                cgContext.fill(CGRect(
                    x: (layout.quietLeft + CGFloat(index)) * scale,
                    y: 0,
                    width: scale,
                    height: height * scale
                ))
            }

            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.monospacedDigitSystemFont(ofSize: layout.fontSize * scale, weight: .regular),
                .foregroundColor: UIColor.black
            ]

            for run in layout.textRuns(for: displayDigits) {
                let string = run.text as NSString
                let textSize = string.size(withAttributes: attributes)
                let boxWidth = run.width * scale
                let bandTop = layout.barHeight * scale
                let bandHeight = layout.textBandHeight * scale
                string.draw(
                    at: CGPoint(
                        x: run.start * scale + (boxWidth - textSize.width) / 2,
                        y: bandTop + (bandHeight - textSize.height) / 2
                    ),
                    withAttributes: attributes
                )
            }
        }
    }
}
