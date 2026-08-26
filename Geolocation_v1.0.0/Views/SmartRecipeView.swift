//
//  SmartRecipeView.swift
//  Geolocation_v1.0.0
//
//  Created by Claude on 2/20/26.
//

import SwiftUI

// MARK: - Recipe Palette

/// The recipe screens run on their own warm, kitchen-toned accent rather than
/// the app's blue. They sit on a culinary backdrop image, and the cool system
/// blue reads as foreign against it.
enum RecipePalette {
    static let apricot = Color(red: 1.00, green: 0.60, blue: 0.24)
    static let paprika = Color(red: 0.90, green: 0.32, blue: 0.23)
    static let basil = Color(red: 0.33, green: 0.60, blue: 0.36)

    static let warmGradient = LinearGradient(
        colors: [apricot, paprika],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Wash laid over the backdrop art so message text keeps its contrast.
    static func scrim(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color.black.opacity(0.28) : Color.white.opacity(0.30)
    }

    /// Tint over the `.ultraThinMaterial` surfaces — bubbles, chips, input bar.
    /// Material takes on whatever sits behind it, so without this the artwork
    /// bleeds through and bubbles lose their edges.
    static func surfaceTint(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color.white.opacity(0.06) : Color.white.opacity(0.55)
    }

    static func surfaceBorder(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color.white.opacity(0.12) : Color.white.opacity(0.85)
    }

    static func hairline(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color.white.opacity(0.10) : Color.black.opacity(0.06)
    }

    static func shadow(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color.black.opacity(0.45)
            : Color(red: 0.45, green: 0.26, blue: 0.12).opacity(0.16)
    }
}

// MARK: - Backdrop

/// Full-bleed culinary artwork behind the whole screen. The asset carries its
/// own light and dark variants; the scrim on top keeps text legible over it.
struct RecipeBackdrop: View {
    let colorScheme: ColorScheme
    /// Extra wash laid over the standard scrim. Screens that put plain text
    /// straight onto the artwork — with no card behind it — dial this up so the
    /// busier parts of the photo don't fight the type.
    var extraScrimOpacity: Double = 0

    var body: some View {
        GeometryReader { geometry in
            Image("RecipeBackground")
                .resizable()
                .scaledToFill()
                .frame(width: geometry.size.width, height: geometry.size.height)
                .clipped()
                .overlay(RecipePalette.scrim(for: colorScheme))
                .overlay((colorScheme == .dark ? Color.black : Color.white).opacity(extraScrimOpacity))
        }
        .ignoresSafeArea()
    }
}

/// Glass surface shared by assistant bubbles, suggestion chips and banners.
private func recipeSurface(for colorScheme: ColorScheme, cornerRadius: CGFloat = 20) -> some View {
    let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    return shape
        .fill(.ultraThinMaterial)
        .overlay(shape.fill(RecipePalette.surfaceTint(for: colorScheme)))
        .overlay(shape.stroke(RecipePalette.surfaceBorder(for: colorScheme), lineWidth: 1))
        .shadow(color: RecipePalette.shadow(for: colorScheme), radius: 8, x: 0, y: 3)
}

/// The small fork-and-knife mark that sits beside every assistant message.
private struct RecipeAssistantAvatar: View {
    var body: some View {
        Image(systemName: "fork.knife")
            .font(.system(size: 12, weight: .bold))
            .foregroundColor(.white)
            .frame(width: 26, height: 26)
            .background(Circle().fill(RecipePalette.warmGradient))
            .padding(.top, 2)
    }
}

struct SmartRecipeView: View {
    @ObservedObject var viewModel: SmartRecipeViewModel
    @ObservedObject var storesViewModel: StoresViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    @FocusState private var isInputFocused: Bool
    @State private var messageIdForStorePicker: UUID?

    var body: some View {
        NavigationStack {
            ZStack {
                RecipeBackdrop(colorScheme: colorScheme)

                VStack(spacing: 0) {
                    conversation
                    statusBanners
                    inputBar
                }
            }
            .tint(RecipePalette.paprika)
            .navigationTitle("Smart Recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !viewModel.messages.isEmpty {
                        Button {
                            viewModel.startNewChat()
                        } label: {
                            Image(systemName: "square.and.pencil")
                        }
                    }
                }
            }
            .sheet(item: $messageIdForStorePicker) { messageId in
                StorePickerView(
                    userStoreItems: storesViewModel.userStoreItems,
                    colorScheme: colorScheme
                ) { selectedStore in
                    messageIdForStorePicker = nil
                    viewModel.addIngredientsToStore(messageId: messageId, userStoreItem: selectedStore)
                }
            }
        }
    }

    // MARK: - Conversation

    private var conversation: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 14) {
                    // Welcome message
                    if viewModel.messages.isEmpty {
                        welcomeView
                    }

                    ForEach(viewModel.messages) { message in
                        VStack(alignment: .leading, spacing: 10) {
                            MessageBubbleView(message: message, colorScheme: colorScheme)

                            // Show "Add Ingredients to Store" button for recipe messages with ingredients
                            if message.role == .assistant, let ingredients = message.ingredients, !ingredients.isEmpty {
                                addIngredientsButton(for: message)
                            }
                        }
                        .id(message.id)
                    }

                    if viewModel.isLoading {
                        HStack(alignment: .top, spacing: 8) {
                            RecipeAssistantAvatar()

                            TypingIndicatorView()
                                .padding(.horizontal, 18)
                                .padding(.vertical, 14)
                                .background { recipeSurface(for: colorScheme) }

                            Spacer(minLength: 40)
                        }
                        .padding(.horizontal)
                        .id("loading")
                    }
                }
                .padding(.vertical, 14)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: viewModel.messages.count) { _, _ in
                withAnimation {
                    if let lastMessage = viewModel.messages.last {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    } else if viewModel.isLoading {
                        proxy.scrollTo("loading", anchor: .bottom)
                    }
                }
            }
            .onChange(of: viewModel.isLoading) { _, isLoading in
                if isLoading {
                    withAnimation {
                        proxy.scrollTo("loading", anchor: .bottom)
                    }
                }
            }
        }
    }

    // MARK: - Status Banners

    private var hasStatusBanner: Bool {
        viewModel.errorMessage != nil
            || (viewModel.savedIngredientsCount != nil && viewModel.savedToStoreName != nil)
            || viewModel.savedRecipeName != nil
    }

    @ViewBuilder
    private var statusBanners: some View {
        if hasStatusBanner {
            VStack(spacing: 8) {
                // Error message
                if let error = viewModel.errorMessage {
                    statusBanner(
                        icon: "exclamationmark.triangle.fill",
                        tint: .orange,
                        text: error
                    ) {
                        viewModel.errorMessage = nil
                    }
                }

                // Success confirmation - ingredients added to store
                if let count = viewModel.savedIngredientsCount, let storeName = viewModel.savedToStoreName {
                    statusBanner(
                        icon: "checkmark.circle.fill",
                        tint: RecipePalette.basil,
                        text: "Added \(count) ingredient\(count == 1 ? "" : "s") to \(storeName)"
                    ) {
                        viewModel.clearSavedConfirmation()
                    }
                }

                // Success confirmation - recipe saved to list
                if let recipeName = viewModel.savedRecipeName {
                    statusBanner(
                        icon: "checkmark.circle.fill",
                        tint: RecipePalette.basil,
                        text: "\"\(recipeName)\" saved to your recipe list"
                    ) {
                        viewModel.clearSavedConfirmation()
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 8)
        }
    }

    private func statusBanner(
        icon: String,
        tint: Color,
        text: String,
        onDismiss: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tint)

            Text(text)
                .font(.footnote)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 8)

            Button("Dismiss", action: onDismiss)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(tint)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background { recipeSurface(for: colorScheme, cornerRadius: 14) }
    }

    // MARK: - Add Ingredients Button

    private func addIngredientsButton(for message: RecipeChatMessage) -> some View {
        let addToStore = recipeActionButton(
            title: "Add to Store",
            icon: "cart.badge.plus",
            fill: AnyShapeStyle(RecipePalette.warmGradient)
        ) {
            messageIdForStorePicker = message.id
        }

        let addToRecipes = recipeActionButton(
            title: "Add to Recipes",
            icon: "text.badge.plus",
            fill: AnyShapeStyle(RecipePalette.basil)
        ) {
            viewModel.addRecipeToList(messageId: message.id)
        }

        // Side by side where there is room; the pair is wider than the content
        // column on the smallest phones, so they stack there instead of wrapping
        // each label onto two lines.
        return ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                addToStore
                addToRecipes
            }

            VStack(alignment: .leading, spacing: 8) {
                addToStore
                addToRecipes
            }
        }
        .disabled(viewModel.isSavingIngredients)
        .opacity(viewModel.isSavingIngredients ? 0.6 : 1.0)
        // Lines up with the assistant bubble, which is inset by its avatar.
        .padding(.leading, 50)
        .padding(.trailing, 16)
    }

    private func recipeActionButton(
        title: String,
        icon: String,
        fill: AnyShapeStyle,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Capsule().fill(fill))
            .foregroundColor(.white)
            .shadow(color: RecipePalette.shadow(for: colorScheme), radius: 6, x: 0, y: 3)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Welcome View

    private var welcomeView: some View {
        VStack(spacing: 18) {
            Image(systemName: "fork.knife")
                .font(.system(size: 36, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 84, height: 84)
                .background(Circle().fill(RecipePalette.warmGradient))
                .overlay(Circle().stroke(Color.white.opacity(0.4), lineWidth: 1))
                .shadow(color: RecipePalette.paprika.opacity(0.35), radius: 18, x: 0, y: 8)
                .padding(.top, 36)

            VStack(spacing: 8) {
                Text("Recipe Assistant")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Ask for any recipe — meal ideas, step-by-step instructions, ingredient swaps — then send the ingredients straight to a store list.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            // Suggestion chips
            VStack(spacing: 10) {
                suggestionChip("Quick weeknight pasta dinner", icon: "timer")
                suggestionChip("Healthy breakfast smoothie bowl", icon: "leaf.fill")
                suggestionChip("Easy chocolate chip cookies", icon: "birthday.cake.fill")
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)
        }
        .padding(.bottom, 24)
    }

    private func suggestionChip(_ text: String, icon: String) -> some View {
        Button {
            viewModel.inputText = text
            viewModel.sendMessage()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(RecipePalette.paprika)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(RecipePalette.apricot.opacity(0.18)))

                Text(text)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)

                Spacer(minLength: 4)

                Image(systemName: "arrow.up.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background { recipeSurface(for: colorScheme, cornerRadius: 16) }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        let isSendDisabled = viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || viewModel.isLoading

        return HStack(spacing: 10) {
            TextField("Ask for a recipe...", text: $viewModel.inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...5)
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
                .background(
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .overlay(Capsule().fill(RecipePalette.surfaceTint(for: colorScheme)))
                        .overlay(Capsule().stroke(RecipePalette.surfaceBorder(for: colorScheme), lineWidth: 1))
                )
                .focused($isInputFocused)
                .onSubmit {
                    viewModel.sendMessage()
                }

            Button {
                viewModel.sendMessage()
            } label: {
                Image(systemName: "arrow.up")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 42, height: 42)
                    .background(
                        Circle().fill(isSendDisabled
                            ? AnyShapeStyle(Color.secondary.opacity(0.4))
                            : AnyShapeStyle(RecipePalette.warmGradient))
                    )
                    .shadow(
                        color: isSendDisabled ? .clear : RecipePalette.paprika.opacity(0.35),
                        radius: 8, x: 0, y: 4
                    )
            }
            .buttonStyle(.plain)
            .disabled(isSendDisabled)
            .animation(.easeInOut(duration: 0.15), value: isSendDisabled)
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(RecipePalette.hairline(for: colorScheme))
                        .frame(height: 0.5)
                }
                .ignoresSafeArea(edges: .bottom)
        )
    }
}

// MARK: - UUID Identifiable Conformance for sheet(item:)

extension UUID: @retroactive Identifiable {
    public var id: UUID { self }
}

// MARK: - Store Picker View

struct StorePickerView: View {
    let userStoreItems: [UserStoreItem]
    let colorScheme: ColorScheme
    let onSelect: (UserStoreItem) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if userStoreItems.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "storefront")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)
                        Text("No stores yet")
                            .font(.headline)
                        Text("Add a store first, then you can save recipe ingredients to it.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                } else {
                    List {
                        Section {
                            ForEach(userStoreItems) { item in
                                Button {
                                    onSelect(item)
                                } label: {
                                    HStack(spacing: 12) {
                                        CachedLogoImage(storeName: item.store.name, size: 40)

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(item.store.name)
                                                .font(.body)
                                                .fontWeight(.medium)
                                            if item.store.reminderCount > 0 {
                                                Text("\(item.store.reminderCount) item\(item.store.reminderCount == 1 ? "" : "s")")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                        }

                                        Spacer()

                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.vertical, 4)
                                }
                                .foregroundColor(.primary)
                            }
                        } header: {
                            Text("Select a store to add ingredients")
                        }
                    }
                }
            }
            .navigationTitle("Choose Store")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

}

// MARK: - Message Bubble View

struct MessageBubbleView: View {
    let message: RecipeChatMessage
    let colorScheme: ColorScheme

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if message.role == .assistant {
                RecipeAssistantAvatar()

                MarkdownTextView(text: message.content)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background { recipeSurface(for: colorScheme) }
                    .foregroundColor(.primary)

                Spacer(minLength: 40)
            } else {
                Spacer(minLength: 60)

                Text(message.content)
                    .font(.body)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 11)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(RecipePalette.warmGradient)
                    )
                    .foregroundColor(.white)
                    .shadow(color: RecipePalette.paprika.opacity(0.28), radius: 8, x: 0, y: 4)
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Markdown Text View

struct MarkdownTextView: View {
    let text: String

    private enum Block {
        case h1(String), h2(String), h3(String)
        case bullet(String)
        case numbered(Int, String)
        case paragraph(String)
        case spacer
    }

    private var blocks: [Block] {
        var result: [Block] = []
        var lastWasSpacer = true

        for line in text.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                if !lastWasSpacer {
                    result.append(.spacer)
                    lastWasSpacer = true
                }
            } else if let heading = parseHeading(trimmed) {
                switch heading.level {
                case 1: result.append(.h1(heading.content))
                case 2: result.append(.h2(heading.content))
                default: result.append(.h3(heading.content))
                }
                lastWasSpacer = false
            } else if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
                result.append(.bullet(String(trimmed.dropFirst(2))))
                lastWasSpacer = false
            } else if let parsed = parseNumbered(trimmed) {
                result.append(.numbered(parsed.0, parsed.1))
                lastWasSpacer = false
            } else {
                result.append(.paragraph(trimmed))
                lastWasSpacer = false
            }
        }

        if case .spacer = result.last { result.removeLast() }
        return result
    }

    private func parseHeading(_ text: String) -> (level: Int, content: String)? {
        // Strip surrounding bold/italic markers so "**### Ingredients**" still parses.
        var stripped = text
        while stripped.hasPrefix("**") && stripped.hasSuffix("**") && stripped.count > 4 {
            stripped = String(stripped.dropFirst(2).dropLast(2)).trimmingCharacters(in: .whitespaces)
        }
        while stripped.hasPrefix("*") && stripped.hasSuffix("*") && stripped.count > 2 {
            stripped = String(stripped.dropFirst().dropLast()).trimmingCharacters(in: .whitespaces)
        }

        var hashCount = 0
        for char in stripped {
            if char == "#" { hashCount += 1 } else { break }
        }
        guard hashCount > 0 else { return nil }

        var content = String(stripped.dropFirst(hashCount))
        // Strip trailing hashes (closed ATX headings like "### Foo ###").
        while content.hasSuffix("#") { content = String(content.dropLast()) }
        content = content.trimmingCharacters(in: .whitespaces)
        guard !content.isEmpty else { return nil }

        return (min(hashCount, 3), content)
    }

    private func parseNumbered(_ text: String) -> (Int, String)? {
        guard let dotIndex = text.firstIndex(of: ".") else { return nil }
        guard let num = Int(String(text[text.startIndex..<dotIndex])) else { return nil }
        let content = String(text[text.index(after: dotIndex)...]).trimmingCharacters(in: .whitespaces)
        guard !content.isEmpty else { return nil }
        return (num, content)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                blockView(for: block)
            }
        }
    }

    @ViewBuilder
    private func blockView(for block: Block) -> some View {
        switch block {
        case .h1(let content):
            inlineText(content)
                .font(.title2).fontWeight(.bold)
                .padding(.top, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
        case .h2(let content):
            inlineText(content)
                .font(.title3).fontWeight(.bold)
                .padding(.top, 4)
                .frame(maxWidth: .infinity, alignment: .leading)
        case .h3(let content):
            inlineText(content)
                .font(.headline).fontWeight(.bold)
                .padding(.top, 4)
                .frame(maxWidth: .infinity, alignment: .leading)
        case .bullet(let content):
            HStack(alignment: .top, spacing: 6) {
                Text("•").font(.body)
                inlineText(content).font(.body)
                Spacer(minLength: 0)
            }
        case .numbered(let num, let content):
            HStack(alignment: .top, spacing: 4) {
                Text("\(num).").font(.body)
                    .frame(minWidth: 24, alignment: .leading)
                inlineText(content).font(.body)
                Spacer(minLength: 0)
            }
        case .paragraph(let content):
            inlineText(content).font(.body)
                .frame(maxWidth: .infinity, alignment: .leading)
        case .spacer:
            Color.clear.frame(height: 4)
        }
    }

    private func inlineText(_ string: String) -> Text {
        if let attributed = try? AttributedString(
            markdown: string,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) {
            return Text(attributed)
        }
        return Text(string)
    }
}

// MARK: - Typing Indicator View

struct TypingIndicatorView: View {
    @State private var dotCount = 0
    let timer = Timer.publish(every: 0.4, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(RecipePalette.paprika)
                    .frame(width: 7, height: 7)
                    .opacity(dotCount % 3 == index ? 1.0 : 0.3)
            }
        }
        .onReceive(timer) { _ in
            dotCount += 1
        }
    }
}

#Preview {
    SmartRecipeView(viewModel: SmartRecipeViewModel(), storesViewModel: StoresViewModel())
}
