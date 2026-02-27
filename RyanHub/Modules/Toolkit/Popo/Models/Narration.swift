import Foundation

// MARK: - Affect Analysis

/// Emotional/psychological analysis result from a voice diary transcript.
struct AffectAnalysis: Codable, Equatable {
    /// Mood on a 1–10 scale (1 = very low, 10 = very positive).
    var mood: Int?
    /// Energy level on a 1–10 scale.
    var energy: Int?
    /// Stress level on a 1–10 scale.
    var stress: Int?
    /// Primary detected emotion (e.g., "calm", "anxious", "happy").
    var primaryEmotion: String?
    /// Secondary detected emotion.
    var secondaryEmotion: String?
    /// One-sentence summary of the overall emotional tone.
    var briefSummary: String?

    enum CodingKeys: String, CodingKey {
        case mood, energy, stress
        case primaryEmotion = "primary_emotion"
        case secondaryEmotion = "secondary_emotion"
        case briefSummary = "brief_summary"
    }
}

// MARK: - Narration

/// A voice narration entry recorded by the user.
/// Contains the transcript, optional mood extraction, affective analysis,
/// and a reference to the audio file for playback.
struct Narration: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    /// Transcript text — empty string before transcription completes.
    var transcript: String
    /// Recording duration in seconds.
    var duration: TimeInterval
    /// Legacy simple mood string (e.g., "happy").
    var extractedMood: String?
    /// Legacy extracted life events.
    var extractedEvents: [String]?
    /// Filename of the uploaded audio (e.g., "abc123.m4a").
    var audioFileRef: String?
    /// Structured affective analysis from the transcription pipeline.
    var affectAnalysis: AffectAnalysis?

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        transcript: String = "",
        duration: TimeInterval = 0,
        extractedMood: String? = nil,
        extractedEvents: [String]? = nil,
        audioFileRef: String? = nil,
        affectAnalysis: AffectAnalysis? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.transcript = transcript
        self.duration = duration
        self.extractedMood = extractedMood
        self.extractedEvents = extractedEvents
        self.audioFileRef = audioFileRef
        self.affectAnalysis = affectAnalysis
    }
}
