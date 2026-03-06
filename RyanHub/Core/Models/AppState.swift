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
            if !isCustomCalendarSyncURL {
                calendarSyncURL = Self.deriveCalendarSyncURL(from: serverURL)
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

    /// Base URL for the calendar sync bridge server.
    /// Defaults to the same host as the WebSocket server on port 18791.
    var calendarSyncURL: String {
        didSet { UserDefaults.standard.set(calendarSyncURL, forKey: Keys.calendarSyncURL) }
    }

    /// Whether the user has manually customized the calendar sync URL.
    var isCustomCalendarSyncURL: Bool {
        didSet { UserDefaults.standard.set(isCustomCalendarSyncURL, forKey: Keys.isCustomCalendarSyncURL) }
    }

    /// Default WebSocket server URL.
    static let defaultServerURL = "ws://100.89.67.80:8765"

    /// Default food analysis bridge URL.
    static let defaultFoodAnalysisURL = "http://100.89.67.80:18790"

    /// Default calendar sync bridge URL.
    static let defaultCalendarSyncURL = "http://100.89.67.80:18791"

    /// Derive the food analysis URL from the WebSocket server URL.
    /// Extracts the host from the WS URL and uses port 18790 with http://.
    static func deriveFoodAnalysisURL(from serverURL: String) -> String {
        guard let url = URL(string: serverURL), let host = url.host else {
            return defaultFoodAnalysisURL
        }
        return "http://\(host):18790"
    }

    /// Derive the calendar sync URL from the WebSocket server URL.
    /// Extracts the host from the WS URL and uses port 18791 with http://.
    static func deriveCalendarSyncURL(from serverURL: String) -> String {
        guard let url = URL(string: serverURL), let host = url.host else {
            return defaultCalendarSyncURL
        }
        return "http://\(host):18791"
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

    /// Incremented to signal ToolkitHomeView to return to the desktop grid.
    var toolkitHomeSignal: Int = 0

    /// True when the user is reading a book (inside BookReaderView).
    /// Used to hide the floating module tab bubble.
    var isReadingBook: Bool = false

    /// Pending deep link from a notification tap. ContentView observes this
    /// to perform navigation, then sets it back to nil once handled.
    var pendingDeepLink: DeepLink?

    /// Whether the app is currently in the foreground (active scene phase).
    /// Used by ChatViewModel to decide whether to fire local notifications.
    var isAppInForeground: Bool = true

    /// Whether RB Meta glasses are connected (updated by RBMetaViewModel).
    var rbMetaConnected: Bool = false

    /// Whether an RB Meta camera stream is actively running (fullscreen mode).
    var rbMetaStreaming: Bool = false

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
        self.isCustomCalendarSyncURL = UserDefaults.standard.bool(forKey: Keys.isCustomCalendarSyncURL)
        self.calendarSyncURL = UserDefaults.standard.string(forKey: Keys.calendarSyncURL)
            ?? Self.deriveCalendarSyncURL(from: savedServerURL)
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
        calendarSyncURL = Self.defaultCalendarSyncURL
        isCustomCalendarSyncURL = false
    }

    // MARK: - Keys

    private enum Keys {
        static let serverURL = "ryanhub_server_url"
        static let foodAnalysisURL = "ryanhub_food_analysis_url"
        static let isCustomFoodAnalysisURL = "ryanhub_is_custom_food_analysis_url"
        static let calendarSyncURL = "ryanhub_calendar_sync_url"
        static let isCustomCalendarSyncURL = "ryanhub_is_custom_calendar_sync_url"
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

}
