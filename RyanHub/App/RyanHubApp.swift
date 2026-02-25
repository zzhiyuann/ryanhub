import SwiftUI

@main
struct RyanHubApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .preferredColorScheme(appState.resolvedColorScheme)
        }
    }
}
