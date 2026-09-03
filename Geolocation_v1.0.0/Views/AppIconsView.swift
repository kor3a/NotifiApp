//
//  AppIconsView.swift
//  Geolocation_v1.0.0
//
//  Picks the icon Allim wears on the Home Screen.
//

import SwiftUI
import UIKit

struct AppIconsView: View {

    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var iconManager = AppIconManager.shared

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 16), count: 2)

    var body: some View {
        ZStack {
            OrganicPalette.canvas(colorScheme)
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if !iconManager.supportsAlternateIcons {
                        unsupportedNotice
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        OrganicSectionLabel(title: "Choose an icon")

                        LazyVGrid(columns: columns, spacing: 24) {
                            ForEach(AppIconManager.options) { option in
                                iconCell(option)
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 32)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(OrganicPalette.canvas(colorScheme), for: .navigationBar)
        .tint(OrganicPalette.terracotta(colorScheme))
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("App Icons")
                    .font(OrganicPalette.title(17))
                    .foregroundColor(OrganicPalette.ink(colorScheme))
            }
        }
        .organicAlert(
            "Couldn't change the icon",
            isPresented: Binding(
                get: { iconManager.errorMessage != nil },
                set: { if !$0 { iconManager.errorMessage = nil } }
            ),
            icon: "exclamationmark.triangle.fill",
            tone: .destructive,
            message: iconManager.errorMessage,
            actions: [.ok { iconManager.errorMessage = nil }]
        )
    }

    // MARK: - Pieces

    private var unsupportedNotice: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(OrganicPalette.rust(colorScheme))

            Text("This device doesn't allow changing the app icon.")
                .font(.system(size: 14))
                .foregroundColor(OrganicPalette.inkSoft(colorScheme))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(OrganicCardBackground(colorScheme: colorScheme))
    }

    private func iconCell(_ option: AppIconOption) -> some View {
        let isSelected = iconManager.isSelected(option)

        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                iconManager.select(option)
            }
        } label: {
            preview(for: option)
                .frame(width: 112, height: 112)
                // The Home Screen's own corner curve, near enough.
                .clipShape(RoundedRectangle(cornerRadius: 25, style: .continuous))
                // Nothing marks an unselected icon: the artwork sits on the
                // canvas as it would on the Home Screen.
                .overlay {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 25, style: .continuous)
                            .strokeBorder(OrganicPalette.terracotta(colorScheme), lineWidth: 3)
                    }
                }
                .overlay(alignment: .bottomTrailing) {
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(OrganicPalette.onTerracotta(colorScheme))
                            .frame(width: 26, height: 26)
                            .background(Circle().fill(OrganicPalette.terracotta(colorScheme)))
                            // Reads against the canvas now that the cards are
                            // gone.
                            .overlay(
                                Circle().strokeBorder(OrganicPalette.canvas(colorScheme), lineWidth: 2)
                            )
                            .offset(x: 8, y: 8)
                    }
                }
                // No card behind the icon — only enough room around it to
                // keep the tap target comfortable.
                .padding(10)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!iconManager.supportsAlternateIcons)
        .opacity(iconManager.supportsAlternateIcons ? 1 : 0.5)
        .accessibilityLabel("\(option.displayName) icon")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    /// The icon assets themselves can't be loaded by name, so each option keeps
    /// a plain imageset of the same artwork. A missing one falls back to a
    /// glyph rather than an empty hole in the grid.
    @ViewBuilder
    private func preview(for option: AppIconOption) -> some View {
        if let image = UIImage(named: option.previewAssetName)
            ?? option.alternateName.flatMap({ UIImage(named: $0) }) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                OrganicPalette.blush(colorScheme)
                Image(systemName: "app.dashed")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(OrganicPalette.terracotta(colorScheme))
            }
        }
    }
}

#Preview {
    NavigationStack {
        AppIconsView()
    }
}
