//
//  BackgroundPickerView.swift
//  Geolocation_v1.0.0
//
//  Lets subscribers set a screen's background to a photo or a solid color.
//

import SwiftUI
import PhotosUI
import UIKit

struct BackgroundPickerView: View {
    let surface: BackgroundSurface

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var preferences = BackgroundPreferences.shared
    @ObservedObject private var subscriptionManager = SubscriptionManager.shared
    @State private var showingPaywall = false
    @State private var photoItem: PhotosPickerItem?
    @State private var isLoadingPhoto = false
    @State private var photoError: String?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 14), count: 4)

    /// Mirrors `SurfaceBackground`: a lapsed subscription falls back to the
    /// default look, so the picker always reflects what's actually on screen.
    private var selection: AppBackgroundColor {
        guard subscriptionManager.isSubscribed else { return .system }
        return preferences.backgroundColor(for: surface)
    }

    private var selectedPhoto: UIImage? {
        guard subscriptionManager.isSubscribed else { return nil }
        return preferences.backgroundImage(for: surface)
    }

    private var isDefault: Bool {
        selection == .system && selectedPhoto == nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    preview

                    if !subscriptionManager.isSubscribed {
                        premiumBanner
                    }

                    photoSection
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
                        withAnimation(.easeInOut(duration: 0.2)) {
                            preferences.reset(surface)
                        }
                    }
                    .disabled(isDefault)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showingPaywall) {
                SubscriptionPaywallView()
            }
            .alert("Couldn't Use That Photo", isPresented: Binding(
                get: { photoError != nil },
                set: { if !$0 { photoError = nil } }
            )) {
                Button("OK", role: .cancel) { photoError = nil }
            } message: {
                Text(photoError ?? "")
            }
            .onChange(of: photoItem) { _, item in
                guard let item else { return }
                loadPhoto(item)
            }
        }
    }

    // MARK: - Preview

    /// A miniature of the real screen so the choice can be judged against the
    /// glass cards it will actually sit behind, not just as a flat swatch.
    private var preview: some View {
        VStack(spacing: 10) {
            ZStack {
                if let photo = selectedPhoto {
                    BackgroundPhoto(
                        image: photo,
                        dimLevel: preferences.dimLevel(for: surface),
                        colorScheme: colorScheme
                    )
                } else if selection == .system {
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

                if isLoadingPhoto {
                    Color.black.opacity(0.25)
                    ProgressView()
                        .tint(.white)
                }
            }
            .frame(height: 170)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
            .animation(.easeInOut(duration: 0.2), value: selection)

            Text(selectedPhoto != nil ? "Your Photo" : selection.displayName)
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

    // MARK: - Photo

    private var photoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("PHOTO")

            VStack(spacing: 0) {
                if subscriptionManager.isSubscribed {
                    // PhotosPicker runs out of process, so choosing a photo
                    // never asks for photo library permission.
                    PhotosPicker(selection: $photoItem, matching: .images, photoLibrary: .shared()) {
                        photoRowLabel
                    }
                    .buttonStyle(.plain)
                    .disabled(isLoadingPhoto)
                } else {
                    Button { showingPaywall = true } label: { photoRowLabel }
                        .buttonStyle(.plain)
                }

                if selectedPhoto != nil {
                    Divider().padding(.leading, 52)

                    dimRow

                    Divider().padding(.leading, 52)

                    Button(role: .destructive) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            preferences.removeBackgroundImage(for: surface)
                        }
                        photoItem = nil
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "trash")
                                .font(.system(size: 18))
                                .frame(width: 24)
                            Text("Remove Photo")
                                .font(.subheadline)
                            Spacer()
                        }
                        .foregroundStyle(.red)
                        .padding(14)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .background(RoundedRectangle(cornerRadius: 14).fill(.ultraThinMaterial))
        }
        .padding(.horizontal, 20)
    }

    private var photoRowLabel: some View {
        HStack(spacing: 14) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 18))
                .foregroundStyle(Color.accentColor)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(selectedPhoto == nil ? "Choose Photo" : "Change Photo")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                Text("Use one of your own photos as the background")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if isLoadingPhoto {
                ProgressView()
            } else if let photo = selectedPhoto {
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 36, height: 36)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .contentShape(Rectangle())
    }

    /// Photos vary wildly in brightness and the app's cards are translucent, so
    /// the user tunes the scrim until their own photo reads well.
    private var dimRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 14) {
                Image(systemName: colorScheme == .dark ? "moon.fill" : "sun.max.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.secondary)
                    .frame(width: 24)

                Text("Fade")
                    .font(.subheadline)
                    .foregroundStyle(.primary)

                Slider(
                    value: Binding(
                        get: { preferences.dimLevel(for: surface) },
                        set: { preferences.setDimLevel($0, for: surface) }
                    ),
                    in: 0...BackgroundPreferences.maxDimLevel
                )
            }

            Text("Fade the photo so your stores stay easy to read.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.leading, 38)
        }
        .padding(14)
    }

    // MARK: - Swatches

    private var swatchGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("COLORS")

            LazyVGrid(columns: columns, spacing: 14) {
                systemSwatch

                ForEach(AppBackgroundColor.selectableColors) { color in
                    swatch(for: color)
                }
            }
        }
        .padding(.horizontal, 20)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
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
        // A photo overrides any color, so no swatch reads as selected while one
        // is set — otherwise the checkmark would point at something invisible.
        let isSelected = selectedPhoto == nil && selection == color

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
        photoItem = nil
    }

    private func loadPhoto(_ item: PhotosPickerItem) {
        isLoadingPhoto = true
        // Pinned to the main actor: everything this touches afterwards is view
        // state or the preferences store, both of which publish to SwiftUI.
        Task { @MainActor in
            defer { isLoadingPhoto = false }
            do {
                guard let data = try await item.loadTransferable(type: Data.self) else {
                    photoError = "That photo couldn't be loaded. Please try a different one."
                    return
                }
                // Decoding and downscaling a full-resolution photo is slow
                // enough to stutter the picker, so it happens off the main
                // actor. Only the finished JPEG comes back, and storing it —
                // which publishes to SwiftUI — stays on the main actor.
                let prepared = await Task.detached(priority: .userInitiated) {
                    BackgroundPreferences.preparedImageData(from: data)
                }.value

                guard let prepared else {
                    photoError = "That photo couldn't be read. Please try a different one."
                    return
                }

                let stored = withAnimation(.easeInOut(duration: 0.25)) {
                    preferences.storeImageData(prepared, for: surface)
                }
                if !stored {
                    photoError = "That photo couldn't be saved. Please try a different one."
                }
            } catch {
                photoError = "That photo couldn't be loaded. Please try a different one."
            }
        }
    }
}

#Preview {
    BackgroundPickerView(surface: .stores)
}
