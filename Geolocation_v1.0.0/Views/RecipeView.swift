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
    @State private var showingEditRecipe = false
    @State private var recipeToEdit: Recipe?
    @State private var recipeToDelete: Recipe?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.backgroundGradient(for: colorScheme)
                    .ignoresSafeArea()

                if viewModel.isLoading {
                    ProgressView("Loading recipes...")
                } else if viewModel.recipes.isEmpty {
                    emptyStateView
                } else {
                    recipeList
                }
            }
            .navigationTitle("My Recipes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        recipeToEdit = nil
                        showingEditRecipe = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $showingEditRecipe) {
            RecipeEditView(
                recipe: recipeToEdit,
                onSave: { name, ingredients in
                    if let existing = recipeToEdit {
                        viewModel.updateRecipe(existing, name: name, ingredients: ingredients)
                    } else {
                        viewModel.addRecipe(name: name, ingredients: ingredients)
                    }
                }
            )
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

    private var recipeList: some View {
        List {
            ForEach(viewModel.recipes) { recipe in
                RecipeRowView(recipe: recipe)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        recipeToEdit = recipe
                        showingEditRecipe = true
                    }
                    .listRowBackground(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.cardBorder(for: colorScheme), lineWidth: 1.5)
                            )
                            .padding(.vertical, 4)
                    )
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
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [Color.blue.opacity(0.15), Color.purple.opacity(0.15)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 100, height: 100)
                Image(systemName: "fork.knife.circle")
                    .font(.system(size: 44, weight: .light))
                    .foregroundStyle(LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
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

private struct RecipeRowView: View {
    let recipe: Recipe

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.12))
                    .frame(width: 42, height: 42)
                Image(systemName: "fork.knife")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Color.appAccent)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(recipe.name)
                    .font(.body)
                    .fontWeight(.medium)
                Text("\(recipe.ingredients.count) ingredient\(recipe.ingredients.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 4)
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
        !recipeName.trimmingCharacters(in: .whitespaces).isEmpty && !ingredients.isEmpty
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
    @StateObject private var viewModel = RecipeViewModel()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    @State private var addedCount: Int?
    @State private var addedForRecipeName: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.backgroundGradient(for: colorScheme)
                    .ignoresSafeArea()

                if viewModel.isLoading {
                    ProgressView("Loading recipes...")
                } else if viewModel.recipes.isEmpty {
                    emptyStateView
                } else {
                    recipeList
                }

                if viewModel.isSavingIngredients {
                    Color.black.opacity(0.25)
                        .ignoresSafeArea()
                    ProgressView("Adding ingredients…")
                        .padding()
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                }
            }
            .navigationTitle("Choose a Recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
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
                        viewModel.addIngredientsToStore(recipe, userStoreItem: userStoreItem) { count in
                            addedCount = count
                            addedForRecipeName = recipe.name
                        }
                    }
                    .listRowBackground(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.cardBorder(for: colorScheme), lineWidth: 1.5)
                            )
                            .padding(.vertical, 4)
                    )
                    .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "fork.knife.circle")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(.secondary)
            Text("No Recipes")
                .font(.title3)
                .fontWeight(.semibold)
            Text("Create recipes from the Stores screen\nusing the  +  button.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

// MARK: - Recipe Picker Row

private struct RecipePickerRowView: View {
    let recipe: Recipe

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.12))
                    .frame(width: 42, height: 42)
                Image(systemName: "fork.knife")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Color.appAccent)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(recipe.name)
                    .font(.body)
                    .fontWeight(.medium)
                Text(recipe.ingredients.prefix(3).joined(separator: ", ") + (recipe.ingredients.count > 3 ? "…" : ""))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Image(systemName: "plus.circle")
                .font(.title3)
                .foregroundStyle(Color.appAccent)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 4)
    }
}
