import Foundation
import UIKit

// MARK: - Food Analysis Service

/// Analyzes food from natural language descriptions or images via a local bridge server
/// that shells out to the `claude` CLI. No API key required -- uses the host Mac's
/// Claude Code subscription.
///
/// The bridge server runs at `http://localhost:18790` by default (see `scripts/food-analysis-server.py`).
/// The base URL is configurable via `AppState.foodAnalysisURL` to support connections
/// from real devices on the local network.
@MainActor @Observable
final class FoodAnalysisService {
    var isAnalyzing = false
    var analysisError: String?

    /// Base URL for the food analysis bridge server.
    /// Configurable so it works over local network (e.g. http://192.168.1.100:18790).
    private var bridgeBaseURL: String

    init(baseURL: String = AppState.defaultFoodAnalysisURL) {
        self.bridgeBaseURL = baseURL
    }

    /// Update the bridge server base URL (call when AppState changes).
    func updateBaseURL(_ url: String) {
        bridgeBaseURL = url
    }

    /// Analyze food from a text description.
    func analyzeText(_ description: String) async -> FoodAnalysisResult? {
        isAnalyzing = true
        analysisError = nil
        defer { isAnalyzing = false }

        let body: [String: Any] = ["text": description]
        return await callBridgeServer(body: body)
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
        var body: [String: Any] = ["image_base64": base64]
        if let context, !context.isEmpty {
            body["text"] = context
        }

        return await callBridgeServer(body: body)
    }

    // MARK: - Bridge Server Communication

    private func callBridgeServer(body: [String: Any]) async -> FoodAnalysisResult? {
        guard let url = URL(string: "\(bridgeBaseURL)/analyze") else {
            analysisError = "Invalid bridge server URL: \(bridgeBaseURL)"
            return nil
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 90 // claude CLI can take a while

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let http = response as? HTTPURLResponse else {
                analysisError = "Invalid response from analysis server"
                return nil
            }

            guard http.statusCode == 200 else {
                // Try to extract error message from response
                if let errorResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let errorMsg = errorResponse["error"] as? String {
                    analysisError = errorMsg
                } else {
                    analysisError = "Analysis server error (\(http.statusCode))"
                }
                return nil
            }

            return try JSONDecoder().decode(FoodAnalysisResult.self, from: data)
        } catch let error as URLError where error.code == .cannotConnectToHost
            || error.code == .networkConnectionLost
            || error.code == .timedOut
        {
            let host = URL(string: bridgeBaseURL)?.host ?? "unknown"
            let port = URL(string: bridgeBaseURL)?.port.map { String($0) } ?? "18790"
            analysisError = "Cannot reach analysis server at \(host):\(port). Make sure food-analysis-server.py is running."
            return nil
        } catch is DecodingError {
            analysisError = "Failed to parse nutritional data from analysis"
            return nil
        } catch {
            analysisError = error.localizedDescription
            return nil
        }
    }

    /// Analyze a physical activity from a text description.
    func analyzeActivity(_ description: String) async -> ActivityAnalysisResult? {
        isAnalyzing = true
        analysisError = nil
        defer { isAnalyzing = false }

        guard let url = URL(string: "\(bridgeBaseURL)/analyze-activity") else {
            analysisError = "Invalid bridge server URL: \(bridgeBaseURL)"
            return nil
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 90

        let body: [String: Any] = ["text": description]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let http = response as? HTTPURLResponse else {
                analysisError = "Invalid response from analysis server"
                return nil
            }

            guard http.statusCode == 200 else {
                if let errorResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let errorMsg = errorResponse["error"] as? String {
                    analysisError = errorMsg
                } else {
                    analysisError = "Analysis server error (\(http.statusCode))"
                }
                return nil
            }

            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            return try decoder.decode(ActivityAnalysisResult.self, from: data)
        } catch let error as URLError where error.code == .cannotConnectToHost
            || error.code == .networkConnectionLost
            || error.code == .timedOut
        {
            let host = URL(string: bridgeBaseURL)?.host ?? "unknown"
            let port = URL(string: bridgeBaseURL)?.port.map { String($0) } ?? "18790"
            analysisError = "Cannot reach analysis server at \(host):\(port). Make sure food-analysis-server.py is running."
            return nil
        } catch is DecodingError {
            analysisError = "Failed to parse activity analysis result"
            return nil
        } catch {
            analysisError = error.localizedDescription
            return nil
        }
    }

    /// Check if the bridge server is reachable.
    func checkServerHealth() async -> Bool {
        guard let url = URL(string: "\(bridgeBaseURL)/health") else { return false }
        var request = URLRequest(url: url)
        request.timeoutInterval = 5

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
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

// MARK: - Activity Analysis Result Model

struct ActivityAnalysisResult: Codable {
    let type: String
    let caloriesBurned: Int
    let summary: String
}
