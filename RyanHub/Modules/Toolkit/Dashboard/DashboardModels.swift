import Foundation

// MARK: - Dashboard API Response

/// Top-level response from GET /api/mainlines
struct DashboardResponse: Decodable {
    let lastUpdated: String?
    let mainlines: [DashboardMainline]
    let today: DashboardToday?
    let agentEvents: [DashboardAgentEvent]?
    let agents: [String: DashboardAgent]?

    // Use custom decoding to skip unknown fields gracefully
    enum CodingKeys: String, CodingKey {
        case lastUpdated, mainlines, today, agentEvents, agents
    }
}

// MARK: - Mainline

struct DashboardMainline: Codable, Identifiable {
    let id: String
    let name: String
    let path: String?
    let status: String
    let deadline: String?
    let priority: String
    var tasks: [DashboardTask]
    let updated: String?

    /// Number of days until deadline, nil if no deadline.
    var daysUntilDeadline: Int? {
        guard let deadline else { return nil }
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        df.timeZone = TimeZone.current
        guard let date = df.date(from: deadline) else { return nil }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let target = calendar.startOfDay(for: date)
        return calendar.dateComponents([.day], from: today, to: target).day
    }

    /// Priority color for display.
    var priorityColor: PriorityLevel {
        PriorityLevel(rawValue: priority) ?? .medium
    }

    /// Task completion ratio.
    var completionRatio: Double {
        guard !tasks.isEmpty else { return 0 }
        let done = tasks.filter { $0.status == "done" }.count
        return Double(done) / Double(tasks.count)
    }

    var activeTasks: [DashboardTask] {
        tasks.filter { $0.status != "done" }
    }
}

// MARK: - Task

struct DashboardTask: Codable, Identifiable {
    let id: String
    var name: String
    var status: String
    var agent: String?
    let createdAt: String?
    let completedAt: String?
    let completedBy: String?
    let needsReview: Bool?
    let order: Int?

    /// Readable status label.
    var statusLabel: String {
        switch status {
        case "done": return "Done"
        case "in-progress": return "In Progress"
        case "blocked": return "Blocked"
        case "todo": return "To Do"
        default: return status
        }
    }

    var statusIcon: String {
        switch status {
        case "done": return "checkmark.circle.fill"
        case "in-progress": return "arrow.triangle.2.circlepath"
        case "blocked": return "exclamationmark.octagon.fill"
        case "todo": return "circle"
        default: return "questionmark.circle"
        }
    }
}

// MARK: - Today

struct DashboardToday: Codable {
    let date: String
    var items: [DashboardTodayItem]
}

struct DashboardTodayItem: Codable, Identifiable {
    let id: String
    let type: String
    let mainlineId: String?
    let taskId: String?
    var name: String
    var done: Bool
    let manual: Bool?
    let order: Int?
}

// MARK: - Agent Event

struct DashboardAgentEvent: Codable, Identifiable {
    let id: String
    let agent: String
    let action: String
    let mainlineId: String?
    let taskId: String?
    let message: String?
    let timestamp: String
    let reviewed: Bool?
}

// MARK: - Agent

struct DashboardAgent: Codable {
    let status: String?
    let lastSeen: String?
}

// MARK: - Priority Level

enum PriorityLevel: String, CaseIterable {
    case critical
    case high
    case medium
    case low

    var displayName: String {
        rawValue.capitalized
    }

    var sortOrder: Int {
        switch self {
        case .critical: return 0
        case .high: return 1
        case .medium: return 2
        case .low: return 3
        }
    }
}
