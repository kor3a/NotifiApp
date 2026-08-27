//
//  RecipeView.swift
//  Geolocation_v1.0.0
//
//  Created by Claude on 3/27/26.
//

import SwiftUI

// MARK: - RecipeView (Full Management — opened from StoresView FAB)

struct RecipeView: View {
    @StateObject private var viewModel = RecipeViewModel()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    @State private var showingNewRecipe = false
    @State private var recipeToEdit: Recipe?
    @State private var recipeToDelete: Recipe?

    var body: some View {
        NavigationStack {
            ZStack {
                // Same culinary artwork the Smart Recipe screen sits on, with a
                // heavier wash: this screen puts bare text on the photo instead
                // of tucking it inside cards.
                RecipeBackdrop(colorScheme: colorScheme, extraScrimOpacity: 0.22)

                if viewModel.isLoading {
                    ProgressView("Loading recipes...")
                } else if viewModel.recipes.isEmpty {
                    emptyStateView
                } else {
                    recipeList
                }
            }
            .tint(RecipePalette.paprika)
            .navigationTitle("My Recipes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingNewRecipe = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        // New recipe — no item needed
        .sheet(isPresented: $showingNewRecipe) {
            RecipeEditView(recipe: nil) { name, ingredients in
                viewModel.addRecipe(name: name, ingredients: ingredients)
            }
        }
        // Edit existing recipe — sheet(item:) guarantees the recipe is set before init
        .sheet(item: $recipeToEdit) { recipe in
            RecipeEditView(recipe: recipe) { name, ingredients in
                viewModel.updateRecipe(recipe, name: name, ingredients: ingredients)
            }
        }
        .alert("Delete Recipe", isPresented: Binding(
            get: { recipeToDelete != nil },
            set: { if !$0 { recipeToDelete = nil } }
        )) {
            Button("Delete", role: .destructive) {
                if let recipe = recipeToDelete {
                    viewModel.deleteRecipe(recipe)
                }
                recipeToDelete = nil
            }
            Button("Cancel", role: .cancel) { recipeToDelete = nil }
        } message: {
            if let recipe = recipeToDelete {
                Text("Delete \"\(recipe.name)\"? This cannot be undone.")
            }
        }
        .onAppear { viewModel.fetchRecipes() }
    }

    // MARK: - Recipe List

    /// Rows sit straight on the backdrop — no card per recipe. A hairline rule
    /// between rows and the warm accent rule on the left carry the separation
    /// instead.
    private var recipeList: some View {
        List {
            listHeader
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 4, leading: 22, bottom: 10, trailing: 22))
                .listRowSeparator(.hidden)

            ForEach(Array(viewModel.recipes.enumerated()), id: \.element.id) { index, recipe in
                VStack(spacing: 0) {
                    RecipeRowView(recipe: recipe, colorScheme: colorScheme)

                    if index < viewModel.recipes.count - 1 {
                        Rectangle()
                            .fill(recipeRowDivider(for: colorScheme))
                            .frame(height: 1)
                            .padding(.leading, 17)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    recipeToEdit = recipe
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 0, leading: 22, bottom: 0, trailing: 22))
                .listRowSeparator(.hidden)
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        recipeToDelete = recipe
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .environment(\.defaultMinListRowHeight, 0)
    }

    private var listHeader: some View {
        let count = viewModel.recipes.count
        return Text("\(count) recipe\(count == 1 ? "" : "s")")
            .font(.caption)
            .fontWeight(.semibold)
            .textCase(.uppercase)
            .tracking(1.1)
            .foregroundStyle(.secondary)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(RecipePalette.apricot.opacity(0.18))
                    .frame(width: 100, height: 100)
                Image(systemName: "fork.knife.circle")
                    .font(.system(size: 44, weight: .light))
                    .foregroundStyle(RecipePalette.paprika)
            }
            VStack(spacing: 8) {
                Text("No Recipes Yet")
                    .font(.title3)
                    .fontWeight(.semibold)
                Text("Tap  +  to create your first recipe\nand save your favourite ingredient lists.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
    }
}

// MARK: - Recipe Row

/// Hairline between rows. Kept a touch stronger than `RecipePalette.hairline`
/// so it still reads over the photograph without a card behind it.
private func recipeRowDivider(for colorScheme: ColorScheme) -> Color {
    colorScheme == .dark ? Color.white.opacity(0.16) : Color.black.opacity(0.12)
}

private struct RecipeRowView: View {
    let recipe: Recipe
    let colorScheme: ColorScheme

    /// Ingredients shown as chips before the row spills into a "+n" summary.
    private static let chipLimit = 3

    /// Indexed so a recipe that repeats an ingredient still gets stable row ids.
    private var visibleIngredients: [(offset: Int, element: String)] {
        Array(recipe.ingredients.prefix(Self.chipLimit).enumerated())
    }

    private var hiddenCount: Int {
        max(0, recipe.ingredients.count - Self.chipLimit)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            // Thin warm rule down the leading edge — the row's only ornament now
            // that the fork-and-knife tile is gone. Flat paprika, no gradient.
            Capsule()
                .fill(RecipePalette.paprika)
                .frame(width: 3)

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(recipe.name)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Spacer(minLength: 4)

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.tertiary)
                }

                if recipe.ingredients.isEmpty {
                    Text("No ingredients yet")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    HStack(spacing: 6) {
                        ForEach(visibleIngredients, id: \.offset) { _, ingredient in
                            IngredientChip(text: ingredient, colorScheme: colorScheme)
                        }
                        if hiddenCount > 0 {
                            Text("+\(hiddenCount)")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundStyle(.secondary)
                                .fixedSize()
                        }
                        Spacer(minLength: 0)
                    }
                }
            }
        }
        .padding(.vertical, 16)
    }
}

/// Single ingredient, shown as a soft capsule. Deliberately lighter than a card:
/// tinted fill, hairline edge, no shadow.
private struct IngredientChip: View {
    let text: String
    let colorScheme: ColorScheme

    var body: some View {
        Text(text)
            .font(.caption2)
            .foregroundStyle(.primary)
            .lineLimit(1)
            .truncationMode(.tail)
            .padding(.vertical, 4)
            .padding(.horizontal, 9)
            .background(
                Capsule()
                    .fill(RecipePalette.apricot.opacity(colorScheme == .dark ? 0.20 : 0.26))
            )
            .overlay(
                Capsule()
                    .stroke(RecipePalette.apricot.opacity(0.42), lineWidth: 1)
            )
    }
}

// MARK: - Recipe Edit / Create View

struct RecipeEditView: View {
    let recipe: Recipe?
    let onSave: (String, [String]) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    @State private var recipeName: String
    @State private var ingredients: [String]
    @State private var newIngredientText: String = ""
    @FocusState private var isNameFocused: Bool
    @FocusState private var isNewIngredientFocused: Bool

    init(recipe: Recipe?, onSave: @escaping (String, [String]) -> Void) {
        self.recipe = recipe
        self.onSave = onSave
        _recipeName = State(initialValue: recipe?.name ?? "")
        _ingredients = State(initialValue: recipe?.ingredients ?? [])
    }

    private var isValid: Bool {
        let hasName = !recipeName.trimmingCharacters(in: .whitespaces).isEmpty
        let hasIngredients = !ingredients.isEmpty || !newIngredientText.trimmingCharacters(in: .whitespaces).isEmpty
        return hasName && hasIngredients
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.backgroundGradient(for: colorScheme)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Recipe Name
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Recipe Name")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 4)
                            TextField("e.g. Pasta Carbonara", text: $recipeName)
                                .font(.body)
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(.ultraThinMaterial)
                                )
                                .focused($isNameFocused)
                                .submitLabel(.next)
                                .onSubmit { isNewIngredientFocused = true }
                        }

                        // Ingredients
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Ingredients")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 4)

                            // Existing ingredients
                            if !ingredients.isEmpty {
                                VStack(spacing: 0) {
                                    ForEach(Array(ingredients.enumerated()), id: \.offset) { index, ingredient in
                                        HStack {
                                            Image(systemName: "circle.fill")
                                                .font(.system(size: 6))
                                                .foregroundStyle(.secondary)
                                            Text(ingredient)
                                                .font(.body)
                                            Spacer()
                                            Button {
                                                ingredients.remove(at: index)
                                            } label: {
                                                Image(systemName: "xmark.circle.fill")
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 10)

                                        if index < ingredients.count - 1 {
                                            Divider().padding(.horizontal, 14)
                                        }
                                    }
                                }
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(.ultraThinMaterial)
                                )
                            }

                            // Add ingredient field
                            HStack(spacing: 10) {
                                TextField("Add ingredient…", text: $newIngredientText)
                                    .font(.body)
                                    .padding()
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(.ultraThinMaterial)
                                    )
                                    .focused($isNewIngredientFocused)
                                    .submitLabel(.done)
                                    .onSubmit { addIngredient() }

                                Button(action: addIngredient) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 32))
                                        .foregroundStyle(
                                            newIngredientText.trimmingCharacters(in: .whitespaces).isEmpty
                                                ? Color.secondary
                                                : Color.appAccent
                                        )
                                }
                                .disabled(newIngredientText.trimmingCharacters(in: .whitespaces).isEmpty)
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle(recipe == nil ? "New Recipe" : "Edit Recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        let name = recipeName.trimmingCharacters(in: .whitespaces)
                        // Finalize any in-progress ingredient text before saving
                        let finalIngredients: [String]
                        let pending = newIngredientText.trimmingCharacters(in: .whitespaces)
                        if !pending.isEmpty {
                            finalIngredients = ingredients + [pending]
                        } else {
                            finalIngredients = ingredients
                        }
                        onSave(name, finalIngredients)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(!isValid)
                }
            }
        }
    }

    private func addIngredient() {
        let text = newIngredientText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        ingredients.append(text)
        newIngredientText = ""
        isNewIngredientFocused = true
    }
}

// MARK: - Recipe Picker View (opened from ReminderView info panel)

struct RecipePickerView: View {
    let userStoreItem: UserStoreItem
    /// Whether the added ingredients should be auto-categorized. Passed in from
    /// ReminderView so this sheet uses the same rule as the rest of the store
    /// (subscriber with the store's Smart Category toggle on).
    var useSmartCategory: Bool = false
    @StateObject private var viewModel = RecipeViewModel()
    @ObservedObject private var subscriptionManager = SubscriptionManager.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    @State private var addedCount: Int?
    @State private var addedForRecipeName: String?

    var body: some View {
        NavigationStack {
            ZStack {
                OrganicPalette.canvas(colorScheme)
                    .ignoresSafeArea()

                if viewModel.isLoading {
                    ProgressView("Loading recipes...")
                        .tint(OrganicPalette.terracotta(colorScheme))
                        .foregroundColor(OrganicPalette.inkSoft(colorScheme))
                } else if viewModel.recipes.isEmpty {
                    emptyStateView
                } else {
                    recipeList
                }

                if viewModel.isSavingIngredients {
                    Color.black.opacity(0.25)
                        .ignoresSafeArea()

                    ProgressView("Adding ingredients…")
                        .tint(OrganicPalette.terracotta(colorScheme))
                        .foregroundColor(OrganicPalette.inkSoft(colorScheme))
                        .padding(24)
                        .background(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .fill(OrganicPalette.surface(colorScheme))
                        )
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(OrganicPalette.canvas(colorScheme), for: .navigationBar)
            .tint(OrganicPalette.terracotta(colorScheme))
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(OrganicPalette.terracotta(colorScheme))
                }

                ToolbarItem(placement: .principal) {
                    Text("Choose a Recipe")
                        .font(.system(size: 17, weight: .bold, design: .serif))
                        .foregroundColor(OrganicPalette.ink(colorScheme))
                }
            }
        }
        .alert("Ingredients Added", isPresented: Binding(
            get: { addedCount != nil },
            set: { if !$0 { addedCount = nil; dismiss() } }
        )) {
            Button("OK") {
                addedCount = nil
                dismiss()
            }
        } message: {
            if let count = addedCount, let name = addedForRecipeName {
                if count > 0 {
                    Text("Added \(count) ingredient\(count == 1 ? "" : "s") from \"\(name)\" to \(userStoreItem.store.name).")
                } else {
                    Text("All ingredients from \"\(name)\" already exist in \(userStoreItem.store.name).")
                }
            }
        }
        .onAppear { viewModel.fetchRecipes() }
    }

    private var recipeList: some View {
        List {
            ForEach(viewModel.recipes) { recipe in
                RecipePickerRowView(recipe: recipe)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        viewModel.addIngredientsToStore(
                            recipe,
                            userStoreItem: userStoreItem,
                            useSmartCategory: useSmartCategory && subscriptionManager.isSubscribed
                        ) { count in
                            addedCount = count
                            addedForRecipeName = recipe.name
                        }
                    }
                    .organicRow()
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private var emptyStateView: some View {
        OrganicEmptyState(
            systemImage: "fork.knife",
            title: "No recipes yet",
            message: "Create recipes from the Stores screen using the + button."
        )
    }
}

// MARK: - Recipe Picker Row

private struct RecipePickerRowView: View {
    let recipe: Recipe

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "fork.knife")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(OrganicPalette.terracotta(colorScheme))
                .frame(width: 44, height: 44)
                .background(Circle().fill(OrganicPalette.blush(colorScheme)))

            VStack(alignment: .leading, spacing: 3) {
                Text(recipe.name)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(OrganicPalette.ink(colorScheme))
                    .lineLimit(1)

                Text(recipe.ingredients.prefix(3).joined(separator: ", ") + (recipe.ingredients.count > 3 ? "\u{2026}" : ""))
                    .font(.system(size: 13))
                    .foregroundColor(OrganicPalette.inkSoft(colorScheme))
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Image(systemName: "plus.circle.fill")
                .font(.system(size: 22))
                .foregroundColor(OrganicPalette.terracotta(colorScheme))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(OrganicCardBackground(colorScheme: colorScheme))
    }
}
