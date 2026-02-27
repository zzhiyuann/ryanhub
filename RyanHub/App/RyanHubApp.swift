import SwiftUI
import UserNotifications
import BackgroundTasks

@main
struct RyanHubApp: App {
    @State private var appState = AppState()
    @State private var notificationManager = NotificationManager()
    @Environment(\.scenePhase) private var scenePhase

    /// Background task identifier for POPO periodic sync.
    private static let popoSyncTaskID = "com.zwang.ryanhub.popo-sync"

    init() {
        // Register BGTaskScheduler for POPO background sync
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.popoSyncTaskID,
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

    /// Schedule the next background app refresh for POPO sync.
    static func scheduleBackgroundSync() {
        let request = BGAppRefreshTaskRequest(identifier: popoSyncTaskID)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 minutes
        do {
            try BGTaskScheduler.shared.submit(request)
            print("[RyanHubApp] Scheduled background POPO sync")
        } catch {
            print("[RyanHubApp] Failed to schedule background sync: \(error.localizedDescription)")
        }
    }

    /// Handle a background sync task: backfill data and sync pending events.
    private static func handleBackgroundSync(task: BGAppRefreshTask) {
        // Schedule the next refresh before doing work
        scheduleBackgroundSync()

        let syncTask = Task { @MainActor in
            let engine = SensingEngine.shared
            await engine.handleBackgroundWake()
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
}
