import SwiftUI
import UserNotifications

@main
struct RyanHubApp: App {
    @State private var appState = AppState()
    @State private var notificationManager = NotificationManager()
    @Environment(\.scenePhase) private var scenePhase

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
                    @unknown default:
                        break
                    }
                }
        }
    }
}
