import Foundation

/// Main view model for the Book Factory library — handles book list, search, audio generation status.
@MainActor @Observable
final class BookFactoryViewModel {
    var books: [Book] = []
    var isLoading = false
    var error: String?
    var search = ""
    var generatingAudio: [String: AudioProgress] = [:]
    var newBooksBanner: String?

    struct AudioProgress {
        var progress: Double
        var chunksReady: Int
        var chunksTotal: Int
    }

    let api: BookFactoryAPI
    private var refreshTask: Task<Void, Never>?
    private var pollingTasks: [String: Task<Void, Never>] = [:]

    init(api: BookFactoryAPI) {
        self.api = api
    }

    // MARK: - Computed Properties

    var filteredBooks: [Book] {
        if search.isEmpty { return books }
        let q = search.lowercased()
        return books.filter {
            $0.title.lowercased().contains(q) ||
            ($0.topic?.lowercased().contains(q) ?? false) ||
            $0.date.contains(q)
        }
    }

    var filteredCount: Int { filteredBooks.count }

    var groupedBooks: [(date: String, books: [Book])] {
        let grouped = Dictionary(grouping: filteredBooks, by: { $0.date })
        return grouped.keys.sorted(by: >).map { (date: $0, books: grouped[$0] ?? []) }
    }

    // MARK: - Data Loading

    func loadBooks() async {
        let previousCount = books.count
        isLoading = true
        error = nil
        do {
            let response: BooksResponse = try await api.get("/api/books")
            books = response.books
            // Check for in-progress audio jobs
            for book in books where !book.hasAudioBool {
                await checkAudioStatus(bookId: book.id)
            }
            // Show banner for newly synced books
            let newCount = books.count - previousCount
            if previousCount > 0 && newCount > 0 {
                newBooksBanner = "\(newCount) new book\(newCount > 1 ? "s" : "") synced"
                Task {
                    try? await Task.sleep(for: .seconds(3))
                    newBooksBanner = nil
                }
            }
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func startBackgroundRefresh() {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60))
                guard !Task.isCancelled, let self else { return }
                await self.loadBooks()
            }
        }
    }

    func stopBackgroundRefresh() {
        refreshTask?.cancel()
        refreshTask = nil
    }

    // MARK: - Audio Generation

    func checkAudioStatus(bookId: String) async {
        do {
            let status: AudioStatus = try await api.get("/api/audiobook/\(bookId)/status")
            if status.status == "processing" {
                generatingAudio[bookId] = AudioProgress(
                    progress: status.progress ?? 0,
                    chunksReady: status.chunksReady ?? 0,
                    chunksTotal: status.chunksTotal ?? 0
                )
                startPolling(bookId: bookId)
            }
        } catch {
            // ignore — book may simply have no audio
        }
    }

    func generateAudio(bookId: String, mode: String = "long") async {
        generatingAudio[bookId] = AudioProgress(progress: 0, chunksReady: 0, chunksTotal: 0)
        do {
            struct Body: Encodable { let bookId: String; let mode: String }
            let response: GenerateAudioResponse = try await api.post(
                "/api/audiobook/generate",
                body: Body(bookId: bookId, mode: mode)
            )
            generatingAudio[bookId] = AudioProgress(
                progress: 0,
                chunksReady: 0,
                chunksTotal: response.chunksTotal
            )
            startPolling(bookId: bookId)
        } catch {
            generatingAudio.removeValue(forKey: bookId)
            self.error = error.localizedDescription
        }
    }

    // MARK: - Polling

    private func startPolling(bookId: String) {
        pollingTasks[bookId]?.cancel()
        pollingTasks[bookId] = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                guard !Task.isCancelled, let self else { return }
                do {
                    let status: AudioStatus = try await self.api.get("/api/audiobook/\(bookId)/status")
                    if status.status == "done" {
                        self.generatingAudio.removeValue(forKey: bookId)
                        self.pollingTasks.removeValue(forKey: bookId)
                        await self.loadBooks()
                        return
                    }
                    if status.status == "error" {
                        self.generatingAudio.removeValue(forKey: bookId)
                        self.pollingTasks.removeValue(forKey: bookId)
                        self.error = status.error ?? "Audio generation failed"
                        return
                    }
                    self.generatingAudio[bookId] = AudioProgress(
                        progress: status.progress ?? 0,
                        chunksReady: status.chunksReady ?? 0,
                        chunksTotal: status.chunksTotal ?? 0
                    )
                } catch {
                    // retry on next cycle
                }
            }
        }
    }

    func stopPolling() {
        for task in pollingTasks.values { task.cancel() }
        pollingTasks.removeAll()
    }
}
