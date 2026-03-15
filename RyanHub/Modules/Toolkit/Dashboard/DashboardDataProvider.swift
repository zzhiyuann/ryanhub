import Foundation

// MARK: - Dashboard Data Provider

/// Provides dashboard project/task data for chat context injection.
/// Uses a static cache populated by DashboardViewModel after loading.
enum DashboardDataProvider: ToolkitDataProvider {

    static let toolkitId = "dashboard"
    static let displayName = "Project Dashboard"

    static let relevanceKeywords: [String] = [
        "dashboard", "mainline", "project", "task", "deadline", "today",
        "priority", "agent", "progress", "sprint", "status",
        // Chinese
        "仪表盘", "项目", "任务", "截止", "进度", "待办"
    ]

    static func buildContextSummary() -> String? {
        guard let data = UserDefaults.standard.data(forKey: "dashboard_cache"),
              let response = try? JSONDecoder().decode(DashboardResponse.self, from: data) else {
            return nil
        }

        var lines: [String] = ["[\(displayName)]"]
        lines.append("Mainlines: \(response.mainlines.count)")

        // Today summary
        if let today = response.today {
            let done = today.items.filter(\.done).count
            lines.append("Today (\(today.date)): \(done)/\(today.items.count) items done")
            for item in today.items where !item.done {
                lines.append("  - [ ] \(item.name)")
            }
        }

        // Critical/high projects
        let urgent = response.mainlines.filter { $0.priority == "critical" || $0.priority == "high" }
        if !urgent.isEmpty {
            lines.append("Urgent projects:")
            for m in urgent {
                let active = m.tasks.filter { $0.status != "done" }.count
                var desc = "  - \(m.name) [\(m.priority)]"
                if let deadline = m.deadline {
                    desc += " due \(deadline)"
                }
                desc += " (\(active) active tasks)"
                lines.append(desc)
            }
        }

        lines.append("API: https://zhiyuans-imac.tail88572f.ts.net/dashboard/api/mainlines")
        lines.append("[End \(displayName)]")
        return lines.joined(separator: "\n")
    }
}
