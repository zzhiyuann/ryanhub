import SwiftUI

// MARK: - Dashboard View

/// Main entry point for the Dashboard toolkit module.
/// Uses a floating bubble tab bar matching the Book Factory pattern.
struct DashboardView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var viewModel = DashboardViewModel()
    @State private var selectedTab: DashboardTab = .today

    enum DashboardTab: String, CaseIterable {
        case today = "Today"
        case mainlines = "Mainlines"
        case timeline = "Timeline"
        case agents = "Agents"

        var icon: String {
            switch self {
            case .today: return "checkmark.circle"
            case .mainlines: return "rectangle.stack"
            case .timeline: return "calendar.badge.clock"
            case .agents: return "person.3"
            }
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Content
            Group {
                switch selectedTab {
                case .today:
                    DashboardTodayView(viewModel: viewModel)
                case .mainlines:
                    DashboardMainlinesView(viewModel: viewModel)
                case .timeline:
                    DashboardTimelineView(viewModel: viewModel)
                case .agents:
                    DashboardAgentsView(viewModel: viewModel)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Floating bubble tab bar
            floatingBubbleBar
                .padding(.bottom, 8)
        }
        .background(AdaptiveColors.background(for: colorScheme))
        .task {
            await viewModel.loadData()
            viewModel.startAutoRefresh()
        }
        .onDisappear {
            viewModel.stopAutoRefresh()
        }
    }

    // MARK: - Floating Bubble Bar

    private var floatingBubbleBar: some View {
        HStack(spacing: 4) {
            ForEach(DashboardTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = tab
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 14, weight: .medium))

                        if selectedTab == tab {
                            Text(tab.rawValue)
                                .font(.system(size: 13, weight: .semibold))
                                .transition(.scale(scale: 0.5).combined(with: .opacity))
                        }
                    }
                    .foregroundStyle(
                        selectedTab == tab
                            ? .white
                            : AdaptiveColors.textSecondary(for: colorScheme)
                    )
                    .padding(.horizontal, selectedTab == tab ? 14 : 10)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(selectedTab == tab ? Color.hubPrimary : Color.clear)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(AdaptiveColors.surface(for: colorScheme))
                .shadow(
                    color: colorScheme == .dark ? Color.black.opacity(0.4) : Color.black.opacity(0.12),
                    radius: 12,
                    x: 0,
                    y: 4
                )
        )
        .overlay(
            Capsule()
                .stroke(AdaptiveColors.border(for: colorScheme), lineWidth: 0.5)
        )
    }
}

// MARK: - Today View

struct DashboardTodayView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Bindable var viewModel: DashboardViewModel
    @FocusState private var isAddFieldFocused: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: HubLayout.sectionSpacing) {
                // Header
                headerSection

                // Progress ring
                progressSection

                // Error banner
                if let error = viewModel.errorMessage {
                    errorBanner(error)
                }

                // Today checklist
                todayChecklist

                // Quick add
                quickAddField

                // Spacer for bubble bar
                Color.clear.frame(height: 60)
            }
            .padding(.horizontal, HubLayout.standardPadding)
            .padding(.top, 12)
        }
        .refreshable {
            await viewModel.loadData()
        }
    }

    private var headerSection: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.hubPrimary.opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: "square.grid.2x2")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Color.hubPrimary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Dashboard")
                    .font(.hubHeading)
                    .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                Text(todayDateString)
                    .font(.hubCaption)
                    .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
            }

            Spacer()

            if viewModel.isLoading {
                ProgressView()
                    .scaleEffect(0.8)
            }
        }
    }

    private var progressSection: some View {
        HStack(spacing: 16) {
            // Progress ring
            ZStack {
                Circle()
                    .stroke(AdaptiveColors.border(for: colorScheme), lineWidth: 6)
                    .frame(width: 56, height: 56)

                Circle()
                    .trim(from: 0, to: viewModel.todayProgress)
                    .stroke(Color.hubAccentGreen, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: 56, height: 56)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.5), value: viewModel.todayProgress)

                Text("\(viewModel.todayCompletedCount)/\(viewModel.todayTotalCount)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Today's Focus")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))

                if viewModel.todayTotalCount == 0 {
                    Text("No items for today")
                        .font(.hubCaption)
                        .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                } else if viewModel.todayCompletedCount == viewModel.todayTotalCount {
                    Text("All done! Nice work.")
                        .font(.hubCaption)
                        .foregroundStyle(Color.hubAccentGreen)
                } else {
                    Text("\(viewModel.todayTotalCount - viewModel.todayCompletedCount) items remaining")
                        .font(.hubCaption)
                        .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                }
            }

            Spacer()
        }
        .padding(HubLayout.cardInnerPadding)
        .background(
            RoundedRectangle(cornerRadius: HubLayout.cardCornerRadius)
                .fill(AdaptiveColors.surface(for: colorScheme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: HubLayout.cardCornerRadius)
                .stroke(AdaptiveColors.border(for: colorScheme), lineWidth: 0.5)
        )
    }

    private var todayChecklist: some View {
        VStack(alignment: .leading, spacing: 8) {
            if viewModel.todayItems.isEmpty && !viewModel.isLoading {
                emptyState(icon: "tray", message: "No tasks for today")
            } else {
                ForEach(viewModel.todayItems) { item in
                    todayItemRow(item)
                }
            }
        }
    }

    private func todayItemRow(_ item: DashboardTodayItem) -> some View {
        HStack(spacing: 12) {
            Button {
                Task { await viewModel.toggleTodayItem(item) }
            } label: {
                Image(systemName: item.done ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(item.done ? Color.hubAccentGreen : AdaptiveColors.textSecondary(for: colorScheme))
            }
            .buttonStyle(.plain)

            Text(item.name)
                .font(.hubBody)
                .foregroundStyle(
                    item.done
                        ? AdaptiveColors.textSecondary(for: colorScheme)
                        : AdaptiveColors.textPrimary(for: colorScheme)
                )
                .strikethrough(item.done)

            Spacer()
        }
        .padding(.vertical, 6)
        .padding(.horizontal, HubLayout.cardInnerPadding)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(AdaptiveColors.surface(for: colorScheme))
        )
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                Task { await viewModel.deleteTodayItem(item) }
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private var quickAddField: some View {
        HStack(spacing: 8) {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 20))
                .foregroundStyle(Color.hubPrimary)

            TextField("Add a task for today...", text: $viewModel.newTodayItemText)
                .font(.hubBody)
                .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                .focused($isAddFieldFocused)
                .onSubmit {
                    Task { await viewModel.addTodayItem() }
                }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(AdaptiveColors.surfaceSecondary(for: colorScheme))
        )
    }

    private var todayDateString: String {
        let df = DateFormatter()
        df.dateFormat = "EEEE, MMM d"
        return df.string(from: Date())
    }
}

// MARK: - Mainlines View

struct DashboardMainlinesView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Bindable var viewModel: DashboardViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: HubLayout.itemSpacing) {
                // Section header
                HStack {
                    Text("Mainlines")
                        .font(.hubHeading)
                        .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                    Spacer()
                    Text("\(viewModel.mainlines.count) projects")
                        .font(.hubCaption)
                        .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                }
                .padding(.horizontal, HubLayout.standardPadding)
                .padding(.top, 12)

                // Error banner
                if let error = viewModel.errorMessage {
                    errorBanner(error)
                        .padding(.horizontal, HubLayout.standardPadding)
                }

                // Mainline cards
                ForEach(viewModel.sortedMainlines) { mainline in
                    mainlineCard(mainline)
                        .padding(.horizontal, HubLayout.standardPadding)
                }

                // Spacer for bubble bar
                Color.clear.frame(height: 60)
            }
            .padding(.top, 4)
        }
        .refreshable {
            await viewModel.loadData()
        }
    }

    private func mainlineCard(_ mainline: DashboardMainline) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header row: name + priority badge + deadline
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        priorityDot(mainline.priorityColor)
                        Text(mainline.name)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                    }

                    if let days = mainline.daysUntilDeadline {
                        deadlineLabel(days: days)
                    }
                }

                Spacer()

                // Completion badge
                if !mainline.tasks.isEmpty {
                    let done = mainline.tasks.filter { $0.status == "done" }.count
                    Text("\(done)/\(mainline.tasks.count)")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(AdaptiveColors.surfaceSecondary(for: colorScheme))
                        )
                }
            }

            // Task list
            if !mainline.tasks.isEmpty {
                Divider()
                    .overlay(AdaptiveColors.border(for: colorScheme))

                ForEach(mainline.tasks) { task in
                    taskRow(task, mainlineId: mainline.id)
                }
            }

            // Quick add task
            quickAddTaskField(mainlineId: mainline.id)
        }
        .padding(HubLayout.cardInnerPadding)
        .background(
            RoundedRectangle(cornerRadius: HubLayout.cardCornerRadius)
                .fill(AdaptiveColors.surface(for: colorScheme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: HubLayout.cardCornerRadius)
                .stroke(AdaptiveColors.border(for: colorScheme), lineWidth: 0.5)
        )
    }

    private func taskRow(_ task: DashboardTask, mainlineId: String) -> some View {
        HStack(spacing: 10) {
            // Status toggle button
            Button {
                let nextStatus = nextStatus(for: task.status)
                Task { await viewModel.updateTaskStatus(mainlineId: mainlineId, taskId: task.id, status: nextStatus) }
            } label: {
                Image(systemName: task.statusIcon)
                    .font(.system(size: 18))
                    .foregroundStyle(statusColor(task.status))
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(task.name)
                    .font(.system(size: 14))
                    .foregroundStyle(
                        task.status == "done"
                            ? AdaptiveColors.textSecondary(for: colorScheme)
                            : AdaptiveColors.textPrimary(for: colorScheme)
                    )
                    .strikethrough(task.status == "done")

                if let agent = task.agent, !agent.isEmpty {
                    Text("@\(agent)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.hubPrimaryLight)
                }
            }

            Spacer()

            // Status label
            Text(task.statusLabel)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(statusColor(task.status))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    Capsule()
                        .fill(statusColor(task.status).opacity(0.12))
                )
        }
        .padding(.vertical, 3)
        .contextMenu {
            Button { Task { await viewModel.updateTaskStatus(mainlineId: mainlineId, taskId: task.id, status: "todo") } } label: {
                Label("To Do", systemImage: "circle")
            }
            Button { Task { await viewModel.updateTaskStatus(mainlineId: mainlineId, taskId: task.id, status: "in-progress") } } label: {
                Label("In Progress", systemImage: "arrow.triangle.2.circlepath")
            }
            Button { Task { await viewModel.updateTaskStatus(mainlineId: mainlineId, taskId: task.id, status: "done") } } label: {
                Label("Done", systemImage: "checkmark.circle.fill")
            }
            Button { Task { await viewModel.updateTaskStatus(mainlineId: mainlineId, taskId: task.id, status: "blocked") } } label: {
                Label("Blocked", systemImage: "exclamationmark.octagon.fill")
            }
            Divider()
            Button(role: .destructive) {
                Task { await viewModel.deleteTask(mainlineId: mainlineId, taskId: task.id) }
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func quickAddTaskField(mainlineId: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "plus")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))

            TextField("Add task...", text: Binding(
                get: { viewModel.newTaskText[mainlineId] ?? "" },
                set: { viewModel.newTaskText[mainlineId] = $0 }
            ))
            .font(.system(size: 13))
            .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
            .onSubmit {
                Task { await viewModel.addTask(to: mainlineId) }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(AdaptiveColors.surfaceSecondary(for: colorScheme))
        )
    }

    // MARK: - Helpers

    private func priorityDot(_ priority: PriorityLevel) -> some View {
        Circle()
            .fill(priorityColor(priority))
            .frame(width: 8, height: 8)
    }

    private func priorityColor(_ priority: PriorityLevel) -> Color {
        switch priority {
        case .critical: return Color.hubAccentRed
        case .high: return Color.hubAccentYellow
        case .medium: return Color.hubPrimary
        case .low: return AdaptiveColors.textSecondary(for: colorScheme)
        }
    }

    private func deadlineLabel(days: Int) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "clock")
                .font(.system(size: 10))
            if days < 0 {
                Text("\(abs(days))d overdue")
            } else if days == 0 {
                Text("Due today")
            } else {
                Text("\(days)d left")
            }
        }
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(days <= 3 ? Color.hubAccentRed : (days <= 7 ? Color.hubAccentYellow : AdaptiveColors.textSecondary(for: colorScheme)))
    }

    private func statusColor(_ status: String) -> Color {
        switch status {
        case "done": return Color.hubAccentGreen
        case "in-progress": return Color.hubPrimary
        case "blocked": return Color.hubAccentRed
        case "todo": return AdaptiveColors.textSecondary(for: colorScheme)
        default: return AdaptiveColors.textSecondary(for: colorScheme)
        }
    }

    private func nextStatus(for current: String) -> String {
        switch current {
        case "todo": return "in-progress"
        case "in-progress": return "done"
        case "done": return "todo"
        case "blocked": return "todo"
        default: return "todo"
        }
    }
}

// MARK: - Timeline View

struct DashboardTimelineView: View {
    @Environment(\.colorScheme) private var colorScheme
    var viewModel: DashboardViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: HubLayout.itemSpacing) {
                HStack {
                    Text("Timeline")
                        .font(.hubHeading)
                        .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                    Spacer()
                }
                .padding(.horizontal, HubLayout.standardPadding)
                .padding(.top, 12)

                if viewModel.mainlines.isEmpty && !viewModel.isLoading {
                    emptyState(icon: "calendar.badge.exclamationmark", message: "No mainlines loaded")
                        .padding(.top, 40)
                } else {
                    // Deadlines sorted by date
                    let withDeadlines = viewModel.sortedMainlines.filter { $0.deadline != nil }
                    let noDeadlines = viewModel.sortedMainlines.filter { $0.deadline == nil }

                    if !withDeadlines.isEmpty {
                        ForEach(withDeadlines) { mainline in
                            timelineRow(mainline)
                        }
                    }

                    if !noDeadlines.isEmpty {
                        Text("No Deadline")
                            .font(.hubCaption)
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, HubLayout.standardPadding)
                            .padding(.top, 8)

                        ForEach(noDeadlines) { mainline in
                            timelineRow(mainline)
                        }
                    }
                }

                Color.clear.frame(height: 60)
            }
        }
        .refreshable {
            await viewModel.loadData()
        }
    }

    private func timelineRow(_ mainline: DashboardMainline) -> some View {
        HStack(spacing: 12) {
            // Timeline dot and line
            VStack(spacing: 0) {
                Circle()
                    .fill(timelineColor(mainline))
                    .frame(width: 12, height: 12)
                Rectangle()
                    .fill(AdaptiveColors.border(for: colorScheme))
                    .frame(width: 2)
            }
            .frame(width: 12)

            // Content card
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(mainline.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))

                    Spacer()

                    priorityBadge(mainline.priorityColor)
                }

                if let days = mainline.daysUntilDeadline {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.system(size: 11))
                        Text(mainline.deadline ?? "")
                            .font(.system(size: 12))
                        Text("(\(deadlineText(days)))")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(days <= 3 ? Color.hubAccentRed : (days <= 7 ? Color.hubAccentYellow : AdaptiveColors.textSecondary(for: colorScheme)))
                    }
                    .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                }

                // Progress bar
                if !mainline.tasks.isEmpty {
                    VStack(spacing: 4) {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(AdaptiveColors.surfaceSecondary(for: colorScheme))
                                    .frame(height: 6)

                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.hubAccentGreen)
                                    .frame(width: geo.size.width * mainline.completionRatio, height: 6)
                                    .animation(.easeInOut(duration: 0.3), value: mainline.completionRatio)
                            }
                        }
                        .frame(height: 6)

                        HStack {
                            let done = mainline.tasks.filter { $0.status == "done" }.count
                            Text("\(done)/\(mainline.tasks.count) tasks done")
                                .font(.system(size: 11))
                                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                            Spacer()
                        }
                    }
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(AdaptiveColors.surface(for: colorScheme))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(AdaptiveColors.border(for: colorScheme), lineWidth: 0.5)
            )
        }
        .padding(.horizontal, HubLayout.standardPadding)
    }

    private func timelineColor(_ mainline: DashboardMainline) -> Color {
        if let days = mainline.daysUntilDeadline {
            if days < 0 { return Color.hubAccentRed }
            if days <= 3 { return Color.hubAccentRed }
            if days <= 7 { return Color.hubAccentYellow }
        }
        return Color.hubPrimary
    }

    private func deadlineText(_ days: Int) -> String {
        if days < 0 { return "\(abs(days))d overdue" }
        if days == 0 { return "due today" }
        if days == 1 { return "tomorrow" }
        return "\(days) days left"
    }

    private func priorityBadge(_ priority: PriorityLevel) -> some View {
        Text(priority.displayName)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(priorityBadgeColor(priority))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Capsule()
                    .fill(priorityBadgeColor(priority).opacity(0.12))
            )
    }

    private func priorityBadgeColor(_ priority: PriorityLevel) -> Color {
        switch priority {
        case .critical: return Color.hubAccentRed
        case .high: return Color.hubAccentYellow
        case .medium: return Color.hubPrimary
        case .low: return AdaptiveColors.textSecondary(for: colorScheme)
        }
    }
}

// MARK: - Agents View

struct DashboardAgentsView: View {
    @Environment(\.colorScheme) private var colorScheme
    var viewModel: DashboardViewModel

    /// Known agents derived from task assignments.
    private var knownAgents: [AgentSummary] {
        var agentTasks: [String: [String]] = [:]
        for mainline in viewModel.mainlines {
            for task in mainline.tasks {
                if let agent = task.agent, !agent.isEmpty {
                    agentTasks[agent, default: []].append("\(mainline.name): \(task.name)")
                }
            }
        }
        return agentTasks.map { AgentSummary(name: $0.key, tasks: $0.value) }
            .sorted { $0.tasks.count > $1.tasks.count }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: HubLayout.itemSpacing) {
                HStack {
                    Text("Agents")
                        .font(.hubHeading)
                        .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                    Spacer()
                    Text("\(knownAgents.count) active")
                        .font(.hubCaption)
                        .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                }
                .padding(.horizontal, HubLayout.standardPadding)
                .padding(.top, 12)

                if knownAgents.isEmpty {
                    emptyState(icon: "person.crop.circle.badge.questionmark", message: "No agents assigned to tasks")
                        .padding(.top, 40)
                } else {
                    ForEach(knownAgents, id: \.name) { agent in
                        agentCard(agent)
                    }
                }

                Color.clear.frame(height: 60)
            }
        }
        .refreshable {
            await viewModel.loadData()
        }
    }

    private func agentCard(_ agent: AgentSummary) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(agentColor(agent.name).opacity(0.15))
                        .frame(width: 36, height: 36)
                    Text(agentInitial(agent.name))
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(agentColor(agent.name))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(agent.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                    Text("\(agent.tasks.count) task\(agent.tasks.count == 1 ? "" : "s") assigned")
                        .font(.system(size: 12))
                        .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                }

                Spacer()
            }

            Divider()
                .overlay(AdaptiveColors.border(for: colorScheme))

            ForEach(agent.tasks, id: \.self) { task in
                HStack(spacing: 6) {
                    Circle()
                        .fill(agentColor(agent.name))
                        .frame(width: 4, height: 4)
                    Text(task)
                        .font(.system(size: 13))
                        .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                }
            }
        }
        .padding(HubLayout.cardInnerPadding)
        .background(
            RoundedRectangle(cornerRadius: HubLayout.cardCornerRadius)
                .fill(AdaptiveColors.surface(for: colorScheme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: HubLayout.cardCornerRadius)
                .stroke(AdaptiveColors.border(for: colorScheme), lineWidth: 0.5)
        )
        .padding(.horizontal, HubLayout.standardPadding)
    }

    private func agentColor(_ name: String) -> Color {
        switch name.lowercased() {
        case "ryan": return Color.hubPrimary
        case "boo": return Color.hubAccentGreen
        case "cc": return Color.hubPrimaryLight
        case "codex": return Color.hubAccentYellow
        default: return Color.hubPrimary
        }
    }

    private func agentInitial(_ name: String) -> String {
        String(name.prefix(1)).uppercased()
    }
}

// MARK: - Agent Summary

private struct AgentSummary {
    let name: String
    let tasks: [String]
}

// MARK: - Shared View Helpers

private func errorBanner(_ message: String) -> some View {
    HStack(spacing: 8) {
        Image(systemName: "wifi.exclamationmark")
            .font(.system(size: 14))
        Text(message)
            .font(.system(size: 13))
    }
    .foregroundStyle(Color.hubAccentRed)
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.hubAccentRed.opacity(0.1))
    )
}

private func emptyState(icon: String, message: String) -> some View {
    VStack(spacing: 12) {
        Image(systemName: icon)
            .font(.system(size: 36))
            .foregroundStyle(Color.hubPrimary.opacity(0.4))
        Text(message)
            .font(.hubCaption)
            .foregroundStyle(Color.hubPrimary.opacity(0.6))
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 32)
}

#Preview {
    DashboardView()
}
