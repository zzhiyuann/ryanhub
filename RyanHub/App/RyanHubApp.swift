import SwiftUI
import UserNotifications
import BackgroundTasks

@main
struct RyanHubApp: App {
    @State private var appState = AppState()
    @State private var notificationManager = NotificationManager()
    @Environment(\.scenePhase) private var scenePhase

    /// Background task identifier for BOBO periodic sync.
    private static let boboSyncTaskID = "com.zwang.ryanhub.bobo-sync"

    init() {
        // Register all dynamically generated toolkit modules
        DynamicModuleRegistry.bootstrapAll()

        // Activate WatchConnectivity session early for Watch mic streaming
        _ = WatchSessionManager.shared

        // Register BGTaskScheduler for BOBO background sync
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.boboSyncTaskID,
            using: nil
        ) { task in
            guard let refreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            Self.handleBackgroundSync(task: refreshTask)
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .environment(notificationManager)
                .preferredColorScheme(appState.resolvedColorScheme)
                .task {
                    // Set up notification delegate
                    UNUserNotificationCenter.current().delegate = notificationManager
                    // Request notification permission on first launch
                    await notificationManager.requestPermission()
                }
                .onReceive(NotificationCenter.default.publisher(for: .didReceiveDeepLink)) { notification in
                    if let deepLink = notification.userInfo?["deepLink"] as? DeepLink {
                        appState.pendingDeepLink = deepLink
                    }
                }
                .onChange(of: scenePhase) { _, newPhase in
                    switch newPhase {
                    case .active:
                        appState.isAppInForeground = true
                        notificationManager.clearBadge()
                    case .inactive, .background:
                        appState.isAppInForeground = false
                        if newPhase == .background {
                            Self.scheduleBackgroundSync()
                        }
                    @unknown default:
                        break
                    }
                }
        }
    }

    // MARK: - Background Sync

    /// Schedule the next background app refresh for BOBO sync.
    static func scheduleBackgroundSync() {
        let request = BGAppRefreshTaskRequest(identifier: boboSyncTaskID)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 minutes
        do {
            try BGTaskScheduler.shared.submit(request)
            print("[RyanHubApp] Scheduled background BOBO sync")
        } catch {
            print("[RyanHubApp] Failed to schedule background sync: \(error.localizedDescription)")
        }
    }

    /// Handle a background sync task: backfill data, sync pending events,
    /// and push fresh HealthKit data to the bridge server.
    private static func handleBackgroundSync(task: BGAppRefreshTask) {
        // Schedule the next refresh before doing work
        scheduleBackgroundSync()

        let syncTask = Task { @MainActor in
            let engine = SensingEngine.shared
            await engine.handleBackgroundWake()
            await generateNudgesInBackground()
        }

        // If the system cancels the task, cancel our async work
        task.expirationHandler = {
            syncTask.cancel()
        }

        Task {
            _ = await syncTask.result
            task.setTaskCompleted(success: true)
        }
    }

    // MARK: - Background Nudge Generation

    /// Bridge server base URL (same logic as BoboViewModel).
    private static var bridgeBaseURL: String {
        UserDefaults.standard.string(forKey: "ryanhub_server_url")
            .flatMap { URL(string: $0)?.host }
            .map { "http://\($0):18790" }
            ?? AppState.defaultFoodAnalysisURL
    }

    /// Ask the bridge server to generate nudges if enough time has elapsed.
    /// Sends a local notification for each nudge returned.
    @MainActor
    private static func generateNudgesInBackground() async {
        let endpoint = "\(bridgeBaseURL)/bobo/nudge-check"
        guard let url = URL(string: endpoint) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data("{}".utf8)
        request.timeoutInterval = 60

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode) else { return }

            struct NudgeCheckResponse: Decodable {
                let ok: Bool
                let nudges: [BackgroundNudge]?
                let skipped: Bool?
            }
            struct BackgroundNudge: Decodable {
                let id: String
                let content: String
                let type: String
            }

            let result = try JSONDecoder().decode(NudgeCheckResponse.self, from: data)
            guard let nudges = result.nudges, !nudges.isEmpty else { return }

            // Send a local notification for each nudge
            for nudge in nudges {
                let content = UNMutableNotificationContent()
                content.title = "Bo"
                content.body = nudge.content
                content.sound = .default
                content.userInfo = ["destination": "bobo"]

                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
                let request = UNNotificationRequest(
                    identifier: nudge.id,
                    content: content,
                    trigger: trigger
                )
                try? await UNUserNotificationCenter.current().add(request)
            }

            print("[RyanHubApp] Background nudge check: \(nudges.count) nudges generated")
        } catch {
            print("[RyanHubApp] Background nudge check failed: \(error.localizedDescription)")
        }
    }
}
