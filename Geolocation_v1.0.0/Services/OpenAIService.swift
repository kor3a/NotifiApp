//
//  OpenAIService.swift
//  Geolocation_v1.0.0
//
//  Created by Claude on 2/20/26.
//

import Foundation

class OpenAIService {
    static let shared = OpenAIService()

    private let apiKey: String = {
        guard let key = Bundle.main.infoDictionary?["OPENAI_API_KEY"] as? String, !key.isEmpty else {
            fatalError("OPENAI_API_KEY not set. Add your key to Secrets.xcconfig (see Secrets.xcconfig.template).")
        }
        return key
    }()

    private let baseURL = "https://api.openai.com/v1/chat/completions"

    private init() {}

    struct ChatMessage: Codable {
        let role: String
        let content: String
    }

    func extractIngredients(from recipeText: String) async throws -> [String] {
        guard let url = URL(string: baseURL) else {
            throw OpenAIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

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

        let body: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": [
                ["role": extractionPrompt.role, "content": extractionPrompt.content],
                ["role": userMessage.role, "content": userMessage.content]
            ],
            "temperature": 0.0,
            "max_tokens": 512
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw OpenAIError.invalidResponse
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let choices = json?["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw OpenAIError.invalidResponse
        }

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
        guard let url = URL(string: baseURL) else {
            throw OpenAIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let systemPrompt = ChatMessage(
            role: "system",
            content: """
            You categorize shopping/reminder items into store aisle categories. \
            Given a JSON array of item names, return a JSON object mapping each item to exactly one category. \
            Use these categories when they fit: Produce, Dairy, Meat & Seafood, Bakery, Beverages, \
            Snacks, Frozen, Canned Goods, Condiments & Sauces, Grains & Pasta, Household, \
            Personal Care, Baby, Pet, Health, Electronics, Clothing. \
            If an item does not clearly fit any category, map it to "Uncategorized". \
            Return ONLY the JSON object, no other text.
            """
        )

        let userMessage = ChatMessage(role: "user", content: "[\(items.map { "\"\($0)\"" }.joined(separator: ", "))]")

        let body: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": [
                ["role": systemPrompt.role, "content": systemPrompt.content],
                ["role": userMessage.role, "content": userMessage.content]
            ],
            "temperature": 0.0,
            "max_tokens": 512
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw OpenAIError.invalidResponse
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let choices = json?["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw OpenAIError.invalidResponse
        }

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

    /// Generate a subscription hero image using DALL-E 3.
    /// Returns a URL string pointing to the generated image.
    func generateSubscriptionImage() async throws -> String {
        let imageURL = "https://api.openai.com/v1/images/generations"
        guard let url = URL(string: imageURL) else {
            throw OpenAIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let prompt = """
        A premium mobile app subscription illustration. A golden crown glowing with light sits \
        above a stylized shopping cart filled with fresh groceries, surrounded by sparkles and \
        small floating map location pins. The background is a smooth gradient from deep blue to \
        vibrant purple. Modern, clean, flat illustration style, no text.
        """

        let body: [String: Any] = [
            "model": "dall-e-3",
            "prompt": prompt,
            "n": 1,
            "size": "1024x1024",
            "quality": "standard"
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw OpenAIError.invalidResponse
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let dataArray = json?["data"] as? [[String: Any]],
              let firstItem = dataArray.first,
              let generatedURL = firstItem["url"] as? String else {
            throw OpenAIError.invalidResponse
        }

        return generatedURL
    }

    func sendMessage(messages: [ChatMessage]) async throws -> String {
        guard let url = URL(string: baseURL) else {
            throw OpenAIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let systemMessage = ChatMessage(
            role: "system",
            content: """
            You are a helpful recipe assistant. When users ask for recipes, provide clear, \
            well-formatted recipes with ingredients and step-by-step instructions. \
            Keep responses concise but complete. Use simple formatting with numbered steps \
            and bullet points for ingredients.
            """
        )

        let allMessages = [systemMessage] + messages

        let body: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": allMessages.map { ["role": $0.role, "content": $0.content] },
            "temperature": 0.7,
            "max_tokens": 1024
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIError.networkError
        }

        guard httpResponse.statusCode == 200 else {
            if let errorBody = String(data: data, encoding: .utf8) {
                #if DEBUG
                print("OpenAI API Error: \(errorBody)")
                #endif
            }
            throw OpenAIError.apiError(statusCode: httpResponse.statusCode)
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let choices = json?["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw OpenAIError.invalidResponse
        }

        return content
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
