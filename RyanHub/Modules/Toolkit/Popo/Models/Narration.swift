import Foundation

// MARK: - Narration

/// A voice narration entry recorded by the user.
/// Contains the transcript, optional mood extraction, and a reference
/// to the audio file for playback.
struct Narration: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let transcript: String
    var duration: TimeInterval
    var extractedMood: String?
    var extractedEvents: [String]?
    var audioFileRef: String?  // Filename for audio playback

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        transcript: String,
        duration: TimeInterval,
        extractedMood: String? = nil,
        extractedEvents: [String]? = nil,
        audioFileRef: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.transcript = transcript
        self.duration = duration
        self.extractedMood = extractedMood
        self.extractedEvents = extractedEvents
        self.audioFileRef = audioFileRef
    }
}
