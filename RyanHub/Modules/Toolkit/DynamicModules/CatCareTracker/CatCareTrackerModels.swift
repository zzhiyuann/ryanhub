import Foundation

// MARK: - Enums

enum EventType: String, CaseIterable, Codable, Identifiable {
    case feeding
    case vetVisit
    case weightCheck
    case medication
    case symptom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .feeding: return "Feeding"
        case .vetVisit: return "Vet Visit"
        case .weightCheck: return "Weight Check"
        case .medication: return "Medication"
        case .symptom: return "Symptom"
        }
    }

    var icon: String {
        switch self {
        case .feeding: return "fork.knife"
        case .vetVisit: return "cross.case.fill"
        case .weightCheck: return "scalemass.fill"
        case .medication: return "pills.fill"
        case .symptom: return "exclamationmark.triangle.fill"
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
        case .wetFood: return "cup.and.saucer.fill"
        case .dryFood: return "bag.fill"
        case .treat: return "star.fill"
        case .water: return "drop.fill"
        }
    }
}

enum VetReason: String, CaseIterable, Codable, Identifiable {
    case routine
    case vaccination
    case illness
    case dental
    case emergency
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .routine: return "Routine Checkup"
        case .vaccination: return "Vaccination"
        case .illness: return "Illness"
        case .dental: return "Dental"
        case .emergency: return "Emergency"
        case .other: return "Other"
        }
    }

    var icon: String {
        switch self {
        case .routine: return "checkmark.shield.fill"
        case .vaccination: return "syringe.fill"
        case .illness: return "stethoscope"
        case .dental: return "mouth.fill"
        case .emergency: return "light.beacon.max.fill"
        case .other: return "ellipsis.circle.fill"
        }
    }
}

enum SymptomType: String, CaseIterable, Codable, Identifiable {
    case vomiting
    case diarrhea
    case lethargy
    case lossOfAppetite
    case sneezing
    case skinIssue
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .vomiting: return "Vomiting"
        case .diarrhea: return "Digestive Issue"
        case .lethargy: return "Lethargy"
        case .lossOfAppetite: return "Loss of Appetite"
        case .sneezing: return "Sneezing / Coughing"
        case .skinIssue: return "Skin / Fur Issue"
        case .other: return "Other"
        }
    }

    var icon: String {
        switch self {
        case .vomiting: return "exclamationmark.triangle.fill"
        case .diarrhea: return "exclamationmark.circle.fill"
        case .lethargy: return "zzz"
        case .lossOfAppetite: return "fork.knife.circle"
        case .sneezing: return "wind"
        case .skinIssue: return "bandage.fill"
        case .other: return "questionmark.circle.fill"
        }
    }
}

enum CatMood: String, CaseIterable, Codable, Identifiable {
    case playful
    case calm
    case affectionate
    case lethargic
    case anxious
    case aggressive

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .playful: return "Playful"
        case .calm: return "Calm"
        case .affectionate: return "Affectionate"
        case .lethargic: return "Lethargic"
        case .anxious: return "Anxious"
        case .aggressive: return "Aggressive"
        }
    }

    var icon: String {
        switch self {
        case .playful: return "figure.play"
        case .calm: return "moon.fill"
        case .affectionate: return "heart.fill"
        case .lethargic: return "zzz"
        case .anxious: return "bolt.heart.fill"
        case .aggressive: return "exclamationmark.triangle.fill"
        }
    }

    var isPositive: Bool {
        switch self {
        case .playful, .calm, .affectionate: return true
        case .lethargic, .anxious, .aggressive: return false
        }
    }
}

// MARK: - Helper Types

struct DailyCount: Identifiable {
    let id: String
    let date: Date
    let count: Int

    init(date: Date, count: Int) {
        self.id = date.formatted(.dateTime.month().day())
        self.date = date
        self.count = count
    }
}

// MARK: - Main Entry

struct CatCareTrackerEntry: Codable, Identifiable {
    var id: String = UUID().uuidString
    var date: String = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.string(from: Date())
    }()

    // Data fields
    var eventType: EventType = .feeding
    var feedType: FeedType = .wetFood
    var portionSize: Double = 0.0
    var catWeight: Double = 0.0
    var vetReason: VetReason = .routine
    var symptomType: SymptomType = .vomiting
    var catMood: CatMood = .calm
    var cost: Double = 0.0
    var medicationName: String = ""
    var notes: String = ""

    // MARK: - Computed: Dates

    var parsedDate: Date {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.date(from: date) ?? Date()
    }

    var formattedDate: String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: parsedDate)
    }

    var dateOnly: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: parsedDate)
    }

    var hourOfDay: Int {
        Calendar.current.component(.hour, from: parsedDate)
    }

    var isToday: Bool {
        Calendar.current.isDateInToday(parsedDate)
    }

    // MARK: - Computed: Summary

    var summaryLine: String {
        switch eventType {
        case .feeding:
            let portion = portionSize > 0 ? " (\(Int(portionSize))g)" : ""
            return "\(feedType.displayName)\(portion)"
        case .vetVisit:
            let costStr = cost > 0 ? " — $\(String(format: "%.0f", cost))" : ""
            return "\(vetReason.displayName)\(costStr)"
        case .weightCheck:
            return catWeight > 0 ? "\(String(format: "%.1f", catWeight)) lbs" : "Weight Check"
        case .medication:
            return medicationName.isEmpty ? "Medication" : medicationName
        case .symptom:
            return symptomType.displayName
        }
    }

    var detailLine: String {
        var parts: [String] = []
        if catMood != .calm || eventType == .symptom {
            parts.append(catMood.displayName)
        }
        if !notes.isEmpty {
            parts.append(notes)
        }
        return parts.joined(separator: " · ")
    }

    // MARK: - Computed: Display helpers

    var formattedWeight: String {
        catWeight > 0 ? "\(String(format: "%.1f", catWeight)) lbs" : "—"
    }

    var formattedCost: String {
        cost > 0 ? "$\(String(format: "%.2f", cost))" : "—"
    }

    var formattedPortion: String {
        portionSize > 0 ? "\(Int(portionSize))g" : "—"
    }

    // MARK: - Computed: Relevance flags

    var isFeedingEvent: Bool { eventType == .feeding }
    var isVetEvent: Bool { eventType == .vetVisit }
    var isWeightEvent: Bool { eventType == .weightCheck }
    var isMedicationEvent: Bool { eventType == .medication }
    var isSymptomEvent: Bool { eventType == .symptom }

    var hasCost: Bool { cost > 0 }
    var hasNotes: Bool { !notes.isEmpty }
    var hasMedication: Bool { !medicationName.isEmpty }
}