import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        TabView {
            ChatView()
                .tabItem {
                    Label(L10n.tabChat, systemImage: "bubble.left.and.bubble.right.fill")
                }

            ToolkitHomeView()
                .tabItem {
                    Label(L10n.tabToolkit, systemImage: "square.grid.2x2.fill")
                }

            SettingsView()
                .tabItem {
                    Label(L10n.tabSettings, systemImage: "gearshape.fill")
                }
        }
        .tint(.cortexPrimary)
    }
}

#Preview {
    ContentView()
        .environment(AppState())
}
