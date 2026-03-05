import Foundation

/// Configuration for the RB Meta module (Gemini Live + OpenClaw + glasses).
enum RBMetaConfig {
    static let websocketBaseURL = "wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1beta.GenerativeService.BidiGenerateContent"
    static let model = "models/gemini-2.5-flash-native-audio-preview-12-2025"

    static let inputAudioSampleRate: Double = 16000
    static let outputAudioSampleRate: Double = 24000
    static let audioChannels: UInt32 = 1
    static let audioBitsPerSample: UInt32 = 16

    static let videoFrameInterval: TimeInterval = 1.0
    static let videoJPEGQuality: CGFloat = 0.5

    // MARK: - User-configurable (UserDefaults with hardcoded fallbacks)

    private static let defaults = UserDefaults.standard

    static var apiKey: String {
        get { defaults.string(forKey: "rbmeta_gemini_api_key") ?? "AIzaSyC-RSUQ850rvDvfXyDIHPGLJBG8M7U1XwQ" }
        set { defaults.set(newValue, forKey: "rbmeta_gemini_api_key") }
    }

    static var systemInstruction: String {
        get { defaults.string(forKey: "rbmeta_system_prompt") ?? defaultSystemInstruction }
        set { defaults.set(newValue, forKey: "rbmeta_system_prompt") }
    }

    static var openClawHost: String {
        get { defaults.string(forKey: "rbmeta_openclaw_host") ?? "http://Zhiyuans-iMac.local" }
        set { defaults.set(newValue, forKey: "rbmeta_openclaw_host") }
    }

    static var openClawPort: Int {
        get {
            let stored = defaults.integer(forKey: "rbmeta_openclaw_port")
            return stored != 0 ? stored : 18789
        }
        set { defaults.set(newValue, forKey: "rbmeta_openclaw_port") }
    }

    static var openClawGatewayToken: String {
        get { defaults.string(forKey: "rbmeta_openclaw_token") ?? "ba8a846646ffb98a9de0b671b9bec6bf2ece7229142f0a88" }
        set { defaults.set(newValue, forKey: "rbmeta_openclaw_token") }
    }

    static func websocketURL() -> URL? {
        guard !apiKey.isEmpty else { return nil }
        return URL(string: "\(websocketBaseURL)?key=\(apiKey)")
    }

    static var isConfigured: Bool {
        !apiKey.isEmpty
    }

    static var isOpenClawConfigured: Bool {
        !openClawGatewayToken.isEmpty && !openClawHost.isEmpty
    }

    static let defaultSystemInstruction = """
        You are an AI assistant for someone wearing Meta Ray-Ban smart glasses. You can see through their camera and have a voice conversation. Keep responses concise and natural.

        CRITICAL: You have NO memory, NO storage, and NO ability to take actions on your own. You cannot remember things, keep lists, set reminders, search the web, send messages, or do anything persistent. You are ONLY a voice interface.

        You have exactly ONE tool: execute. This connects you to a powerful personal assistant that can do anything -- send messages, search the web, manage lists, set reminders, create notes, research topics, control smart home devices, interact with apps, and much more.

        ALWAYS use execute when the user asks you to:
        - Send a message to someone (any platform: WhatsApp, Telegram, iMessage, Slack, etc.)
        - Search or look up anything (web, local info, facts, news)
        - Add, create, or modify anything (shopping lists, reminders, notes, todos, events)
        - Research, analyze, or draft anything
        - Control or interact with apps, devices, or services
        - Remember or store any information for later

        Be detailed in your task description. Include all relevant context: names, content, platforms, quantities, etc. The assistant works better with complete information.

        NEVER pretend to do these things yourself.

        IMPORTANT: Before calling execute, ALWAYS speak a brief acknowledgment first. For example:
        - "Sure, let me add that to your shopping list." then call execute.
        - "Got it, searching for that now." then call execute.
        - "On it, sending that message." then call execute.
        Never call execute silently -- the user needs verbal confirmation that you heard them and are working on it.

        For messages, confirm recipient and content before delegating unless clearly urgent.
        """
}
