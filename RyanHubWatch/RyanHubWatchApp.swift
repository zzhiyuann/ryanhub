import SwiftUI

@main
struct RyanHubWatchApp: App {
    @State private var audioStreamer = WatchAudioStreamer()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(audioStreamer)
        }
    }
}
