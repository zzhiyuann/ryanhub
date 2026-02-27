import Foundation
import AVFoundation

// MARK: - Narration Recording State

/// Represents the current state of the narration recording flow.
enum NarrationRecordingState: Equatable {
    case idle
    case recording
    case uploading
    case done
    case error(String)
}

// MARK: - Timeline Item

/// A unified timeline item that wraps any type of POPO event for chronological display.
/// Enables rendering sensing events, narrations, and nudges in a single timeline.
enum TimelineItem: Identifiable {
    case sensing(SensingEvent)
    case narration(Narration)
    case nudge(Nudge)

    var id: UUID {
        switch self {
        case .sensing(let event): return event.id
        case .narration(let narration): return narration.id
        case .nudge(let nudge): return nudge.id
        }
    }

    var timestamp: Date {
        switch self {
        case .sensing(let event): return event.timestamp
        case .narration(let narration): return narration.timestamp
        case .nudge(let nudge): return nudge.timestamp
        }
    }
}

// MARK: - Today Summary

/// Aggregated statistics for the overview card.
struct DayOverviewSummary {
    var totalSteps: Int = 0
    var activityBreakdown: [String: Int] = [:]  // activity type -> count
    var locationChanges: Int = 0
    var screenEvents: Int = 0
    var narrationCount: Int = 0
    var nudgeCount: Int = 0
    var eventCount: Int = 0
}

// MARK: - POPO View Model

/// Main view model for the POPO (Proactive Personal Observer) sensing module.
/// Coordinates the sensing engine and exposes observable state for the UI.
@MainActor
@Observable
final class PopoViewModel {
    // MARK: - State

    /// The sensing engine that manages all sensors.
    let engine = SensingEngine()

    /// Whether sensing has been toggled on by the user.
    var sensingEnabled: Bool = false {
        didSet {
            if sensingEnabled {
                engine.startSensing()
            } else {
                engine.stopSensing()
            }
            // Persist the preference
            UserDefaults.standard.set(sensingEnabled, forKey: StorageKeys.sensingEnabled)
        }
    }

    /// The currently selected modality filter for the event list (nil = all).
    var selectedModality: SensingModality?

    /// The currently selected date for day navigation.
    var selectedDate: Date = Date()

    /// Set of expanded timeline item IDs (for tap-to-expand behavior).
    var expandedItemIDs: Set<UUID> = []

    /// Narrations loaded from local storage.
    var narrations: [Narration] = []

    /// Nudges loaded from local storage.
    var nudges: [Nudge] = []

    // MARK: - Narration Recording State

    /// Current state of the recording flow.
    private(set) var narrationState: NarrationRecordingState = .idle

    /// Duration of the current or last recording, in seconds.
    private(set) var narrationDuration: TimeInterval = 0

    /// Audio power levels for waveform visualization (0–1 normalized).
    private(set) var narrationAudioLevels: [CGFloat] = []

    /// Whether a narration is currently being recorded.
    var isRecordingNarration: Bool {
        narrationState == .recording
    }

    // MARK: - Private Recording Properties

    private var audioRecorder: AVAudioRecorder?
    private var recordingURL: URL?
    private var recordingTimer: Timer?
    private var recordingStartTime: Date?

    // MARK: - Date-Filtered Computed Properties

    /// Whether the selected date is today.
    var isSelectedDateToday: Bool {
        Calendar.current.isDateInToday(selectedDate)
    }

    /// Sensing events for the selected date, sorted newest first.
    var eventsForSelectedDate: [SensingEvent] {
        let calendar = Calendar.current
        return engine.recentEvents
            .filter { calendar.isDate($0.timestamp, inSameDayAs: selectedDate) }
            .sorted { $0.timestamp > $1.timestamp }
    }

    /// Narrations for the selected date, sorted newest first.
    var narrationsForSelectedDate: [Narration] {
        let calendar = Calendar.current
        return narrations
            .filter { calendar.isDate($0.timestamp, inSameDayAs: selectedDate) }
            .sorted { $0.timestamp > $1.timestamp }
    }

    /// Nudges for the selected date, sorted newest first.
    var nudgesForSelectedDate: [Nudge] {
        let calendar = Calendar.current
        return nudges
            .filter { calendar.isDate($0.timestamp, inSameDayAs: selectedDate) }
            .sorted { $0.timestamp > $1.timestamp }
    }

    /// All timeline items for the selected date, merged and sorted chronologically (newest first).
    var timelineItems: [TimelineItem] {
        var items: [TimelineItem] = []
        items.append(contentsOf: eventsForSelectedDate.map { .sensing($0) })
        items.append(contentsOf: narrationsForSelectedDate.map { .narration($0) })
        items.append(contentsOf: nudgesForSelectedDate.map { .nudge($0) })
        return items.sorted { $0.timestamp > $1.timestamp }
    }

    /// Aggregated overview summary for the selected date.
    var daySummary: DayOverviewSummary {
        let dayEvents = eventsForSelectedDate
        var summary = DayOverviewSummary()

        summary.eventCount = dayEvents.count
        summary.narrationCount = narrationsForSelectedDate.count
        summary.nudgeCount = nudgesForSelectedDate.count

        for event in dayEvents {
            switch event.modality {
            case .steps:
                if let steps = event.payload["steps"], let count = Int(steps) {
                    summary.totalSteps += count
                }
            case .motion:
                let activity = event.payload["activityType"] ?? "unknown"
                summary.activityBreakdown[activity, default: 0] += 1
            case .location:
                summary.locationChanges += 1
            case .screen:
                summary.screenEvents += 1
            default:
                break
            }
        }

        return summary
    }

    // MARK: - Computed Properties

    /// Events filtered by the selected modality, or all events if no filter.
    var filteredEvents: [SensingEvent] {
        if let modality = selectedModality {
            return engine.events(for: modality)
        }
        return engine.recentEvents
    }

    /// Formatted string for the last sync time.
    var lastSyncTimeString: String? {
        guard let syncTime = engine.lastSyncTime else { return nil }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: syncTime, relativeTo: Date())
    }

    // MARK: - Init

    init() {
        // Restore persisted preference
        let wasEnabled = UserDefaults.standard.bool(forKey: StorageKeys.sensingEnabled)
        if wasEnabled {
            sensingEnabled = true
            engine.startSensing()
        }

        // Load narrations and nudges from local storage
        loadNarrations()
        loadNudges()
    }

    // MARK: - Day Navigation

    /// Navigate to a day offset from the current selected date.
    func navigateDay(offset: Int) {
        guard let newDate = Calendar.current.date(byAdding: .day, value: offset, to: selectedDate) else { return }
        // Don't navigate past today
        if newDate <= Date() {
            selectedDate = newDate
        }
    }

    /// Jump back to today.
    func goToToday() {
        selectedDate = Date()
    }

    // MARK: - Expand/Collapse

    /// Toggle whether a timeline item is expanded.
    func toggleExpanded(_ id: UUID) {
        if expandedItemIDs.contains(id) {
            expandedItemIDs.remove(id)
        } else {
            expandedItemIDs.insert(id)
        }
    }

    /// Check if a timeline item is expanded.
    func isExpanded(_ id: UUID) -> Bool {
        expandedItemIDs.contains(id)
    }

    // MARK: - Sync State

    /// Whether a sync operation is currently in progress (mirrors engine state).
    var isSyncing: Bool {
        engine.isSyncing
    }

    /// Error from the last sync attempt, if any.
    var lastSyncError: String? {
        engine.lastSyncError
    }

    // MARK: - Actions

    /// Force an immediate sync of pending events.
    func syncNow() async {
        await engine.syncPendingEvents()
    }

    // MARK: - Narration Recording

    /// Start recording a voice narration diary entry.
    func startNarration() {
        guard narrationState == .idle || narrationState == .done || isNarrationError else {
            return
        }

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default)
            try session.setActive(true)
        } catch {
            narrationState = .error("Microphone access denied")
            return
        }

        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "narration_\(UUID().uuidString).m4a"
        let url = tempDir.appendingPathComponent(fileName)
        recordingURL = url

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.record()
            narrationState = .recording
            recordingStartTime = Date()
            narrationDuration = 0
            narrationAudioLevels = []

            // Sample audio levels at ~30fps and update duration
            let timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
                guard let self, let start = self.recordingStartTime else { return }
                self.narrationDuration = Date().timeIntervalSince(start)

                self.audioRecorder?.updateMeters()
                let power = self.audioRecorder?.averagePower(forChannel: 0) ?? -160
                let clampedPower = max(power, -50)
                let normalized = CGFloat((clampedPower + 50) / 50)
                self.narrationAudioLevels.append(normalized)
            }
            recordingTimer = timer
        } catch {
            narrationState = .error("Failed to start recording")
        }
    }

    /// Stop recording, upload audio, and create a narration entry.
    func stopNarration() {
        recordingTimer?.invalidate()
        recordingTimer = nil
        audioRecorder?.stop()

        guard narrationState == .recording else { return }

        guard let url = recordingURL,
              let data = try? Data(contentsOf: url) else {
            narrationState = .error("Failed to read recording")
            return
        }

        let duration = narrationDuration
        guard duration >= 1.0 else {
            // Too short, discard
            narrationState = .idle
            narrationDuration = 0
            narrationAudioLevels = []
            try? FileManager.default.removeItem(at: url)
            return
        }

        narrationState = .uploading

        let narrationId = UUID()

        Task {
            do {
                let filename = try await uploadNarrationAudio(data: data, narrationId: narrationId)

                // Create the narration entry (transcript filled later by server analysis)
                var narration = Narration(
                    id: narrationId,
                    timestamp: Date(),
                    transcript: "",
                    duration: duration,
                    audioFileRef: filename
                )

                // Save locally
                narrations.insert(narration, at: 0)
                saveNarrations()

                // Sync narration entry to server
                await syncNarrationToServer(narration)

                // Request server-side analysis (transcription + affect)
                if let analysis = await requestNarrationAnalysis(filename: filename, narrationId: narrationId) {
                    narration.transcript = analysis.transcript
                    narration.affectAnalysis = analysis.affect
                    narration.extractedMood = analysis.affect?.primaryEmotion

                    // Update the local entry
                    if let index = narrations.firstIndex(where: { $0.id == narrationId }) {
                        narrations[index] = narration
                        saveNarrations()
                    }

                    // Re-sync updated narration
                    await syncNarrationToServer(narration)
                }

                narrationState = .done

                // Auto-reset to idle after a short delay
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                if narrationState == .done {
                    narrationState = .idle
                    narrationDuration = 0
                    narrationAudioLevels = []
                }
            } catch {
                narrationState = .error("Upload failed: \(error.localizedDescription)")
            }

            // Clean up temp file
            try? FileManager.default.removeItem(at: url)
        }
    }

    /// Cancel an in-progress narration recording.
    func cancelNarration() {
        recordingTimer?.invalidate()
        recordingTimer = nil
        audioRecorder?.stop()
        narrationState = .idle
        narrationDuration = 0
        narrationAudioLevels = []

        if let url = recordingURL {
            try? FileManager.default.removeItem(at: url)
        }
    }

    // MARK: - Narration Networking

    /// Upload raw audio data to the bridge server. Returns the server-assigned filename.
    private func uploadNarrationAudio(data: Data, narrationId: UUID) async throws -> String {
        let endpoint = "\(Self.bridgeBaseURL)/popo/audio"
        guard let url = URL(string: endpoint) else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("audio/mp4", forHTTPHeaderField: "Content-Type")
        request.setValue("narration_\(narrationId.uuidString).m4a", forHTTPHeaderField: "X-Filename")
        request.setValue(narrationId.uuidString, forHTTPHeaderField: "X-Narration-Id")
        request.httpBody = data
        request.timeoutInterval = 60

        let (responseData, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw URLError(.badServerResponse, userInfo: [
                NSLocalizedDescriptionKey: "Server returned \(statusCode)"
            ])
        }

        let result = try JSONDecoder().decode(NarrationAudioUploadResponse.self, from: responseData)
        return result.filename
    }

    /// Sync a narration entry to the bridge server's /popo/narrations endpoint.
    private func syncNarrationToServer(_ narration: Narration) async {
        let endpoint = "\(Self.bridgeBaseURL)/popo/narrations"
        guard let url = URL(string: endpoint) else { return }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let body = try? encoder.encode([narration]) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        request.timeoutInterval = 30

        _ = try? await URLSession.shared.data(for: request)
    }

    /// Request the bridge server to transcribe and analyze a narration.
    private func requestNarrationAnalysis(
        filename: String,
        narrationId: UUID
    ) async -> NarrationAnalysisResult? {
        let endpoint = "\(Self.bridgeBaseURL)/popo/narrations/analyze"
        guard let url = URL(string: endpoint) else { return nil }

        let payload: [String: String] = [
            "filename": filename,
            "narration_id": narrationId.uuidString
        ]

        guard let body = try? JSONSerialization.data(withJSONObject: payload) else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        request.timeoutInterval = 120  // Transcription can take a while

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode) else {
                return nil
            }

            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let result = try decoder.decode(NarrationAnalysisResponse.self, from: data)

            return NarrationAnalysisResult(
                transcript: result.transcript ?? "",
                affect: result.affect
            )
        } catch {
            print("[PopoVM] Analysis request failed: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Helpers

    private var isNarrationError: Bool {
        if case .error = narrationState { return true }
        return false
    }

    /// Base URL for the bridge server.
    private static var bridgeBaseURL: String {
        UserDefaults.standard.string(forKey: "ryanhub_server_url")
            .flatMap { URL(string: $0)?.host }
            .map { "http://\($0):18790" }
            ?? AppState.defaultFoodAnalysisURL
    }

    // MARK: - Local Persistence

    private func loadNarrations() {
        guard let data = UserDefaults.standard.data(forKey: StorageKeys.narrations) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        narrations = (try? decoder.decode([Narration].self, from: data)) ?? []
    }

    private func saveNarrations() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(narrations) {
            UserDefaults.standard.set(data, forKey: StorageKeys.narrations)
        }
    }

    private func loadNudges() {
        guard let data = UserDefaults.standard.data(forKey: StorageKeys.nudges) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        nudges = (try? decoder.decode([Nudge].self, from: data)) ?? []
    }

    // MARK: - Storage Keys

    private enum StorageKeys {
        static let sensingEnabled = "ryanhub_popo_sensing_enabled"
        static let narrations = "ryanhub_popo_narrations"
        static let nudges = "ryanhub_popo_nudges"
    }
}

// MARK: - Narration Network Response Models

/// Response from the audio upload endpoint.
private struct NarrationAudioUploadResponse: Decodable {
    let ok: Bool
    let filename: String
    let size: Int
}

/// Response from the narration analysis endpoint.
private struct NarrationAnalysisResponse: Decodable {
    let transcript: String?
    let affect: AffectAnalysis?
}

/// Internal result combining transcript and affect analysis.
private struct NarrationAnalysisResult {
    let transcript: String
    let affect: AffectAnalysis?
}
