import Foundation

/// Centralized localization key access.
/// All user-facing strings are defined here, backed by Localizable.strings bundles.
enum L10n {
    // MARK: - Tabs

    static var tabChat: String { localized("tab_chat") }
    static var tabToolkit: String { localized("tab_toolkit") }
    static var tabSettings: String { localized("tab_settings") }

    // MARK: - Chat

    static var chatSend: String { localized("chat_send") }
    static var chatPlaceholder: String { localized("chat_placeholder") }
    static var chatConnected: String { localized("chat_connected") }
    static var chatDisconnected: String { localized("chat_disconnected") }
    static var chatReconnecting: String { localized("chat_reconnecting") }
    static var chatWelcomeTitle: String { localized("chat_welcome_title") }
    static var chatWelcomeMessage: String { localized("chat_welcome_message") }

    // MARK: - Toolkit

    static var toolkitTitle: String { localized("toolkit_title") }
    static var toolkitBookFactory: String { localized("toolkit_book_factory") }
    static var toolkitBookFactoryDesc: String { localized("toolkit_book_factory_desc") }
    static var toolkitFluent: String { localized("toolkit_fluent") }
    static var toolkitFluentDesc: String { localized("toolkit_fluent_desc") }
    static var toolkitParking: String { localized("toolkit_parking") }
    static var toolkitParkingDesc: String { localized("toolkit_parking_desc") }
    static var toolkitCalendar: String { localized("toolkit_calendar") }
    static var toolkitCalendarDesc: String { localized("toolkit_calendar_desc") }
    static var toolkitHealth: String { localized("toolkit_health") }
    static var toolkitHealthDesc: String { localized("toolkit_health_desc") }
    static var toolkitBobo: String { localized("toolkit_bobo") }
    static var toolkitBoboDesc: String { localized("toolkit_bobo_desc") }
    static var toolkitRBMeta: String { localized("toolkit_rb_meta") }
    static var toolkitRBMetaDesc: String { localized("toolkit_rb_meta_desc") }

    // MARK: - Settings

    static var settingsTitle: String { localized("settings_title") }
    static var settingsServer: String { localized("settings_server") }
    static var settingsServerURL: String { localized("settings_server_url") }
    static var settingsTestConnection: String { localized("settings_test_connection") }
    static var settingsLanguage: String { localized("settings_language") }
    static var settingsAppearance: String { localized("settings_appearance") }
    static var settingsAppearanceSystem: String { localized("settings_appearance_system") }
    static var settingsAppearanceLight: String { localized("settings_appearance_light") }
    static var settingsAppearanceDark: String { localized("settings_appearance_dark") }
    static var settingsResetToDefault: String { localized("settings_reset_to_default") }
    static var settingsAbout: String { localized("settings_about") }
    static var settingsVersion: String { localized("settings_version") }
    static var settingsBuild: String { localized("settings_build") }

    // MARK: - Common

    static var commonCancel: String { localized("common_cancel") }
    static var commonDone: String { localized("common_done") }
    static var commonSave: String { localized("common_save") }
    static var commonDelete: String { localized("common_delete") }
    static var commonError: String { localized("common_error") }
    static var commonSuccess: String { localized("common_success") }

    // MARK: - Private

    private static func localized(_ key: String) -> String {
        NSLocalizedString(key, comment: "")
    }
}
