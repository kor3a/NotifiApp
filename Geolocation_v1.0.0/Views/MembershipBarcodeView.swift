//
//  MembershipBarcodeView.swift
//  Geolocation_v1.0.0
//
//  Created on 7/27/26.
//

import SwiftUI
import UIKit

// MARK: - Top Sheet

/// A compact panel that slides down from the top of ReminderView showing the
/// membership / loyalty barcode saved for that store.
///
/// The card is either a photo of the physical card or a barcode the app renders
/// from a membership number the user typed in. Both live on-device only
/// (see `MembershipCardStore`).
struct MembershipBarcodeTopSheet: View {
    let storeName: String
    /// Dismisses the sheet. Owned by the presenting view so it can animate the
    /// panel out with the same transition it animated in.
    let onDismiss: () -> Void

    @ObservedObject private var cardStore = MembershipCardStore.shared

    @State private var showingEditor = false
    @State private var showingPhotoPicker = false
    @State private var pickedImage: UIImage?
    @State private var showDeleteConfirm = false
    @State private var dragOffset: CGFloat = 0
    /// Screen brightness before the sheet raised it, restored on dismiss.
    @State private var previousBrightness: CGFloat?

    private var card: MembershipCard? {
        cardStore.card(forStoreNamed: storeName)
    }

    /// The image to display: a saved photo of the card wins over a generated
    /// barcode, since it's a literal capture of what the scanner expects.
    private var displayImage: UIImage? {
        guard let card else { return nil }
        if let photo = cardStore.image(for: card) {
            return photo
        }
        guard card.hasNumber else { return nil }
        return BarcodeGenerator.image(for: card.trimmedNumber, symbology: card.symbology)
    }

    private var isShowingPhoto: Bool {
        guard let card else { return false }
        return cardStore.image(for: card) != nil
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            if let displayImage {
                barcodeCard(image: displayImage)
            } else if card?.hasNumber == true {
                // A number is saved but the chosen symbology can't encode it.
                unrenderableCardMessage
            } else {
                emptyState
            }

            grabber
        }
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.22), radius: 18, x: 0, y: 8)
        )
        .padding(.horizontal, 12)
        .offset(y: min(dragOffset, 0))
        .gesture(
            DragGesture()
                .onChanged { value in
                    dragOffset = min(0, value.translation.height)
                }
                .onEnded { value in
                    if value.translation.height < -40 {
                        dismiss()
                    } else {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            dragOffset = 0
                        }
                    }
                }
        )
        .onAppear { raiseBrightnessIfNeeded() }
        .onDisappear { restoreBrightness() }
        .onChange(of: displayImage == nil) { _, isEmpty in
            // A card added while the sheet is open should light up too.
            if isEmpty { restoreBrightness() } else { raiseBrightnessIfNeeded() }
        }
        .sheet(isPresented: $showingEditor) {
            MembershipCardEditorView(storeName: storeName)
        }
        .sheet(isPresented: $showingPhotoPicker) {
            ImagePicker(selectedImage: $pickedImage, allowsEditing: true) { image in
                cardStore.saveImage(image, forStoreNamed: storeName)
            }
        }
        .confirmationDialog(
            "Delete membership card?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete Card", role: .destructive) {
                cardStore.delete(forStoreNamed: storeName)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the saved number and photo for \(storeName) from this device.")
        }
    }

    // MARK: - Pieces

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "barcode.viewfinder")
                .font(.body)
                .foregroundStyle(Color.appAccent)

            VStack(alignment: .leading, spacing: 1) {
                Text(storeName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                Text("Membership")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            if card != nil {
                Menu {
                    Button {
                        showingEditor = true
                    } label: {
                        Label(card?.hasNumber == true ? "Edit number" : "Add number", systemImage: "number")
                    }

                    Button {
                        showingPhotoPicker = true
                    } label: {
                        Label(isShowingPhoto ? "Replace photo" : "Add photo", systemImage: "photo")
                    }

                    if isShowingPhoto {
                        Button(role: .destructive) {
                            cardStore.removeImage(forStoreNamed: storeName)
                        } label: {
                            Label("Remove photo", systemImage: "trash")
                        }
                    }

                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Label("Delete card", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
            }

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.body)
                    .foregroundStyle(.tertiary)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    private func barcodeCard(image: UIImage) -> some View {
        VStack(spacing: 8) {
            // Always on white: scanners read a dark-on-light code, and the panel
            // itself is translucent material that follows the system theme.
            Image(uiImage: image)
                .resizable()
                .interpolation(.none)
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .frame(height: (card?.symbology.isLinear ?? true) || isShowingPhoto ? 96 : 132)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.black.opacity(0.08), lineWidth: 1)
                )

            if let number = card?.trimmedNumber, !number.isEmpty {
                Text(number)
                    .font(.footnote.monospaced())
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .textSelection(.enabled)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
    }

    private var unrenderableCardMessage: some View {
        VStack(spacing: 8) {
            Text(card?.trimmedNumber ?? "")
                .font(.footnote.monospaced())
                .fontWeight(.medium)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text("This number can't be rendered as a \(card?.symbology.displayName ?? "barcode"). Try another format or add a photo of the card.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Edit") { showingEditor = true }
                .font(.caption.weight(.semibold))
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Text("No membership card saved for this store")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 10) {
                Button {
                    showingEditor = true
                } label: {
                    Label("Enter number", systemImage: "number")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(Color.appAccent.opacity(0.15)))
                        .foregroundStyle(Color.appAccent)
                }
                .buttonStyle(.plain)

                Button {
                    showingPhotoPicker = true
                } label: {
                    Label("Add photo", systemImage: "photo")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(Color.appAccent.opacity(0.15)))
                        .foregroundStyle(Color.appAccent)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
        .padding(.bottom, 14)
    }

    private var grabber: some View {
        Capsule()
            .fill(Color.secondary.opacity(0.35))
            .frame(width: 36, height: 4)
            .padding(.bottom, 8)
    }

    // MARK: - Behavior

    private func dismiss() {
        restoreBrightness()
        dragOffset = 0
        onDismiss()
    }

    /// Scanners read a bright screen far more reliably, so the sheet turns the
    /// display up while a code is visible and puts it back on the way out.
    private func raiseBrightnessIfNeeded() {
        guard displayImage != nil, previousBrightness == nil, let screen = activeScreen else { return }
        previousBrightness = screen.brightness
        screen.brightness = 1.0
    }

    private func restoreBrightness() {
        guard let previous = previousBrightness else { return }
        previousBrightness = nil
        activeScreen?.brightness = previous
    }

    private var activeScreen: UIScreen? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }?
            .screen
    }
}

// MARK: - Editor

/// Sheet for typing a membership number and picking the barcode format, with a
/// live preview of what the top sheet will render.
struct MembershipCardEditorView: View {
    let storeName: String

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var cardStore = MembershipCardStore.shared

    @State private var number: String = ""
    @State private var symbology: BarcodeSymbology = .code128
    @State private var didLoad = false

    private var trimmedNumber: String {
        number.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var previewImage: UIImage? {
        BarcodeGenerator.image(for: trimmedNumber, symbology: symbology)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("e.g. 1234567890123", text: $number)
                        .keyboardType(.asciiCapable)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled(true)
                        .font(.body.monospaced())
                } header: {
                    Text("Membership number")
                } footer: {
                    Text("The number printed under the barcode on your \(storeName) card.")
                }

                Section("Barcode format") {
                    Picker("Format", selection: $symbology) {
                        ForEach(BarcodeSymbology.allCases) { format in
                            Text(format.displayName).tag(format)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text(symbology.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Preview") {
                    if let previewImage {
                        Image(uiImage: previewImage)
                            .resizable()
                            .interpolation(.none)
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                            .frame(height: symbology.isLinear ? 90 : 130)
                            .padding(8)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Color.white)
                            )
                            .listRowBackground(Color.clear)
                    } else if trimmedNumber.isEmpty {
                        Text("Enter a number to see the barcode.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Label(
                            symbology.requiresASCII
                                ? "\(symbology.displayName) can only encode letters, digits and basic punctuation."
                                : "This value can't be encoded as a \(symbology.displayName).",
                            systemImage: "exclamationmark.triangle"
                        )
                        .font(.caption)
                        .foregroundStyle(.orange)
                    }
                }

                Section {
                    Text("Saved on this device only — it isn't shared with anyone this store is shared with.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if cardStore.card(forStoreNamed: storeName) != nil {
                    Section {
                        Button(role: .destructive) {
                            cardStore.delete(forStoreNamed: storeName)
                            dismiss()
                        } label: {
                            Label("Delete card", systemImage: "trash")
                        }
                    }
                }
            }
            .navigationTitle("Membership Card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        cardStore.saveNumber(number, symbology: symbology, forStoreNamed: storeName)
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
            .onAppear {
                guard !didLoad else { return }
                didLoad = true
                if let card = cardStore.card(forStoreNamed: storeName) {
                    number = card.number
                    symbology = card.symbology
                }
            }
        }
    }

    /// Saving an empty number is allowed only when it clears an existing one;
    /// otherwise the number has to be encodable in the selected format.
    private var canSave: Bool {
        if trimmedNumber.isEmpty {
            return cardStore.card(forStoreNamed: storeName)?.hasNumber == true
        }
        return previewImage != nil
    }
}

#Preview {
    MembershipCardEditorView(storeName: "Target")
}
