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

                        LazyVGrid(columns: columns, spacing: 18) {
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
        .alert(
            "Couldn't change the icon",
            isPresented: Binding(
                get: { iconManager.errorMessage != nil },
                set: { if !$0 { iconManager.errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) { iconManager.errorMessage = nil }
        } message: {
            Text(iconManager.errorMessage ?? "")
        }
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
                .frame(width: 96, height: 96)
                // The Home Screen's own corner curve, near enough.
                .clipShape(RoundedRectangle(cornerRadius: 21, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 21, style: .continuous)
                        .strokeBorder(
                            isSelected
                                ? OrganicPalette.terracotta(colorScheme)
                                : OrganicPalette.inkSoft(colorScheme).opacity(0.15),
                            lineWidth: isSelected ? 3 : 1
                        )
                )
                .overlay(alignment: .bottomTrailing) {
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 26, height: 26)
                            .background(Circle().fill(OrganicPalette.terracotta(colorScheme)))
                            .overlay(
                                Circle().strokeBorder(OrganicPalette.surface(colorScheme), lineWidth: 2)
                            )
                            .offset(x: 8, y: 8)
                    }
                }
                .padding(.vertical, 24)
                .frame(maxWidth: .infinity)
                .background(OrganicCardBackground(colorScheme: colorScheme, cornerRadius: 24))
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
