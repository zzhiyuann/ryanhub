import SwiftUI

/// Global observable application state shared across all modules.
@Observable
final class AppState {
    // MARK: - Server Configuration

    var serverURL: String {
        didSet { UserDefaults.standard.set(serverURL, forKey: Keys.serverURL) }
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

    // MARK: - Connection State

    var isConnected: Bool = false

    // MARK: - Init

    init() {
        self.serverURL = UserDefaults.standard.string(forKey: Keys.serverURL) ?? "ws://localhost:8765"
        let rawAppearance = UserDefaults.standard.string(forKey: Keys.appearanceMode) ?? AppearanceMode.system.rawValue
        self.appearanceMode = AppearanceMode(rawValue: rawAppearance) ?? .system
        let rawLanguage = UserDefaults.standard.string(forKey: Keys.language) ?? AppLanguage.english.rawValue
        self.language = AppLanguage(rawValue: rawLanguage) ?? .english
    }

    // MARK: - Keys

    private enum Keys {
        static let serverURL = "cortex_server_url"
        static let appearanceMode = "cortex_appearance_mode"
        static let language = "cortex_language"
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
