import SwiftUI

/// Settings view for the Book Factory module — server config, generation settings, API keys.
struct BookFactorySettingsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(BookFactoryAPI.self) private var api

    @State private var showServerConfig = false
    @State private var showOpenAIKeySheet = false
    @State private var showAnthropicKeySheet = false
    @State private var booksPerDay: Int = 8
    @State private var isLoadingSettings = true
    @State private var hasOpenaiKey = false
    @State private var hasAnthropicKey = false

    var body: some View {
        NavigationStack {
            List {
                // Server section
                Section {
                    HStack {
                        Text("Server")
                            .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                        Spacer()
                        Text(api.baseURL.isEmpty ? "Not configured" : api.baseURL)
                            .font(.hubCaption)
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                            .lineLimit(1)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { showServerConfig = true }
                } header: {
                    Text("CONNECTION")
                        .font(.hubCaption)
                        .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                }

                // Generation section
                Section {
                    Stepper(
                        "Books per day: \(booksPerDay)",
                        value: $booksPerDay,
                        in: 1...20
                    )
                    .onChange(of: booksPerDay) { _, newValue in
                        Task { await saveSetting(key: "books_per_day", value: newValue) }
                    }
                } header: {
                    Text("GENERATION")
                        .font(.hubCaption)
                        .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                }

                // API Keys section
                Section {
                    Button {
                        showOpenAIKeySheet = true
                    } label: {
                        HStack {
                            Text("OpenAI")
                                .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                            Spacer()
                            Image(systemName: hasOpenaiKey ? "checkmark.circle.fill" : "xmark.circle")
                                .foregroundStyle(hasOpenaiKey ? Color.hubAccentGreen : Color.hubAccentRed)
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                        }
                    }

                    Button {
                        showAnthropicKeySheet = true
                    } label: {
                        HStack {
                            Text("Anthropic")
                                .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                            Spacer()
                            Image(systemName: hasAnthropicKey ? "checkmark.circle.fill" : "xmark.circle")
                                .foregroundStyle(hasAnthropicKey ? Color.hubAccentGreen : Color.hubAccentRed)
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                        }
                    }
                } header: {
                    Text("API KEYS")
                        .font(.hubCaption)
                        .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                }

                // Disconnect section
                Section {
                    Button(role: .destructive) {
                        api.authToken = nil
                        api.baseURL = ""
                    } label: {
                        Text("Disconnect Server")
                            .foregroundStyle(Color.hubAccentRed)
                    }
                }
            }
            .navigationTitle("Settings")
            .task { await loadSettings() }
            .sheet(isPresented: $showServerConfig) {
                BookFactoryServerConfigSheet(api: api)
            }
            .sheet(isPresented: $showOpenAIKeySheet) {
                BookFactoryAPIKeySheet(
                    title: "OpenAI API Key",
                    keyName: "openai_api_key",
                    api: api,
                    onSaved: { Task { await loadSettings() } }
                )
            }
            .sheet(isPresented: $showAnthropicKeySheet) {
                BookFactoryAPIKeySheet(
                    title: "Anthropic API Key",
                    keyName: "anthropic_api_key",
                    api: api,
                    onSaved: { Task { await loadSettings() } }
                )
            }
        }
    }

    // MARK: - Data Loading

    private func loadSettings() async {
        do {
            let response: SettingsAPIResponse = try await api.get("/api/settings")
            booksPerDay = response.settings.booksPerDay ?? 8
            hasOpenaiKey = response.apiKeys.hasOpenaiKey
            hasAnthropicKey = response.apiKeys.hasAnthropicKey
        } catch {
            // use defaults
        }
        isLoadingSettings = false
    }

    private func saveSetting(key: String, value: Int) async {
        do {
            let body: [String: Int] = [key: value]
            let _: [String: Bool] = try await api.put("/api/settings", body: body)
        } catch {
            // ignore
        }
    }
}

// MARK: - Settings API Response

private struct SettingsAPIResponse: Codable {
    let settings: SettingsData
    let apiKeys: APIKeysData

    struct SettingsData: Codable {
        let booksPerDay: Int?
        let ttsVoice: String?
        let ttsModel: String?

        enum CodingKeys: String, CodingKey {
            case booksPerDay = "books_per_day"
            case ttsVoice = "tts_voice"
            case ttsModel = "tts_model"
        }
    }

    struct APIKeysData: Codable {
        let hasOpenaiKey: Bool
        let hasAnthropicKey: Bool

        enum CodingKeys: String, CodingKey {
            case hasOpenaiKey = "has_openai_key"
            case hasAnthropicKey = "has_anthropic_key"
        }
    }

    enum CodingKeys: String, CodingKey {
        case settings
        case apiKeys = "api_keys"
    }
}

// MARK: - Server Config Sheet

struct BookFactoryServerConfigSheet: View {
    let api: BookFactoryAPI

    @Environment(\.dismiss) private var dismiss
    @State private var urlText = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("e.g. 192.168.1.100:3443", text: $urlText)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                } header: {
                    Text("Server Address")
                } footer: {
                    Text("Enter the IP address and port of your Book Factory server. Uses HTTPS (port 3443 by default).")
                }
            }
            .navigationTitle("Server")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        api.saveServerURL(urlText)
                        dismiss()
                    }
                    .tint(.hubPrimary)
                    .disabled(urlText.isEmpty)
                }
            }
            .onAppear {
                urlText = api.baseURL
                    .replacingOccurrences(of: "https://", with: "")
                    .replacingOccurrences(of: "http://", with: "")
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - API Key Sheet

struct BookFactoryAPIKeySheet: View {
    let title: String
    let keyName: String
    let api: BookFactoryAPI
    let onSaved: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var apiKey = ""
    @State private var isSaving = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("Paste API key here", text: $apiKey)
                        .textContentType(.password)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                } footer: {
                    Text("Leave empty and save to remove the key.")
                        .font(.caption)
                }

                if let error {
                    Section {
                        Text(error)
                            .foregroundStyle(Color.hubAccentRed)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await saveKey() }
                    }
                    .tint(.hubPrimary)
                    .disabled(isSaving)
                }
            }
        }
    }

    private func saveKey() async {
        isSaving = true
        error = nil
        do {
            let body: [String: String] = [keyName: apiKey]
            let _: [String: Bool] = try await api.put("/api/settings", body: body)
            onSaved()
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
        isSaving = false
    }
}
