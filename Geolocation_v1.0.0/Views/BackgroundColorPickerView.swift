//
//  BackgroundColorPickerView.swift
//  Geolocation_v1.0.0
//
//  Lets subscribers pick the background color for a screen.
//

import SwiftUI

struct BackgroundColorPickerView: View {
    let surface: BackgroundSurface

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var preferences = BackgroundPreferences.shared
    @ObservedObject private var subscriptionManager = SubscriptionManager.shared
    @State private var showingPaywall = false

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 14), count: 4)

    /// Mirrors `SurfaceBackground`: a lapsed subscription falls back to the
    /// default look, so the picker always reflects what's actually on screen.
    private var selection: AppBackgroundColor {
        guard subscriptionManager.isSubscribed else { return .system }
        return preferences.backgroundColor(for: surface)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    preview

                    if !subscriptionManager.isSubscribed {
                        premiumBanner
                    }

                    swatchGrid
                }
                .padding(.vertical, 20)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("\(surface.displayName) Background")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Reset") {
                        select(.system)
                    }
                    .disabled(selection == .system)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showingPaywall) {
                SubscriptionPaywallView()
            }
        }
    }

    // MARK: - Preview

    /// A miniature of the real screen so the choice can be judged against the
    /// glass cards it will actually sit behind, not just as a flat swatch.
    private var preview: some View {
        VStack(spacing: 10) {
            ZStack {
                if selection == .system {
                    Color.backgroundGradient(for: colorScheme)
                } else {
                    selection.fill(for: colorScheme)
                }

                VStack(spacing: 10) {
                    ForEach(previewRows, id: \.title) { row in
                        previewCard(title: row.title, subtitle: row.subtitle)
                    }
                }
                .padding(16)
            }
            .frame(height: 170)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
            .animation(.easeInOut(duration: 0.2), value: selection)

            Text(selection.displayName)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 20)
    }

    private struct PreviewRow {
        let title: String
        let subtitle: String
    }

    /// Sample rows for the miniature, matching whatever the surface actually shows.
    private var previewRows: [PreviewRow] {
        switch surface {
        case .stores:
            return [PreviewRow(title: "Whole Foods", subtitle: "4 items"),
                    PreviewRow(title: "Trader Joe's", subtitle: "2 items")]
        case .reminders:
            return [PreviewRow(title: "Milk", subtitle: "Dairy"),
                    PreviewRow(title: "Avocados", subtitle: "Produce")]
        case .conversation:
            return [PreviewRow(title: "See you there!", subtitle: "9:41 AM"),
                    PreviewRow(title: "On my way", subtitle: "9:42 AM")]
        }
    }

    private func previewCard(title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.primary.opacity(0.12))
                .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.cardBorder(for: colorScheme), lineWidth: 1.5)
                )
        )
    }

    // MARK: - Premium Banner

    private var premiumBanner: some View {
        Button {
            showingPaywall = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.linearGradient(
                        colors: [.yellow, .orange],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Premium Feature")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                    Text("Subscribe to personalize your backgrounds")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 14).fill(.ultraThinMaterial))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
    }

    // MARK: - Swatches

    private var swatchGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("COLORS")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)

            LazyVGrid(columns: columns, spacing: 14) {
                systemSwatch

                ForEach(AppBackgroundColor.selectableColors) { color in
                    swatch(for: color)
                }
            }
        }
        .padding(.horizontal, 20)
    }

    private var systemSwatch: some View {
        swatchButton(for: .system) {
            Color.backgroundGradient(for: colorScheme)
        }
    }

    private func swatch(for color: AppBackgroundColor) -> some View {
        swatchButton(for: color) {
            color.fill(for: colorScheme)
        }
    }

    private func swatchButton<Fill: View>(
        for color: AppBackgroundColor,
        @ViewBuilder fill: () -> Fill
    ) -> some View {
        let isSelected = selection == color

        return Button {
            select(color)
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    fill()
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(
                                    isSelected ? Color.accentColor : Color.primary.opacity(0.12),
                                    lineWidth: isSelected ? 2.5 : 1
                                )
                        )

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20))
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, Color.accentColor)
                    }
                }
                .frame(height: 56)

                Text(color.displayName)
                    .font(.caption2)
                    .foregroundStyle(isSelected ? .primary : .secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Selection

    private func select(_ color: AppBackgroundColor) {
        // Non-subscribers can open the picker and see the palette — tapping a
        // color is what routes them to the paywall.
        guard subscriptionManager.isSubscribed else {
            showingPaywall = true
            return
        }
        withAnimation(.easeInOut(duration: 0.2)) {
            preferences.setBackgroundColor(color, for: surface)
        }
    }
}

#Preview {
    BackgroundColorPickerView(surface: .stores)
}
