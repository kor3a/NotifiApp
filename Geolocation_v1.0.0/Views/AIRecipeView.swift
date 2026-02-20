//
//  AIRecipeView.swift
//  Geolocation_v1.0.0
//
//  Created by Claude on 2/20/26.
//

import SwiftUI

struct AIRecipeView: View {
    @StateObject private var viewModel = AIRecipeViewModel()
    @ObservedObject var storesViewModel: StoresViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    @FocusState private var isInputFocused: Bool
    @State private var messageIdForStorePicker: UUID?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Chat messages
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            // Welcome message
                            if viewModel.messages.isEmpty {
                                welcomeView
                            }

                            ForEach(viewModel.messages) { message in
                                VStack(alignment: .leading, spacing: 8) {
                                    MessageBubbleView(message: message, colorScheme: colorScheme)

                                    // Show "Add Ingredients to Store" button for recipe messages with ingredients
                                    if message.role == .assistant, let ingredients = message.ingredients, !ingredients.isEmpty {
                                        addIngredientsButton(for: message)
                                    }
                                }
                                .id(message.id)
                            }

                            if viewModel.isLoading {
                                HStack {
                                    TypingIndicatorView()
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 10)
                                        .background(
                                            RoundedRectangle(cornerRadius: 16)
                                                .fill(colorScheme == .dark
                                                    ? Color(white: 0.2)
                                                    : Color(white: 0.92))
                                        )
                                    Spacer()
                                }
                                .padding(.horizontal)
                                .id("loading")
                            }
                        }
                        .padding(.vertical, 12)
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

                // Error message
                if let error = viewModel.errorMessage {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Button("Dismiss") {
                            viewModel.errorMessage = nil
                        }
                        .font(.caption)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color.orange.opacity(0.1))
                }

                // Success confirmation
                if let count = viewModel.savedIngredientsCount, let storeName = viewModel.savedToStoreName {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Added \(count) ingredient\(count == 1 ? "" : "s") to \(storeName)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Button("Dismiss") {
                            viewModel.clearSavedConfirmation()
                        }
                        .font(.caption)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color.green.opacity(0.1))
                }

                Divider()

                // Input bar
                inputBar
            }
            .background(Color.backgroundGradient(for: colorScheme).ignoresSafeArea())
            .navigationTitle("AI Recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
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

    // MARK: - Add Ingredients Button

    private func addIngredientsButton(for message: RecipeChatMessage) -> some View {
        Button {
            messageIdForStorePicker = message.id
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "cart.badge.plus")
                    .font(.system(size: 14))
                Text("Add Ingredients to Store")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.blue)
            )
            .foregroundColor(.white)
        }
        .disabled(viewModel.isSavingIngredients)
        .opacity(viewModel.isSavingIngredients ? 0.6 : 1.0)
        .padding(.horizontal)
    }

    // MARK: - Welcome View

    private var welcomeView: some View {
        VStack(spacing: 16) {
            Image(systemName: "fork.knife.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.linearGradient(
                    colors: [.blue, .purple],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .padding(.top, 40)

            Text("AI Recipe Assistant")
                .font(.title2)
                .fontWeight(.bold)

            Text("Ask me for any recipe! I can help with meal ideas, cooking instructions, ingredient substitutions, and more.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            // Suggestion chips
            VStack(spacing: 8) {
                suggestionChip("Quick weeknight pasta dinner")
                suggestionChip("Healthy breakfast smoothie bowl")
                suggestionChip("Easy chocolate chip cookies")
            }
            .padding(.top, 8)
        }
        .padding(.bottom, 20)
    }

    private func suggestionChip(_ text: String) -> some View {
        Button {
            viewModel.inputText = text
            viewModel.sendMessage()
        } label: {
            Text(text)
                .font(.subheadline)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                        )
                )
                .foregroundColor(.primary)
        }
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        HStack(spacing: 12) {
            TextField("Ask for a recipe...", text: $viewModel.inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...5)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(colorScheme == .dark
                            ? Color(white: 0.15)
                            : Color(white: 0.95))
                )
                .focused($isInputFocused)
                .onSubmit {
                    viewModel.sendMessage()
                }

            Button {
                viewModel.sendMessage()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(
                        viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isLoading
                            ? Color.gray
                            : Color.blue
                    )
            }
            .disabled(viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isLoading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
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
                                        if let logoURL = StoreLogoProvider.shared.logoURL(for: item.store.name),
                                           let url = URL(string: logoURL) {
                                            AsyncImage(url: url) { phase in
                                                switch phase {
                                                case .success(let image):
                                                    image
                                                        .resizable()
                                                        .scaledToFill()
                                                        .frame(width: 40, height: 40)
                                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                                default:
                                                    storeIconPlaceholder(for: item.store.name)
                                                }
                                            }
                                            .frame(width: 40, height: 40)
                                        } else {
                                            storeIconPlaceholder(for: item.store.name)
                                        }

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

    private func storeIconPlaceholder(for name: String) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.blue.opacity(0.15))
                .frame(width: 40, height: 40)
            Text(String(name.prefix(1)).uppercased())
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.blue)
        }
    }
}

// MARK: - Message Bubble View

struct MessageBubbleView: View {
    let message: RecipeChatMessage
    let colorScheme: ColorScheme

    var body: some View {
        HStack {
            if message.role == .user {
                Spacer(minLength: 60)
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .font(.body)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(message.role == .user
                                ? Color.blue
                                : (colorScheme == .dark
                                    ? Color(white: 0.2)
                                    : Color(white: 0.92)))
                    )
                    .foregroundColor(message.role == .user ? .white : .primary)
            }

            if message.role == .assistant {
                Spacer(minLength: 60)
            }
        }
        .padding(.horizontal)
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
                    .fill(Color.secondary)
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
    AIRecipeView(storesViewModel: StoresViewModel())
}
