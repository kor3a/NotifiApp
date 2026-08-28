//
//  BackgroundPickerView.swift
//  Geolocation_v1.0.0
//
//  Lets anyone set a screen's background color, and subscribers use a photo.
//

import SwiftUI
import PhotosUI
import UIKit

struct BackgroundPickerView: View {
    let surface: BackgroundSurface
    /// What this background belongs to — a store or chat name. Falls back to
    /// the surface's generic name when the caller has nothing better.
    var title: String?
    /// Every store the user has, so this background can be pushed out to all of
    /// their reminder lists at once. Passing the store being edited is fine —
    /// it's filtered out. Empty (a conversation, or a caller that doesn't know
    /// the store list) hides the Apply to All Stores row.
    var storeIds: [String] = []
    /// What the "Default" entry looks like on the screen being edited. Passed
    /// through so its swatch and the preview show what the user will actually
    /// get — Stores, Reminders and Conversations resolve Default to the organic
    /// canvas, not the app gradient. Nil keeps the gradient.
    var systemDefault: Color?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var preferences = BackgroundPreferences.shared
    @ObservedObject private var subscriptionManager = SubscriptionManager.shared
    @State private var showingPaywall = false
    @State private var photoItem: PhotosPickerItem?
    @State private var isLoadingPhoto = false
    @State private var photoError: String?
    @State private var showingApplyAllConfirmation = false
    @State private var applyAllError: String?
    /// Flips the row to a checkmark for a moment after a sweep, so a tap that
    /// changes nothing on this screen still visibly does something.
    @State private var didApplyToAllStores = false

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 14), count: 4)

    /// Colors are free, so this is simply whatever the user picked.
    private var selection: AppBackgroundColor {
        preferences.backgroundColor(for: surface)
    }

    /// Mirrors `SurfaceBackground`: a lapsed subscription falls back to the
    /// color, so the picker always reflects what's actually on screen.
    private var selectedPhoto: UIImage? {
        guard subscriptionManager.isSubscribed else { return nil }
        return preferences.backgroundImage(for: surface)
    }

    private var shade: Double {
        preferences.shadeLevel(for: surface)
    }

    private var isDefault: Bool {
        selection == .system && selectedPhoto == nil && shade == 0
    }

    /// The reminder lists a sweep would write to — every store except the one
    /// already being edited here.
    private var applyAllTargets: [BackgroundSurface] {
        storeIds
            .map { BackgroundSurface.reminders(storeId: $0) }
            .filter { $0.storageSuffix != surface.storageSuffix }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    preview

                    photoSection
                    swatchGrid

                    // A photo has its own Fade control, so the color shade
                    // slider would have nothing to act on.
                    if selectedPhoto == nil {
                        shadeSection
                    }

                    if !applyAllTargets.isEmpty {
                        applyAllSection
                    }
                }
                .padding(.vertical, 20)
            }
            .background(OrganicPalette.canvas(colorScheme).ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(OrganicPalette.canvas(colorScheme), for: .navigationBar)
            .tint(OrganicPalette.terracotta(colorScheme))
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Reset") {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            preferences.reset(surface)
                        }
                    }
                    .foregroundColor(OrganicPalette.terracotta(colorScheme))
                    .disabled(isDefault)
                }
                ToolbarItem(placement: .principal) {
                    Text("\(title ?? surface.displayName) Background")
                        .font(OrganicPalette.title(17))
                        .foregroundColor(OrganicPalette.ink(colorScheme))
                        .lineLimit(1)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(OrganicPalette.title(16))
                        .foregroundColor(OrganicPalette.terracotta(colorScheme))
                }
            }
            .sheet(isPresented: $showingPaywall) {
                SubscriptionPaywallView()
            }
            .organicAlert(
                "Couldn't Use That Photo",
                isPresented: Binding(
                    get: { photoError != nil },
                    set: { if !$0 { photoError = nil } }
                ),
                icon: "photo.badge.exclamationmark",
                tone: .destructive,
                message: photoError,
                actions: [.ok { photoError = nil }]
            )
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
                } else {
                    Rectangle()
                        .fill(selection.background(
                            for: colorScheme,
                            shade: shade,
                            systemDefault: systemDefault
                        ))
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
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(OrganicPalette.outline(colorScheme), lineWidth: 1)
            )
            .animation(.easeInOut(duration: 0.2), value: selection)

            Text(selectedPhoto != nil ? "Your Photo" : selection.displayName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(OrganicPalette.inkSoft(colorScheme))
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
            Circle()
                .fill(OrganicPalette.blush(colorScheme))
                .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(OrganicPalette.ink(colorScheme))
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(OrganicPalette.inkSoft(colorScheme))
            }

            Spacer()
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(OrganicPalette.surface(colorScheme))
                .shadow(color: OrganicPalette.shadow(colorScheme), radius: 6, x: 0, y: 2)
        )
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
                    cardRule

                    dimRow

                    cardRule

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
                                .font(.system(size: 15, weight: .semibold))
                            Spacer()
                        }
                        .foregroundColor(OrganicPalette.rust(colorScheme))
                        .padding(14)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .background(OrganicCardBackground(colorScheme: colorScheme, cornerRadius: 20))
        }
        .padding(.horizontal, 20)
    }

    private var photoRowLabel: some View {
        HStack(spacing: 14) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 18))
                .foregroundColor(OrganicPalette.terracotta(colorScheme))
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(selectedPhoto == nil ? "Choose Photo" : "Change Photo")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(OrganicPalette.ink(colorScheme))
                Text("Use one of your own photos as the background")
                    .font(.system(size: 12))
                    .foregroundColor(OrganicPalette.inkSoft(colorScheme))
            }

            Spacer()

            if isLoadingPhoto {
                ProgressView()
                    .tint(OrganicPalette.terracotta(colorScheme))
            } else if let photo = selectedPhoto {
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 36, height: 36)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            } else if !subscriptionManager.isSubscribed {
                // The one paid row on this screen — marked so it reads as
                // locked rather than broken when the paywall appears.
                Image(systemName: "crown.fill")
                    .font(.system(size: 12))
                    .foregroundColor(OrganicPalette.terracotta(colorScheme))
            } else {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(OrganicPalette.inkSoft(colorScheme).opacity(0.7))
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
                    .foregroundColor(OrganicPalette.inkSoft(colorScheme))
                    .frame(width: 24)

                Text("Fade")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(OrganicPalette.ink(colorScheme))

                Slider(
                    value: Binding(
                        get: { preferences.dimLevel(for: surface) },
                        set: { preferences.setDimLevel($0, for: surface) }
                    ),
                    in: 0...BackgroundPreferences.maxDimLevel
                )
            }

            Text("Fade the photo so your stores stay easy to read.")
                .font(.system(size: 12))
                .foregroundColor(OrganicPalette.inkSoft(colorScheme))
                .padding(.leading, 38)
        }
        .padding(14)
    }

    // MARK: - Swatches

    private var swatchGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("COLORS")

            LazyVGrid(columns: columns, spacing: 14) {
                swatch(for: .system)

                ForEach(AppBackgroundColor.selectableColors) { color in
                    swatch(for: color)
                }
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Shade

    /// The palette's light-mode variants are deliberately pale so text stays
    /// readable, which makes a name like Midnight land lighter than it sounds.
    /// This is the escape hatch: take the color you picked and set how deep it
    /// actually sits.
    private var shadeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionHeader("SHADE")

                if shade != 0 {
                    Button("Default") {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            preferences.setShadeLevel(0, for: surface)
                        }
                    }
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(OrganicPalette.terracotta(colorScheme))
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 12) {
                    Image(systemName: "sun.max.fill")
                        .font(.system(size: 15))
                        .foregroundColor(OrganicPalette.inkSoft(colorScheme))

                    Slider(
                        value: Binding(
                            get: { shade },
                            set: { preferences.setShadeLevel($0, for: surface) }
                        ),
                        in: -1...1
                    )
                    .accessibilityLabel("Background shade")

                    Image(systemName: "moon.fill")
                        .font(.system(size: 15))
                        .foregroundColor(OrganicPalette.inkSoft(colorScheme))
                }

                Text(shadeHint)
                    .font(.system(size: 12))
                    .foregroundColor(OrganicPalette.inkSoft(colorScheme))
            }
            .padding(14)
            .background(OrganicCardBackground(colorScheme: colorScheme, cornerRadius: 20))
        }
        .padding(.horizontal, 20)
    }

    /// The palette is tuned for readability, so pushing a color much darker in
    /// Light Mode is worth a word of warning — the miniature above shows it.
    private var shadeHint: String {
        let subject = selection == .system ? "the default background" : selection.displayName
        return "Drag right to deepen \(subject), left to lighten it. Watch the preview above — a very dark background in Light Mode can make text harder to read."
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .bold))
            .kerning(0.8)
            .foregroundColor(OrganicPalette.inkSoft(colorScheme))
            .padding(.horizontal, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// The hairline between rows inside a card. `Divider` draws the system's
    /// grey, which reads as a seam across the paper.
    private var cardRule: some View {
        Rectangle()
            .fill(OrganicPalette.outline(colorScheme).opacity(0.5))
            .frame(height: 1)
            .padding(.leading, 52)
    }

    /// Swatches carry the current shade, so dragging the slider previews the
    /// whole palette at that depth rather than only the chosen color.
    private func swatch(for color: AppBackgroundColor) -> some View {
        // A photo overrides any color, so no swatch reads as selected while one
        // is set — otherwise the checkmark would point at something invisible.
        let isSelected = selectedPhoto == nil && selection == color

        return Button {
            select(color)
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    Rectangle()
                        .fill(color.background(
                            for: colorScheme,
                            shade: shade,
                            systemDefault: systemDefault
                        ))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(
                                    isSelected
                                        ? OrganicPalette.terracotta(colorScheme)
                                        : OrganicPalette.outline(colorScheme),
                                    lineWidth: isSelected ? 2.5 : 1
                                )
                        )

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20))
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, OrganicPalette.terracotta(colorScheme))
                    }
                }
                .frame(height: 56)

                Text(color.displayName)
                    .font(.system(size: 11, weight: isSelected ? .bold : .regular))
                    .foregroundColor(
                        isSelected
                            ? OrganicPalette.ink(colorScheme)
                            : OrganicPalette.inkSoft(colorScheme)
                    )
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Apply to All Stores

    /// One background across every store list is the common case, and setting
    /// it store by store means reopening this screen once per store.
    private var applyAllSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("ALL STORES")

            Button {
                showingApplyAllConfirmation = true
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: didApplyToAllStores ? "checkmark.circle.fill" : "square.grid.2x2")
                        .font(.system(size: 18))
                        .foregroundColor(
                            didApplyToAllStores
                                ? OrganicPalette.sageInk(colorScheme)
                                : OrganicPalette.terracotta(colorScheme)
                        )
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(didApplyToAllStores ? "Applied to All Stores" : "Apply to All Stores")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(OrganicPalette.ink(colorScheme))
                        Text(applyAllSubtitle)
                            .font(.system(size: 12))
                            .foregroundColor(OrganicPalette.inkSoft(colorScheme))
                    }

                    Spacer()

                    if !didApplyToAllStores {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(OrganicPalette.inkSoft(colorScheme).opacity(0.7))
                    }
                }
                .padding(14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .background(OrganicCardBackground(colorScheme: colorScheme, cornerRadius: 20))
        }
        .padding(.horizontal, 20)
        // Carried on the row rather than the screen: the photo alert already
        // sits on the NavigationStack, and stacked presentations there swallow
        // one another.
        .organicAlert(
            "Apply to All Stores?",
            isPresented: $showingApplyAllConfirmation,
            icon: "square.on.square",
            message: "Every store's reminder list will use this background. Any background you set on a store on its own will be replaced.",
            actions: [
                .primary("Apply") { applyToAllStores() },
                .cancel()
            ]
        )
        .organicAlert(
            "Couldn't Apply Background",
            isPresented: Binding(
                get: { applyAllError != nil },
                set: { if !$0 { applyAllError = nil } }
            ),
            icon: "exclamationmark.triangle.fill",
            tone: .destructive,
            message: applyAllError,
            actions: [.ok { applyAllError = nil }]
        )
        // The row confirms the look that was swept out, so a new pick makes it
        // stale.
        .onChange(of: selection) { _, _ in didApplyToAllStores = false }
    }

    private var applyAllSubtitle: String {
        let count = applyAllTargets.count
        guard count > 1 else { return "Give your store's reminder list this background." }
        return "Give all \(count) of your store lists this background."
    }

    /// Copies what this screen currently shows onto every other store's list.
    ///
    /// Photos travel only for subscribers: without one, the photo has already
    /// fallen back to the color in the preview above, so the color is what the
    /// user is agreeing to send everywhere.
    private func applyToAllStores() {
        let targets = applyAllTargets
        guard !targets.isEmpty else { return }

        let applied = withAnimation(.easeInOut(duration: 0.25)) {
            preferences.applyBackground(
                from: surface,
                to: targets,
                includingPhoto: subscriptionManager.isSubscribed
            )
        }

        guard applied else {
            applyAllError = "Some of your store lists couldn't be updated. Please try again."
            return
        }

        withAnimation(.easeInOut(duration: 0.2)) { didApplyToAllStores = true }
        // Pinned to the main actor: the only thing it touches is view state.
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            withAnimation(.easeInOut(duration: 0.2)) { didApplyToAllStores = false }
        }
    }

    // MARK: - Selection

    /// Colors are free for everyone — only the photo row routes to the paywall.
    private func select(_ color: AppBackgroundColor) {
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
