import Foundation
import UIKit

// MARK: - Food Analysis Service

/// Analyzes food from natural language descriptions or images using the Anthropic API.
/// Falls back to the Dispatcher chat system if API key is not configured.
@MainActor @Observable
final class FoodAnalysisService {
    var isAnalyzing = false
    var analysisError: String?

    private let apiKey: String?

    init() {
        self.apiKey = UserDefaults.standard.string(forKey: StorageKeys.anthropicAPIKey)
    }

    /// Analyze food from a text description.
    func analyzeText(_ description: String) async -> FoodAnalysisResult? {
        isAnalyzing = true
        analysisError = nil
        defer { isAnalyzing = false }

        let prompt = buildTextPrompt(description)

        if let key = apiKey, !key.isEmpty {
            return await callAnthropicAPI(messages: [
                .init(role: "user", content: [.text(prompt)])
            ], apiKey: key)
        } else {
            // Fallback: send through Dispatcher
            sendThroughDispatcher(prompt)
            return nil
        }
    }

    /// Analyze food from an image (photo of a meal).
    func analyzeImage(_ image: UIImage, context: String? = nil) async -> FoodAnalysisResult? {
        isAnalyzing = true
        analysisError = nil
        defer { isAnalyzing = false }

        guard let imageData = image.jpegData(compressionQuality: 0.6) else {
            analysisError = "Failed to process image"
            return nil
        }

        let base64 = imageData.base64EncodedString()
        let textPart = context ?? "What food is in this image?"
        let prompt = buildImagePrompt(textPart)

        if let key = apiKey, !key.isEmpty {
            return await callAnthropicAPI(messages: [
                .init(role: "user", content: [
                    .image(mediaType: "image/jpeg", data: base64),
                    .text(prompt)
                ])
            ], apiKey: key)
        } else {
            sendThroughDispatcher("Analyze this meal: \(textPart)")
            return nil
        }
    }

    /// Save API key.
    func saveAPIKey(_ key: String) {
        UserDefaults.standard.set(key, forKey: StorageKeys.anthropicAPIKey)
    }

    var hasAPIKey: Bool {
        guard let key = apiKey else { return false }
        return !key.isEmpty
    }

    // MARK: - Anthropic API

    private func callAnthropicAPI(messages: [APIMessage], apiKey: String) async -> FoodAnalysisResult? {
        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.timeoutInterval = 30

        let body = APIRequestBody(
            model: "claude-haiku-4-5-20251001",
            maxTokens: 1024,
            messages: messages
        )

        do {
            request.httpBody = try JSONEncoder().encode(body)
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                let http = response as? HTTPURLResponse
                analysisError = "API error (\(http?.statusCode ?? 0))"
                return nil
            }

            let apiResponse = try JSONDecoder().decode(APIResponse.self, from: data)
            guard let text = apiResponse.content.first?.text else {
                analysisError = "Empty response from AI"
                return nil
            }

            return parseAnalysisResponse(text)
        } catch {
            analysisError = error.localizedDescription
            return nil
        }
    }

    // MARK: - Prompt Building

    private func buildTextPrompt(_ description: String) -> String {
        """
        Analyze this meal/food description and return a JSON object with nutritional estimates. \
        The user might describe food in any language (Chinese, English, etc). \
        Be practical and estimate realistic calorie counts.

        Description: "\(description)"

        Return ONLY a JSON object in this exact format, no other text:
        {
          "items": [
            {
              "name": "food item name in English",
              "calories": 350,
              "protein": 25,
              "carbs": 30,
              "fat": 12,
              "portion": "1 bowl"
            }
          ],
          "totalCalories": 350,
          "totalProtein": 25,
          "totalCarbs": 30,
          "totalFat": 12,
          "mealType": "lunch",
          "summary": "A brief one-line summary of the meal"
        }

        mealType must be one of: breakfast, lunch, dinner, snack.
        All nutritional values are in grams except calories (kcal).
        """
    }

    private func buildImagePrompt(_ context: String) -> String {
        """
        Look at this food image and analyze what's being eaten. \
        Estimate nutritional content based on typical portion sizes. \
        Additional context from user: "\(context)"

        Return ONLY a JSON object in this exact format, no other text:
        {
          "items": [
            {
              "name": "food item name in English",
              "calories": 350,
              "protein": 25,
              "carbs": 30,
              "fat": 12,
              "portion": "1 plate"
            }
          ],
          "totalCalories": 350,
          "totalProtein": 25,
          "totalCarbs": 30,
          "totalFat": 12,
          "mealType": "lunch",
          "summary": "A brief one-line summary of the meal"
        }

        mealType must be one of: breakfast, lunch, dinner, snack.
        All nutritional values are in grams except calories (kcal).
        """
    }

    // MARK: - Response Parsing

    private func parseAnalysisResponse(_ text: String) -> FoodAnalysisResult? {
        // Extract JSON from the response (handle markdown code blocks)
        var jsonString = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if jsonString.hasPrefix("```json") {
            jsonString = String(jsonString.dropFirst(7))
        } else if jsonString.hasPrefix("```") {
            jsonString = String(jsonString.dropFirst(3))
        }
        if jsonString.hasSuffix("```") {
            jsonString = String(jsonString.dropLast(3))
        }
        jsonString = jsonString.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let data = jsonString.data(using: .utf8) else {
            analysisError = "Failed to parse AI response"
            return nil
        }

        do {
            return try JSONDecoder().decode(FoodAnalysisResult.self, from: data)
        } catch {
            analysisError = "Failed to parse nutritional data"
            return nil
        }
    }

    // MARK: - Dispatcher Fallback

    private func sendThroughDispatcher(_ message: String) {
        NotificationCenter.default.post(
            name: .sendChatCommand,
            object: nil,
            userInfo: ["command": message]
        )
    }

    // MARK: - Storage Keys

    private enum StorageKeys {
        static let anthropicAPIKey = "ryanhub_anthropic_api_key"
    }
}

// MARK: - Analysis Result Model

struct FoodAnalysisResult: Codable {
    let items: [AnalyzedFoodItem]
    let totalCalories: Int
    let totalProtein: Int
    let totalCarbs: Int
    let totalFat: Int
    let mealType: String
    let summary: String
}

struct AnalyzedFoodItem: Codable, Identifiable {
    var id: String { name }
    let name: String
    let calories: Int
    let protein: Int
    let carbs: Int
    let fat: Int
    let portion: String?
}

// MARK: - Anthropic API Types

private struct APIRequestBody: Encodable {
    let model: String
    let maxTokens: Int
    let messages: [APIMessage]

    enum CodingKeys: String, CodingKey {
        case model
        case maxTokens = "max_tokens"
        case messages
    }
}

struct APIMessage: Encodable {
    let role: String
    let content: [APIContent]
}

enum APIContent: Encodable {
    case text(String)
    case image(mediaType: String, data: String)

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .text(let text):
            try container.encode(TextContent(type: "text", text: text))
        case .image(let mediaType, let data):
            try container.encode(ImageContent(
                type: "image",
                source: ImageSource(type: "base64", mediaType: mediaType, data: data)
            ))
        }
    }

    private struct TextContent: Encodable {
        let type: String
        let text: String
    }

    private struct ImageContent: Encodable {
        let type: String
        let source: ImageSource
    }

    private struct ImageSource: Encodable {
        let type: String
        let mediaType: String
        let data: String

        enum CodingKeys: String, CodingKey {
            case type
            case mediaType = "media_type"
            case data
        }
    }
}

private struct APIResponse: Decodable {
    let content: [ResponseContent]

    struct ResponseContent: Decodable {
        let type: String
        let text: String?
    }
}
