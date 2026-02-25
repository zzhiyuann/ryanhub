import SwiftUI

@main
struct CortexApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .preferredColorScheme(appState.resolvedColorScheme)
        }
    }
}
