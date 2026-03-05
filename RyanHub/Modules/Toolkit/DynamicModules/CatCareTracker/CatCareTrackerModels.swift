import Foundation

// MARK: - Enums

enum CareEventType: String, CaseIterable, Codable, Identifiable {
    case feeding
    case vetVisit
    case medication
    case weightCheck
    case grooming

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .feeding: return "Feeding"
        case .vetVisit: return "Vet Visit"
        case .medication: return "Medication"
        case .weightCheck: return "Weight Check"
        case .grooming: return "Grooming"
        }
    }

    var icon: String {
        switch self {
        case .feeding: return "fork.knife"
        case .vetVisit: return "cross.case.fill"
        case .medication: return "pills.fill"
        case .weightCheck: return "scalemass.fill"
        case .grooming: return "scissors"
        }
    }
}

enum FeedType: String, CaseIterable, Codable, Identifiable {
    case wetFood
    case dryFood
    case treat
    case water

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .wetFood: return "Wet Food"
        case .dryFood: return "Dry Food"
        case .treat: return "Treat"
        case .water: return "Water"
        }
    }

    var icon: String {
        switch self {
        case .wetFood: return "takeoutbag.and.cup.and.straw.fill"
        case .dryFood: return "cup.and.saucer.fill"
        case .treat: return "star.fill"
        case .water: return "drop.fill"
        }
    }

    /// Returns true if this feed type counts toward the daily meal goal.
    var countsMeal: Bool {
        switch self {
        case .wetFood, .dryFood: return true
        case .treat, .water: return false
        }
    }
}

enum VetVisitType: String, CaseIterable, Codable, Identifiable {
    case checkup
    case vaccination
    case dental
    case emergency
    case surgery
    case labWork

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .checkup: return "Checkup"
        case .vaccination: return "Vaccination"
        case .dental: return "Dental"
        case .emergency: return "Emergency"
        case .surgery: return "Surgery"
        case .labWork: return "Lab Work"
        }
    }

    var icon: String {
        switch self {
        case .checkup: return "stethoscope"
        case .vaccination: return "syringe.fill"
        case .dental: return "mouth.fill"
        case .emergency: return "exclamationmark.triangle.fill"
        case .surgery: return "bandage.fill"
        case .labWork: return "testtube.2"
        }
    }
}

enum MedicationType: String, CaseIterable, Codable, Identifiable {
    case fleaTick
    case deworming
    case antibiotic
    case supplement
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .fleaTick: return "Flea & Tick"
        case .deworming: return "Deworming"
        case .antibiotic: return "Antibiotic"
        case .supplement: return "Supplement"
        case .other: return "Other"
        }
    }

    var icon: String {
        switch self {
        case .fleaTick: return "ladybug.fill"
        case .deworming: return "pill.fill"
        case .antibiotic: return "cross.vial.fill"
        case .supplement: return "leaf.fill"
        case .other: return "ellipsis.circle.fill"
        }
    }
}

enum CatMood: String, CaseIterable, Codable, Identifiable {
    case playful
    case content
    case sleepy
    case lethargic
    case anxious
    case hiding

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .playful: return "Playful"
        case .content: return "Content"
        case .sleepy: return "Sleepy"
        case .lethargic: return "Lethargic"
        case .anxious: return "Anxious"
        case .hiding: return "Hiding"
        }
    }

    var icon: String {
        switch self {
        case .playful: return "figure.play"
        case .content: return "face.smiling.inverse"
        case .sleepy: return "moon.zzz.fill"
        case .lethargic: return "tortoise.fill"
        case .anxious: return "exclamationmark.circle.fill"
        case .hiding: return "eye.slash.fill"
        }
    }

    /// Indicates moods that may signal a health concern worth noting.
    var isConcerning: Bool {
        switch self {
        case .lethargic, .anxious, .hiding: return true
        case .playful, .content, .sleepy: return false
        }
    }
}

// MARK: - Entry Model

struct CatCareTrackerEntry: Codable, Identifiable {
    var id: String = UUID().uuidString
    var date: String = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.string(from: Date())
    }()

    // Event classification
    var eventType: CareEventType = .feeding

    // Feeding fields
    var feedType: FeedType = .wetFood
    var portionCount: Int = 1
    var wasEaten: Bool = true

    // Vet visit fields
    var vetVisitType: VetVisitType = .checkup
    var costCents: Int = 0

    // Medication fields
    var medicationType: MedicationType = .fleaTick

    // Weight check fields
    var weightGrams: Int = 4000

    // Always-visible fields
    var mood: CatMood = .content
    var eventTime: Date = Date()
    var notes: String = ""

    // MARK: - Computed: Date Parsing

    var parsedDate: Date {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.date(from: date) ?? Date()
    }

    var calendarDay: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: parsedDate)
    }

    // MARK: - Computed: Formatted Display

    var formattedDate: String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: parsedDate)
    }

    var formattedTime: String {
        let f = DateFormatter()
        f.timeStyle = .short
        return f.string(from: eventTime)
    }

    var formattedCost: String {
        guard costCents > 0 else { return "" }
        let dollars = Double(costCents) / 100.0
        return String(format: "$%.2f", dollars)
    }

    var formattedWeight: String {
        if weightGrams >= 1000 {
            return String(format: "%.2f kg", Double(weightGrams) / 1000.0)
        }
        return "\(weightGrams) g"
    }

    // MARK: - Computed: Summary Line

    var summaryLine: String {
        switch eventType {
        case .feeding:
            let portions = portionCount == 1 ? "1 portion" : "\(portionCount) portions"
            let eaten = wasEaten ? "" : " (not finished)"
            return "\(portions) \(feedType.displayName)\(eaten)"

        case .vetVisit:
            let cost = costCents > 0 ? " — \(formattedCost)" : ""
            return "\(vetVisitType.displayName)\(cost)"

        case .medication:
            return medicationType.displayName

        case .weightCheck:
            return formattedWeight

        case .grooming:
            return notes.isEmpty ? "Grooming session" : notes
        }
    }

    var detailLine: String {
        var parts: [String] = [formattedTime]
        if !notes.isEmpty { parts.append(notes) }
        return parts.joined(separator: " · ")
    }

    // MARK: - Computed: Domain Helpers

    /// True if this entry contributes to the daily feeding streak (wet or dry food only).
    var countsForStreak: Bool {
        eventType == .feeding && feedType.countsMeal
    }

    /// True if this is a flea & tick medication entry.
    var isFleaTickMedication: Bool {
        eventType == .medication && medicationType == .fleaTick
    }

    /// True if this is a standard wellness checkup (not emergency/surgery).
    var isWellnessVetVisit: Bool {
        eventType == .vetVisit && (vetVisitType == .checkup || vetVisitType == .vaccination)
    }
}

// MARK: - Daily Feeding Goal

extension CatCareTrackerEntry {
    static let dailyFeedingGoal: Int = 3
}