import Foundation

// MARK: - Book

struct Book: Codable, Identifiable, Sendable, Hashable {
    let id: String
    let title: String
    let topic: String?
    let date: String
    let slot: String?
    let wordCount: Int
    let language: String?
    let hasAudio: Int
    let audioDuration: Double?
    let audioVoice: String?
    let createdAt: String?

    var hasAudioBool: Bool { hasAudio == 1 }

    enum CodingKeys: String, CodingKey {
        case id, title, topic, date, slot, language
        case wordCount = "word_count"
        case hasAudio = "has_audio"
        case audioDuration = "audio_duration"
        case audioVoice = "audio_voice"
        case createdAt = "created_at"
    }
}

struct BooksResponse: Codable {
    let books: [Book]
}

// MARK: - Audio Manifest

struct AudioManifest: Codable, Sendable {
    let bookId: String?
    let title: String?
    let totalDuration: Double
    let estimatedTotalDuration: Double?
    let voice: String?
    let complete: Bool?
    let chunksTotal: Int?
    let chunksReady: Int?
    let chapters: [ChapterMarker]
    let chunks: [AudioChunkInfo]

    /// Whether all chunks have been generated
    var isComplete: Bool { complete ?? true }

    /// Total number of chunks expected
    var totalChunks: Int { chunksTotal ?? chunks.count }

    /// Number of chunks available for playback
    var readyChunks: Int { chunksReady ?? chunks.count }
}

struct ChapterMarker: Codable, Identifiable, Sendable {
    var id: String { title }
    let title: String
    let startTime: Double
    let endTime: Double
    let startChunk: Int
    let endChunk: Int
}

struct AudioChunkInfo: Codable, Identifiable, Sendable {
    let index: Int
    let duration: Double
    let size: Int?
    let path: String?

    var id: Int { index }
}

struct AudioStatus: Codable, Sendable {
    let jobId: String?
    let status: String  // "none" | "processing" | "done" | "error"
    let progress: Double?
    let chunksReady: Int?
    let chunksTotal: Int?
    let error: String?
}

struct GenerateAudioResponse: Codable {
    let jobId: String
    let status: String
    let chunksTotal: Int
}

// MARK: - Queue

struct QueueTopic: Codable, Identifiable, Sendable {
    let id: String
    let tier: String?
    let title: String
    let description: String?
    let status: String
    let position: Int
    let generatedDate: String?
    let generatedSlot: String?
    let bookId: String?

    enum CodingKeys: String, CodingKey {
        case id, tier, title, description, status, position
        case generatedDate = "generated_date"
        case generatedSlot = "generated_slot"
        case bookId = "book_id"
    }
}

struct QueueResponse: Codable {
    let topics: [QueueTopic]
}

struct ScheduleResponse: Codable {
    let today: [QueueTopic]
    let tomorrow: [QueueTopic]
    let booksPerDay: Int
    let generatedToday: Int
    let remainingToday: Int
}

// MARK: - Formatting Helpers

enum BookFormatting {
    static func wordCount(_ count: Int) -> String {
        if count >= 10000 { return String(format: "%.1fk words", Double(count) / 1000) }
        if count >= 1000 { return String(format: "%.1fk words", Double(count) / 1000) }
        return "\(count) words"
    }

    static func duration(_ seconds: Double) -> String {
        let total = Int(seconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%d:%02d", m, s)
    }

    static func shortDuration(_ seconds: Double) -> String {
        let m = Int(seconds / 60)
        if m == 0 { return "<1 min" }
        return "\(m) min"
    }

    static func progress(_ value: Double) -> String {
        return "\(Int(value * 100))%"
    }
}
