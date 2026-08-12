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

        guard let jsonData = Self.stripCodeFences(content).data(using: .utf8),
              let ingredients = try? JSONSerialization.jsonObject(with: jsonData) as? [String] else {
            throw OpenAIError.invalidResponse
        }

        return ingredients
    }

    /// Models often wrap JSON replies in a markdown code fence despite being
    /// told not to. Strip it so the payload parses.
    private static func stripCodeFences(_ content: String) -> String {
        var cleaned = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleaned.hasPrefix("```") else { return cleaned }

        // Remove the opening fence (```json or ```)
        if let firstNewline = cleaned.firstIndex(of: "\n") {
            cleaned = String(cleaned[cleaned.index(after: firstNewline)...])
        }
        if cleaned.hasSuffix("```") {
            cleaned = String(cleaned.dropLast(3))
        }
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
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

        guard let jsonData = Self.stripCodeFences(content).data(using: .utf8),
              let mapping = try? JSONSerialization.jsonObject(with: jsonData) as? [String: String] else {
            throw OpenAIError.invalidResponse
        }

        return mapping
    }

    // MARK: - Voice Commands

    /// Turns a spoken request into a plan of changes for one store's list.
    ///
    /// The current list is sent along with its document IDs so the model can
    /// point at the exact item the user meant. Nothing here is trusted blindly —
    /// `VoiceCommandPlanner.resolve` re-matches every returned action against
    /// live data before the app writes anything.
    func parseVoiceCommand(
        transcript: String,
        storeName: String,
        reminders: [Reminder]
    ) async throws -> VoiceCommandPlan {
        let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw OpenAIError.invalidResponse }

        let systemPrompt = ChatMessage(
            role: "system",
            content: """
            You convert a spoken request into changes to a shopping/reminder list \
            for the store "\(storeName)".

            Return ONLY a JSON object, no prose and no code fences:
            {
              "confirmation": "<one short sentence describing what you will do, addressed to the user>",
              "actions": [ { "type": "...", "id": "...", "title": "...", "quantity": 1, "newTitle": "..." } ],
              "notes": ["<anything you could not act on, phrased for the user>"]
            }

            Allowed "type" values and their fields:
            - "add": new item. Requires "title" (short, singular, capitalized, no quantity words). \
            Optional "quantity" (integer > 1).
            - "delete": remove an existing item. Requires "id".
            - "check": mark an existing item done/bought/got it. Requires "id".
            - "uncheck": mark an existing item not done again. Requires "id".
            - "setQuantity": change how many of an existing item. Requires "id" and "quantity".
            - "rename": change an existing item's name. Requires "id" and "newTitle".
            - "outOfStock": mark an existing item unavailable at the store. Requires "id".

            Rules:
            - Every type except "add" MUST use an "id" copied exactly from the CURRENT LIST. \
            Never invent an id. If the user refers to something not on the list, put an entry in \
            "notes" instead of guessing.
            - Also include the item's "title" on every action so it can be read back.
            - One action per item. "Add milk and eggs" is two "add" actions.
            - If the request is not about this list at all, return no actions and explain in "notes".
            - Write "confirmation" and "notes" in the same language the user spoke.
            """
        )

        let listMessage = ChatMessage(
            role: "user",
            content: "CURRENT LIST:\n\(Self.listContext(for: reminders))"
        )
        let requestMessage = ChatMessage(role: "user", content: "SPOKEN REQUEST:\n\(trimmed)")

        let content = try await chat(
            messages: [systemPrompt, listMessage, requestMessage],
            temperature: 0.0,
            maxTokens: 700
        )

        guard let jsonData = Self.stripCodeFences(content).data(using: .utf8),
              let plan = try? JSONDecoder().decode(VoiceCommandPlan.self, from: jsonData) else {
            throw OpenAIError.invalidResponse
        }
        return plan
    }

    /// The current list as compact JSON. Capped because the proxy rejects
    /// oversized requests, and a list this long is already past the point where
    /// a spoken command is the right tool.
    private static func listContext(for reminders: [Reminder]) -> String {
        guard !reminders.isEmpty else { return "[]" }

        let entries = reminders.prefix(120).map { reminder -> [String: Any] in
            var entry: [String: Any] = [
                "id": reminder.id,
                "title": reminder.title,
                "done": reminder.isDone
            ]
            if let quantity = reminder.quantity { entry["quantity"] = quantity }
            if reminder.isOutOfStock == true { entry["outOfStock"] = true }
            return entry
        }

        guard let data = try? JSONSerialization.data(withJSONObject: entries),
              let json = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return json
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
