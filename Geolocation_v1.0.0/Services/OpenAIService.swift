//
//  OpenAIService.swift
//  Geolocation_v1.0.0
//
//  Created by Claude on 2/20/26.
//
//  SECURITY: This service no longer talks to the OpenAI API directly, and no
//  longer reads an OPENAI_API_KEY from Info.plist/Secrets.xcconfig. A key
//  compiled into the app can be extracted from the shipped .ipa and abused to
//  run up charges, so all completions now go through the authenticated
//  `openAIChat` Cloud Function, which holds the key server-side (Functions
//  secrets). Once this build is live, rotate any key that was previously
//  embedded in the client — assume it is compromised.
//

import Foundation
import FirebaseFunctions

class OpenAIService {
    static let shared = OpenAIService()

    private lazy var functions = Functions.functions()

    private init() {}

    struct ChatMessage: Codable {
        let role: String
        let content: String
    }

    /// Send a set of chat messages through the server-side proxy and return the
    /// assistant's text content. Shared by every method below.
    private func chat(
        messages: [ChatMessage],
        temperature: Double,
        maxTokens: Int
    ) async throws -> String {
        let payload: [String: Any] = [
            "messages": messages.map { ["role": $0.role, "content": $0.content] },
            "temperature": temperature,
            "maxTokens": maxTokens
        ]

        let result: HTTPSCallableResult
        do {
            result = try await functions.httpsCallable("openAIChat").call(payload)
        } catch {
            #if DEBUG
            print("OpenAIService: openAIChat call failed: \(error)")
            #endif
            throw OpenAIError.networkError
        }

        guard let data = result.data as? [String: Any],
              let content = data["content"] as? String else {
            throw OpenAIError.invalidResponse
        }
        return content
    }

    func extractIngredients(from recipeText: String) async throws -> [String] {
        let extractionPrompt = ChatMessage(
            role: "system",
            content: """
            Extract only the ingredient names from the recipe below. \
            Return a JSON array of short ingredient names suitable for a shopping list. \
            Simplify each ingredient to its core item (e.g. "2 cups all-purpose flour" becomes "All-purpose flour", \
            "1/2 cup unsalted butter, melted" becomes "Unsalted butter"). \
            Do not include quantities or preparation notes. \
            Return ONLY the JSON array, no other text.
            """
        )

        let userMessage = ChatMessage(role: "user", content: recipeText)

        let content = try await chat(
            messages: [extractionPrompt, userMessage],
            temperature: 0.0,
            maxTokens: 512
        )

        // Strip markdown code fences if present (e.g. ```json ... ```)
        var cleaned = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("```") {
            // Remove opening fence (```json or ```)
            if let firstNewline = cleaned.firstIndex(of: "\n") {
                cleaned = String(cleaned[cleaned.index(after: firstNewline)...])
            }
            // Remove closing fence
            if cleaned.hasSuffix("```") {
                cleaned = String(cleaned.dropLast(3))
            }
            cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        guard let jsonData = cleaned.data(using: .utf8),
              let ingredients = try? JSONSerialization.jsonObject(with: jsonData) as? [String] else {
            throw OpenAIError.invalidResponse
        }

        return ingredients
    }

    /// Categorize a list of reminder/shopping items into store categories.
    /// Returns a dictionary mapping each item title to its category string.
    /// Items the AI cannot confidently categorize will be mapped to "Uncategorized".
    func categorizeItems(_ items: [String]) async throws -> [String: String] {
        guard !items.isEmpty else { return [:] }

        let systemPrompt = ChatMessage(
            role: "system",
            content: """
            You categorize shopping/reminder items into store aisle categories. \
            Given a JSON array of item names, return a JSON object mapping each item to exactly one category. \
            Use these categories when they fit: Produce, Dairy, Meat & Seafood, Bakery, Beverages, \
            Snacks, Frozen, Canned Goods, Condiments & Sauces, Grains & Pasta, Household, \
            Personal Care, Baby, Pet, Health, Electronics, Clothing, \
            Office & Stationery, Furniture, Hardware & Tools, Home & Kitchen, \
            Toys & Games, Sports & Outdoors, Automotive, Garden & Outdoor, Books & Media, Craft & Hobby. \
            These items are not limited to groceries — categorize everyday non-food items too \
            (e.g. "pencil" and "paper" are Office & Stationery, "desk" is Furniture, "screwdriver" is Hardware & Tools). \
            Only map an item to "Uncategorized" as a last resort when it genuinely fits none of the categories above. \
            Return ONLY the JSON object, no other text.
            """
        )

        let userMessage = ChatMessage(role: "user", content: "[\(items.map { "\"\($0)\"" }.joined(separator: ", "))]")

        let content = try await chat(
            messages: [systemPrompt, userMessage],
            temperature: 0.0,
            maxTokens: 512
        )

        // Strip markdown code fences if present
        var cleaned = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("```") {
            if let firstNewline = cleaned.firstIndex(of: "\n") {
                cleaned = String(cleaned[cleaned.index(after: firstNewline)...])
            }
            if cleaned.hasSuffix("```") {
                cleaned = String(cleaned.dropLast(3))
            }
            cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        guard let jsonData = cleaned.data(using: .utf8),
              let mapping = try? JSONSerialization.jsonObject(with: jsonData) as? [String: String] else {
            throw OpenAIError.invalidResponse
        }

        return mapping
    }

    func sendMessage(messages: [ChatMessage]) async throws -> String {
        let systemMessage = ChatMessage(
            role: "system",
            content: """
            You are a helpful recipe assistant. When users ask for recipes, provide clear, \
            well-formatted recipes with ingredients and step-by-step instructions. \
            Keep responses concise but complete. Use simple formatting with numbered steps \
            and bullet points for ingredients.
            """
        )

        return try await chat(
            messages: [systemMessage] + messages,
            temperature: 0.7,
            maxTokens: 1024
        )
    }
}

// MARK: - Errors

enum OpenAIError: Error, LocalizedError {
    case invalidURL
    case networkError
    case apiError(statusCode: Int)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .networkError:
            return "Network error occurred"
        case .apiError(let statusCode):
            return "API error (status code: \(statusCode))"
        case .invalidResponse:
            return "Invalid response from OpenAI"
        }
    }
}
