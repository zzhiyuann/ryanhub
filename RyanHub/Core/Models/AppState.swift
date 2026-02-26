import SwiftUI

/// Global observable application state shared across all modules.
@Observable
final class AppState {
    // MARK: - Server Configuration

    var serverURL: String {
        didSet {
            UserDefaults.standard.set(serverURL, forKey: Keys.serverURL)
            // Auto-update food analysis URL when server host changes (unless user overrode it)
            if !isCustomFoodAnalysisURL {
                foodAnalysisURL = Self.deriveFoodAnalysisURL(from: serverURL)
            }
        }
    }

    /// Base URL for the food analysis bridge server.
    /// Defaults to the same host as the WebSocket server on port 18790.
    var foodAnalysisURL: String {
        didSet { UserDefaults.standard.set(foodAnalysisURL, forKey: Keys.foodAnalysisURL) }
    }

    /// Whether the user has manually customized the food analysis URL.
    var isCustomFoodAnalysisURL: Bool {
        didSet { UserDefaults.standard.set(isCustomFoodAnalysisURL, forKey: Keys.isCustomFoodAnalysisURL) }
    }

    /// Default WebSocket server URL.
    static let defaultServerURL = "ws://localhost:8765"

    /// Default food analysis bridge URL.
    static let defaultFoodAnalysisURL = "http://localhost:18790"

    /// Derive the food analysis URL from the WebSocket server URL.
    /// Extracts the host from the WS URL and uses port 18790 with http://.
    static func deriveFoodAnalysisURL(from serverURL: String) -> String {
        guard let url = URL(string: serverURL), let host = url.host else {
            return defaultFoodAnalysisURL
        }
        return "http://\(host):18790"
    }

    // MARK: - Appearance

    var appearanceMode: AppearanceMode {
        didSet { UserDefaults.standard.set(appearanceMode.rawValue, forKey: Keys.appearanceMode) }
    }

    var resolvedColorScheme: ColorScheme? {
        switch appearanceMode {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    // MARK: - Language

    var language: AppLanguage {
        didSet { UserDefaults.standard.set(language.rawValue, forKey: Keys.language) }
    }

    // MARK: - Navigation State

    /// True when the user is inside a toolkit module (selectedPlugin != nil).
    /// Used by the custom tab bar to switch to compact (icon-only) mode.
    var isInToolkitModule: Bool = false

    /// True when the user is reading a book (inside BookReaderView).
    /// Used to hide the floating module tab bubble.
    var isReadingBook: Bool = false

    // MARK: - Connection State

    var isConnected: Bool = false
    var connectionState: WebSocketClient.ConnectionState = .disconnected
    var connectionError: String?

    // MARK: - Init

    init() {
        let savedServerURL = UserDefaults.standard.string(forKey: Keys.serverURL) ?? Self.defaultServerURL
        self.serverURL = savedServerURL
        self.isCustomFoodAnalysisURL = UserDefaults.standard.bool(forKey: Keys.isCustomFoodAnalysisURL)
        self.foodAnalysisURL = UserDefaults.standard.string(forKey: Keys.foodAnalysisURL)
            ?? Self.deriveFoodAnalysisURL(from: savedServerURL)
        let rawAppearance = UserDefaults.standard.string(forKey: Keys.appearanceMode) ?? AppearanceMode.system.rawValue
        self.appearanceMode = AppearanceMode(rawValue: rawAppearance) ?? .system
        let rawLanguage = UserDefaults.standard.string(forKey: Keys.language) ?? AppLanguage.english.rawValue
        self.language = AppLanguage(rawValue: rawLanguage) ?? .english
    }

    /// Reset all server URLs to defaults.
    func resetServerURLs() {
        serverURL = Self.defaultServerURL
        foodAnalysisURL = Self.defaultFoodAnalysisURL
        isCustomFoodAnalysisURL = false
    }

    // MARK: - Keys

    private enum Keys {
        static let serverURL = "ryanhub_server_url"
        static let foodAnalysisURL = "ryanhub_food_analysis_url"
        static let isCustomFoodAnalysisURL = "ryanhub_is_custom_food_analysis_url"
        static let appearanceMode = "ryanhub_appearance_mode"
        static let language = "ryanhub_language"
    }
}

// MARK: - Enums

enum AppearanceMode: String, CaseIterable {
    case system
    case light
    case dark

    var displayName: String {
        switch self {
        case .system: return L10n.settingsAppearanceSystem
        case .light: return L10n.settingsAppearanceLight
        case .dark: return L10n.settingsAppearanceDark
        }
    }
}

enum AppLanguage: String, CaseIterable {
    case english = "en"
    case chinese = "zh-Hans"

    var displayName: String {
        switch self {
        case .english: return "English"
        case .chinese: return "中文"
        }
    }

    /// Instruction prefix to prepend to outgoing chat messages so the AI
    /// responds in the user's chosen language.
    var responseLanguageInstruction: String {
        switch self {
        case .english: return "[System: Respond in English]"
        case .chinese: return "[System: 请用中文回复]"
        }
    }
}
