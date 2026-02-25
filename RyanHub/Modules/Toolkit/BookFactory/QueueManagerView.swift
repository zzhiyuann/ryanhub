import SwiftUI

/// Manage the Book Factory topic generation queue.
/// Supports filtering (pending/done/all), reordering, CRUD operations, and schedule display.
struct QueueManagerView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(QueueViewModel.self) private var vm
    @State private var filter: TopicFilter = .pending
    @State private var showAddSheet = false
    @State private var editingTopic: QueueTopic?

    enum TopicFilter: String, CaseIterable {
        case pending = "Pending"
        case done = "Done"
        case all = "All"
    }

    var filteredTopics: [QueueTopic] {
        switch filter {
        case .pending: return vm.pendingTopics
        case .done: return vm.doneTopics
        case .all: return vm.topics
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if vm.isLoading && vm.topics.isEmpty {
                    loadingView
                } else if vm.topics.isEmpty {
                    emptyView
                } else {
                    topicList
                }
            }
            .background(AdaptiveColors.background(for: colorScheme))
            .navigationTitle("Queue")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if filter == .pending {
                        EditButton()
                    }
                }
                ToolbarItem(placement: .principal) {
                    Picker("Filter", selection: $filter) {
                        ForEach(TopicFilter.allCases, id: \.self) { f in
                            Text(f.rawValue).tag(f)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 200)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAddSheet = true } label: {
                        Image(systemName: "plus")
                            .foregroundStyle(Color.hubPrimary)
                    }
                }
            }
            .refreshable {
                await vm.loadTopics()
                await vm.loadSchedule()
            }
            .task {
                await vm.loadTopics()
                await vm.loadSchedule()
            }
            .sheet(isPresented: $showAddSheet) {
                AddTopicSheet(vm: vm)
            }
            .sheet(item: $editingTopic) { topic in
                EditTopicSheet(topic: topic, vm: vm)
            }
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Loading queue...")
                .font(.hubCaption)
                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Empty View

    private var emptyView: some View {
        ContentUnavailableView {
            Label("No Topics", systemImage: "list.bullet")
        } description: {
            Text("Tap + to add topics to your queue.")
        }
    }

    // MARK: - Topic List

    private var topicList: some View {
        List {
            // Schedule header for pending filter
            if filter == .pending, let schedule = vm.schedule {
                scheduleSection(schedule)
            }

            // Topic rows
            Section(filter == .pending ? "Queue" : filter.rawValue) {
                ForEach(Array(filteredTopics.enumerated()), id: \.element.id) { index, topic in
                    // Visual dividers for today/tomorrow boundaries
                    if filter == .pending, let schedule = vm.schedule {
                        if index == schedule.remainingToday && schedule.remainingToday > 0 {
                            Label("Tomorrow", systemImage: "calendar")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color.hubPrimary)
                                .listRowBackground(Color.clear)
                        }
                        if index == schedule.remainingToday + schedule.booksPerDay {
                            Label("Later", systemImage: "calendar.badge.clock")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                                .listRowBackground(Color.clear)
                        }
                    }

                    topicRow(topic)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                Task { await vm.deleteTopic(id: topic.id) }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .swipeActions(edge: .leading) {
                            if topic.status == "pending" {
                                Button {
                                    Task { await vm.updateTopic(id: topic.id, status: "skipped") }
                                } label: {
                                    Label("Skip", systemImage: "forward")
                                }
                                .tint(.hubPrimary)
                            } else if topic.status == "skipped" {
                                Button {
                                    Task { await vm.updateTopic(id: topic.id, status: "pending") }
                                } label: {
                                    Label("Restore", systemImage: "arrow.uturn.backward")
                                }
                                .tint(.hubAccentGreen)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { editingTopic = topic }
                }
                .onMove { from, to in
                    if filter == .pending {
                        vm.moveTopic(from: from, to: to)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Schedule Section

    @ViewBuilder
    private func scheduleSection(_ schedule: ScheduleResponse) -> some View {
        Section {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Today")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                    Text("\(schedule.generatedToday) generated, \(schedule.remainingToday) remaining")
                        .font(.hubCaption)
                        .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                }
                Spacer()
                Text("\(schedule.generatedToday)/\(schedule.booksPerDay)")
                    .font(.system(size: 22, weight: .bold).monospacedDigit())
                    .foregroundStyle(Color.hubPrimary)
            }
        }
    }

    // MARK: - Topic Row

    private func topicRow(_ topic: QueueTopic) -> some View {
        HStack(spacing: 12) {
            statusIcon(topic.status)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 4) {
                Text(topic.title)
                    .font(.system(size: 15))
                    .lineLimit(2)
                    .strikethrough(topic.status == "skipped")
                    .foregroundStyle(
                        topic.status == "skipped"
                            ? AdaptiveColors.textSecondary(for: colorScheme)
                            : AdaptiveColors.textPrimary(for: colorScheme)
                    )

                HStack(spacing: 8) {
                    if let tier = topic.tier {
                        Text(tier)
                            .font(.system(size: 11, weight: .medium))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Color.hubPrimary.opacity(0.15),
                                in: Capsule()
                            )
                            .foregroundStyle(Color.hubPrimary)
                    }
                    if let date = topic.generatedDate {
                        Text(date)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                    }
                }
            }
        }
    }

    // MARK: - Status Icon

    @ViewBuilder
    private func statusIcon(_ status: String) -> some View {
        switch status {
        case "done":
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color.hubAccentGreen)
        case "skipped":
            Image(systemName: "xmark.circle")
                .foregroundStyle(Color.hubAccentRed)
        default:
            Image(systemName: "circle")
                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
        }
    }
}

// MARK: - Add Topic Sheet

struct AddTopicSheet: View {
    @Environment(\.colorScheme) private var colorScheme
    let vm: QueueViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var tier = ""
    @State private var description = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Title", text: $title)
                        .textInputAutocapitalization(.sentences)
                } header: {
                    Text("Topic Title")
                }

                Section {
                    TextField("e.g. Tier 1, Tier L1", text: $tier)
                        .textInputAutocapitalization(.never)
                } header: {
                    Text("Tier (optional)")
                }

                Section {
                    TextField("Brief description...", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                } header: {
                    Text("Description (optional)")
                }
            }
            .navigationTitle("Add Topic")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        Task {
                            await vm.addTopic(
                                title: title,
                                tier: tier.isEmpty ? nil : tier,
                                description: description.isEmpty ? nil : description
                            )
                            dismiss()
                        }
                    }
                    .tint(.hubPrimary)
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

// MARK: - Edit Topic Sheet

struct EditTopicSheet: View {
    let topic: QueueTopic
    let vm: QueueViewModel

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var tier: String
    @State private var description: String
    @State private var status: String

    init(topic: QueueTopic, vm: QueueViewModel) {
        self.topic = topic
        self.vm = vm
        _title = State(initialValue: topic.title)
        _tier = State(initialValue: topic.tier ?? "")
        _description = State(initialValue: topic.description ?? "")
        _status = State(initialValue: topic.status)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Title", text: $title)
                        .textInputAutocapitalization(.sentences)
                }

                Section {
                    TextField("Tier", text: $tier)
                        .textInputAutocapitalization(.never)
                } header: {
                    Text("Tier")
                }

                Section {
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                } header: {
                    Text("Description")
                }

                Section {
                    Picker("Status", selection: $status) {
                        Text("Pending").tag("pending")
                        Text("Done").tag("done")
                        Text("Skipped").tag("skipped")
                    }
                }
            }
            .navigationTitle("Edit Topic")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await vm.updateTopic(
                                id: topic.id,
                                title: title != topic.title ? title : nil,
                                status: status != topic.status ? status : nil,
                                tier: tier != (topic.tier ?? "") ? (tier.isEmpty ? nil : tier) : nil,
                                description: description != (topic.description ?? "") ? (description.isEmpty ? nil : description) : nil
                            )
                            dismiss()
                        }
                    }
                    .tint(.hubPrimary)
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
