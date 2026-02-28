import Foundation

/// Manages the Book Factory topic queue — pending/done topics, schedule, CRUD, reordering.
@MainActor @Observable
final class QueueViewModel {
    var topics: [QueueTopic] = []
    var schedule: ScheduleResponse?
    var isLoading = false
    var error: String?

    private let api: BookFactoryAPI

    init(api: BookFactoryAPI) {
        self.api = api
    }

    // MARK: - Computed Properties

    var pendingTopics: [QueueTopic] {
        topics.filter { $0.status == "pending" }
    }

    var doneTopics: [QueueTopic] {
        topics.filter { $0.status == "done" }
    }

    // MARK: - Data Loading

    func loadTopics() async {
        isLoading = true
        error = nil
        do {
            let response: QueueResponse = try await api.get("/api/queue")
            topics = response.topics
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func loadSchedule() async {
        do {
            schedule = try await api.get("/api/queue/schedule")
        } catch {
            // ignore — schedule endpoint may not always be available
        }
    }

    // MARK: - Topic CRUD

    func addTopic(title: String, tier: String?, description: String?, scheduling: String = "End of Queue") async {
        struct Body: Encodable {
            let title: String
            let tier: String?
            let description: String?
            let scheduling: String
        }
        do {
            let _: QueueTopic = try await api.post(
                "/api/queue/topics",
                body: Body(title: title, tier: tier, description: description, scheduling: scheduling)
            )
            await loadTopics()
            await loadSchedule()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func updateTopic(id: String, title: String? = nil, status: String? = nil, tier: String? = nil, description: String? = nil) async {
        struct Body: Encodable {
            let title: String?
            let status: String?
            let tier: String?
            let description: String?
        }
        do {
            let _: QueueTopic = try await api.put(
                "/api/queue/topics/\(id)",
                body: Body(title: title, status: status, tier: tier, description: description)
            )
            await loadTopics()
            await loadSchedule()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func deleteTopic(id: String) async {
        do {
            try await api.delete("/api/queue/topics/\(id)")
            topics.removeAll { $0.id == id }
            await loadSchedule()
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Generate Immediately

    func generateImmediately(id: String) async {
        struct GenerateResponse: Decodable {
            let ok: Bool
            let jobId: String?
        }
        do {
            let _: GenerateResponse = try await api.post("/api/queue/topics/\(id)/generate")
            await loadTopics()
            await loadSchedule()
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Reordering

    func moveTopic(from source: IndexSet, to destination: Int) {
        var pending = pendingTopics
        pending.move(fromOffsets: source, toOffset: destination)
        // Optimistic local update
        let nonPending = topics.filter { $0.status != "pending" }
        topics = pending + nonPending
        // Persist reorder to server
        let ids = pending.map(\.id)
        Task { await reorder(topicIds: ids) }
    }

    private func reorder(topicIds: [String]) async {
        struct Body: Encodable {
            let topicIds: [String]
        }
        do {
            let _: [String: Bool] = try await api.put(
                "/api/queue/reorder",
                body: Body(topicIds: topicIds)
            )
            await loadSchedule()
        } catch {
            // Reload to fix state on failure
            await loadTopics()
        }
    }
}
