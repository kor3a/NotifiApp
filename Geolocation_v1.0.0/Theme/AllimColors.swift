import SwiftUI
import UIKit

// Aisle palette for Allim.
// Quiet neutral chrome; category color is the only saturated thing on screen.
// Every token has a light and dark value. Never use a raw hex in a view.

// MARK: - Hex helpers

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255.0,
            green: CGFloat((hex >> 8) & 0xFF) / 255.0,
            blue: CGFloat(hex & 0xFF) / 255.0,
            alpha: 1.0
        )
    }

    static func dynamic(light: UInt32, dark: UInt32) -> UIColor {
        UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(hex: dark)
                : UIColor(hex: light)
        }
    }
}

extension Color {
    static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(UIColor.dynamic(light: light, dark: dark))
    }
}

// MARK: - Core tokens

enum AllimColor {

    // Surfaces
    static let canvas = Color.dynamic(light: 0xF6F7F8, dark: 0x121417)
    static let card = Color.dynamic(light: 0xFFFFFF, dark: 0x1B1F23)
    static let cardRaised = Color.dynamic(light: 0xFFFFFF, dark: 0x232830)
    static let border = Color.dynamic(light: 0xE3E6E9, dark: 0x2B3238)
    static let borderStrong = Color.dynamic(light: 0xCED4D9, dark: 0x3A434B)

    // Brand / actions
    static let primary = Color.dynamic(light: 0x0B7285, dark: 0x3EB8CC)
    static let primaryPressed = Color.dynamic(light: 0x075661, dark: 0x2E9AAC)
    static let primaryWash = Color.dynamic(light: 0xE0F1F4, dark: 0x12303A)
    static let onPrimary = Color.dynamic(light: 0xFFFFFF, dark: 0x0B1417)

    // Accent — reminders, "you're near <store>", unread badges. Use sparingly.
    static let accent = Color.dynamic(light: 0xD94F16, dark: 0xFF7A45)
    static let accentWash = Color.dynamic(light: 0xFCEAE1, dark: 0x3A1B0E)
    static let onAccent = Color.dynamic(light: 0xFFFFFF, dark: 0x1A0A04)
    // Text and glyphs on accentWash. `accent` itself only reaches about 3.5:1
    // against that tint — fine for a large glyph, short of the 4.5:1 the small
    // labels that sit on it need — so it darkens the way `textOnWash` does for
    // primaryWash.
    static let textOnAccentWash = Color.dynamic(light: 0x8A3510, dark: 0xFFC3A6)

    // Text
    static let textPrimary = Color.dynamic(light: 0x16191C, dark: 0xECEFF2)
    static let textSecondary = Color.dynamic(light: 0x5A6570, dark: 0x9BA6B0)
    static let textMuted = Color.dynamic(light: 0x8A939C, dark: 0x6F7B85)
    static let textOnWash = Color.dynamic(light: 0x075661, dark: 0xA8E4EF)

    // Status
    static let danger = Color.dynamic(light: 0xC4342B, dark: 0xFF6B60)
    static let dangerWash = Color.dynamic(light: 0xFBEAE9, dark: 0x3A1614)
    static let success = Color.dynamic(light: 0x1C6640, dark: 0x5FCB90)

    // Checked-off list items
    static let itemChecked = Color.dynamic(light: 0x8A939C, dark: 0x6F7B85)
    static let itemCheckedFill = Color.dynamic(light: 0xEEF0F2, dark: 0x1F242A)
}

// MARK: - Category tokens

// Three values per category:
//   dot   — the filled swatch / leading indicator
//   tint  — chip or section-header background
//   label — text on that tint (never white; see contrast note)

struct CategoryPalette {
    let dot: Color
    let tint: Color
    let label: Color
}

enum GroceryCategory: String, CaseIterable, Codable {
    case produce
    case dairy
    case meat
    case bakery
    case pantry
    case frozen
    case beverages
    case snacks
    case household
    case other

    var palette: CategoryPalette {
        switch self {
        case .produce:
            return CategoryPalette(
                dot: .dynamic(light: 0x3FA96B, dark: 0x5FC489),
                tint: .dynamic(light: 0xE7F4EC, dark: 0x14301F),
                label: .dynamic(light: 0x1C6640, dark: 0xA9E3C0)
            )
        case .dairy:
            return CategoryPalette(
                dot: .dynamic(light: 0x4C8DD6, dark: 0x6EA9E8),
                tint: .dynamic(light: 0xE7F0FA, dark: 0x14243A),
                label: .dynamic(light: 0x1F5490, dark: 0xB3D2F2)
            )
        case .meat:
            return CategoryPalette(
                dot: .dynamic(light: 0xC4574F, dark: 0xE0796F),
                tint: .dynamic(light: 0xF8EAE8, dark: 0x351715),
                label: .dynamic(light: 0x8A2F28, dark: 0xF0B8B1)
            )
        case .bakery:
            return CategoryPalette(
                dot: .dynamic(light: 0xB98A5A, dark: 0xD3A87A),
                tint: .dynamic(light: 0xF4EBE1, dark: 0x2E2318),
                label: .dynamic(light: 0x7A5432, dark: 0xE6CBAB)
            )
        case .pantry:
            return CategoryPalette(
                dot: .dynamic(light: 0xC08A22, dark: 0xDFAB44),
                tint: .dynamic(light: 0xF8EFDD, dark: 0x322512),
                label: .dynamic(light: 0x7A5410, dark: 0xEDCE8C)
            )
        case .frozen:
            return CategoryPalette(
                dot: .dynamic(light: 0x4FA8C4, dark: 0x74C4DC),
                tint: .dynamic(light: 0xE5F2F7, dark: 0x122A33),
                label: .dynamic(light: 0x1B5D74, dark: 0xADDCEB)
            )
        case .beverages:
            return CategoryPalette(
                dot: .dynamic(light: 0x0B7285, dark: 0x3EB8CC),
                tint: .dynamic(light: 0xE0F1F4, dark: 0x12303A),
                label: .dynamic(light: 0x075661, dark: 0xA8E4EF)
            )
        case .snacks:
            return CategoryPalette(
                dot: .dynamic(light: 0xC96A93, dark: 0xE08CAF),
                tint: .dynamic(light: 0xF8E9F0, dark: 0x331723),
                label: .dynamic(light: 0x8A3660, dark: 0xF0BBD2)
            )
        case .household:
            return CategoryPalette(
                dot: .dynamic(light: 0x8A7BC8, dark: 0xA99CE0),
                tint: .dynamic(light: 0xEEEBF8, dark: 0x221E38),
                label: .dynamic(light: 0x4E4090, dark: 0xCAC1F0)
            )
        case .other:
            return CategoryPalette(
                dot: .dynamic(light: 0x8A939C, dark: 0x9BA6B0),
                tint: .dynamic(light: 0xEEF0F2, dark: 0x22272C),
                label: .dynamic(light: 0x4A535B, dark: 0xC3CBD2)
            )
        }
    }
}

// MARK: - Reusable views

struct CategoryChip: View {
    let category: GroceryCategory
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(category.palette.label)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(category.palette.tint, in: Capsule())
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .medium))
            .foregroundStyle(AllimColor.onPrimary)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(
                configuration.isPressed ? AllimColor.primaryPressed : AllimColor.primary,
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
    }
}

// MARK: - Sample row

struct GroceryRow: View {
    let name: String
    let category: GroceryCategory
    let isChecked: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 20))
                .foregroundStyle(isChecked ? AllimColor.itemChecked : AllimColor.primary)

            Text(name)
                .font(.system(size: 16))
                .foregroundStyle(isChecked ? AllimColor.itemChecked : AllimColor.textPrimary)
                .strikethrough(isChecked, color: AllimColor.itemChecked)

            Spacer(minLength: 8)

            CategoryChip(category: category, title: category.rawValue.capitalized)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(isChecked ? AllimColor.itemCheckedFill : AllimColor.card)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AllimColor.border)
                .frame(height: 0.5)
        }
    }
}

#Preview {
    VStack(spacing: 0) {
        GroceryRow(name: "Roma tomatoes", category: .produce, isChecked: false)
        GroceryRow(name: "Whole milk", category: .dairy, isChecked: false)
        GroceryRow(name: "Sourdough", category: .bakery, isChecked: true)
        GroceryRow(name: "Paper towels", category: .household, isChecked: false)

        Button("Add item") {}
            .buttonStyle(PrimaryButtonStyle())
            .padding(16)
    }
    .background(AllimColor.canvas)
}
