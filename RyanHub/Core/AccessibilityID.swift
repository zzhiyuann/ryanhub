import Foundation

/// Centralized accessibility identifiers for UI testing.
/// Every interactive element must have an identifier from this enum.
enum AccessibilityID {

    // MARK: - Tab Bar

    static let tabChat = "tab_chat"
    static let tabToolkit = "tab_toolkit"
    static let tabSettings = "tab_settings"

    // MARK: - Chat Mode Toggle

    static let modeChatButton = "mode_chat"
    static let modeTerminalButton = "mode_terminal"

    // MARK: - Chat

    static let chatInputField = "chat_input_field"
    static let chatSendButton = "chat_send_button"
    static let chatMicButton = "chat_mic_button"
    static let chatAttachButton = "chat_attach_button"
    static let chatEmptyState = "chat_empty_state"
    static let chatMessagesArea = "chat_messages_area"
    static let chatRetryButton = "chat_retry_button"
    static let chatRecordingCancelButton = "chat_recording_cancel"
    static let chatRecordingStopButton = "chat_recording_stop"
    static let chatPendingImagePreview = "chat_pending_image_preview"
    static let chatClearImageButton = "chat_clear_image_button"
    static let chatQuestionCard = "chat_question_card"
    static let chatQuestionDismiss = "chat_question_dismiss"
    static let chatQuestionFreeInput = "chat_question_free_input"
    static let chatQuestionFreeSubmit = "chat_question_free_submit"
    static let chatReplyBar = "chat_reply_bar"
    static let chatReplyDismiss = "chat_reply_dismiss"

    // MARK: - Terminal

    static let terminalSessionBar = "terminal_session_bar"
    static let terminalConnectButton = "terminal_connect_button"
    static let terminalSessionPicker = "terminal_session_picker"
    static let terminalNewSession = "terminal_new_session"

    // MARK: - Toolkit

    static let toolkitHomeGrid = "toolkit_home_grid"
    static let toolkitMenuBar = "toolkit_menu_bar"
    static let toolkitMenuHome = "toolkit_menu_home"
    static let toolkitDesktopGrid = "toolkit_desktop_grid"

    static func toolkitCard(_ plugin: String) -> String {
        "toolkit_card_\(plugin)"
    }
    static func toolkitMenuItem(_ plugin: String) -> String {
        "toolkit_menu_\(plugin)"
    }

    // MARK: - Book Factory

    static let bookFactoryServerSetup = "bookfactory_server_setup"
    static let bookFactoryServerURL = "bookfactory_server_url"
    static let bookFactoryUsername = "bookfactory_username"
    static let bookFactoryPassword = "bookfactory_password"
    static let bookFactoryConnectButton = "bookfactory_connect_button"
    static let bookFactoryTabLibrary = "bookfactory_tab_library"
    static let bookFactoryTabQueue = "bookfactory_tab_queue"
    static let bookFactoryTabSettings = "bookfactory_tab_settings"
    static let bookFactoryMiniPlayer = "bookfactory_mini_player"

    // MARK: - Fluent

    static let fluentTabDashboard = "fluent_tab_dashboard"
    static let fluentTabVocabulary = "fluent_tab_vocabulary"
    static let fluentTabReview = "fluent_tab_review"
    static let fluentTabSettings = "fluent_tab_settings"
    static let fluentDailyGoalCard = "fluent_daily_goal_card"
    static let fluentStartReview = "fluent_start_review"
    static let fluentWordOfDay = "fluent_word_of_day"
    static let fluentSpeakButton = "fluent_speak_button"
    static let fluentBrowseWords = "fluent_browse_words"
    static let fluentReviewCards = "fluent_review_cards"

    // MARK: - Parking

    static let parkingTodayStatus = "parking_today_status"
    static let parkingCalendar = "parking_calendar"
    static let parkingPrevMonth = "parking_prev_month"
    static let parkingNextMonth = "parking_next_month"
    static let parkingMonthLabel = "parking_month_label"
    static let parkingConfirmation = "parking_confirmation"

    // MARK: - Calendar

    static let calendarEmptyState = "calendar_empty_state"
    static let calendarSyncButton = "calendar_sync_button"
    static let calendarRefreshButton = "calendar_refresh_button"
    static let calendarCountdown = "calendar_countdown"
    static let calendarWeekOverview = "calendar_week_overview"
    static let calendarTodaySection = "calendar_today_section"
    static let calendarTomorrowSection = "calendar_tomorrow_section"
    static let calendarThisWeekSection = "calendar_this_week_section"

    // MARK: - Health

    static let healthTabWeight = "health_tab_weight"
    static let healthTabFood = "health_tab_food"
    static let healthTabActivity = "health_tab_activity"
    static let healthLogWeightButton = "health_log_weight_button"
    static let healthCurrentWeight = "health_current_weight"
    static let healthQuickMealInput = "health_quick_meal_input"
    static let healthQuickMealSubmit = "health_quick_meal_submit"
    static let healthPhotoButton = "health_photo_button"
    static let healthCameraButton = "health_camera_button"
    static let healthQuickActivityInput = "health_quick_activity_input"
    static let healthQuickActivitySubmit = "health_quick_activity_submit"
    static let healthStructuredLogButton = "health_structured_log_button"
    static let healthTodayActivity = "health_today_activity"

    // MARK: - Settings

    static let settingsServerURL = "settings_server_url"
    static let settingsTestConnection = "settings_test_connection"
    static let settingsLocalhostPreset = "settings_localhost_preset"
    static let settingsResetPreset = "settings_reset_preset"
    static let settingsSSHHost = "settings_ssh_host"
    static let settingsSSHUsername = "settings_ssh_username"
    static let settingsSSHPassword = "settings_ssh_password"
    static let settingsTestSSH = "settings_test_ssh"
    static let settingsAppearanceSystem = "settings_appearance_system"
    static let settingsAppearanceDark = "settings_appearance_dark"
    static let settingsAppearanceLight = "settings_appearance_light"
    static let settingsLanguageEN = "settings_language_en"
    static let settingsLanguageZH = "settings_language_zh"
    static let settingsVersion = "settings_version"
    static let settingsBuild = "settings_build"
}
