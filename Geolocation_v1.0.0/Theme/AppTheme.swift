//
//  AppTheme.swift
//  Geolocation_v1.0.0
//
//  Created on 11/13/24.
//

import SwiftUI

// MARK: - App Theme
extension Color {
    // MARK: - Text Colors
    static let primaryText = Color.primary
    static let secondaryText = Color.secondary

    // MARK: - Accent Colors
    static let appAccent = Color.blue
    static let appSuccess = Color.green
    static let appError = Color.red
    static let appWarning = Color.orange

    // MARK: - Gradients
    static func backgroundGradient(for colorScheme: ColorScheme) -> LinearGradient {
        if colorScheme == .dark {
            return LinearGradient(
                colors: [
                    Color(red: 0.1, green: 0.1, blue: 0.15),
                    Color(red: 0.15, green: 0.15, blue: 0.2)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        } else {
            return LinearGradient(
                colors: [
                    Color(red: 0.95, green: 0.96, blue: 0.98),
                    Color(red: 0.88, green: 0.92, blue: 0.96)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    static let iconGradient = LinearGradient(
        colors: [.blue, .purple],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: - Border Colors
    static func cardBorder(for colorScheme: ColorScheme) -> LinearGradient {
        if colorScheme == .dark {
            return LinearGradient(
                colors: [
                    Color.white.opacity(0.2),
                    Color.white.opacity(0.05)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            return LinearGradient(
                colors: [
                    Color.white.opacity(0.6),
                    Color.white.opacity(0.2)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

// MARK: - View Modifiers
struct CardStyle: ViewModifier {
    @Environment(\.colorScheme) var colorScheme

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                Color.cardBorder(for: colorScheme),
                                lineWidth: 1.5
                            )
                    )
                    .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.1), radius: 8, x: 0, y: 4)
                    .shadow(color: Color.white.opacity(colorScheme == .dark ? 0.05 : 0.5), radius: 2, x: 0, y: -2)
                    .padding(.vertical, 4)
            )
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    var color: Color = .blue

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(color)
            )
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    var color: Color = .red

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(color)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(color.opacity(0.1))
            )
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
    }
}

extension View {
    func cardStyle() -> some View {
        modifier(CardStyle())
    }
}
