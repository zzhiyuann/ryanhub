import SwiftUI

/// Entry point for the Book Factory toolkit module.
/// Shows a tabbed interface with library, queue, and settings.
struct BookFactoryView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(AppState.self) private var appState

    @State private var api = BookFactoryAPI()
    @State private var libraryVM: BookFactoryViewModel?
    @State private var audioPlayerVM: AudioPlayerViewModel?
    @State private var queueVM: QueueViewModel?
    @State private var selectedTab: BookFactoryTab = .library

    enum BookFactoryTab: String, CaseIterable {
        case library = "Library"
        case queue = "Queue"
        case settings = "Settings"

        var icon: String {
            switch self {
            case .library: return "books.vertical"
            case .queue: return "list.bullet.clipboard"
            case .settings: return "gearshape"
            }
        }
    }

    var body: some View {
        Group {
            if api.baseURL.isEmpty {
                serverSetupView
            } else if let libraryVM, let audioPlayerVM, let queueVM {
                mainContent
                    .environment(api)
                    .environment(libraryVM)
                    .environment(audioPlayerVM)
                    .environment(queueVM)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(AdaptiveColors.background(for: colorScheme))
            }
        }
        .task {
            initializeViewModels()
        }
    }

    // MARK: - Server Setup (first launch)

    private var serverSetupView: some View {
        VStack(spacing: HubLayout.sectionSpacing) {
            Spacer()

            Image(systemName: "books.vertical.fill")
                .font(.system(size: 56))
                .foregroundStyle(Color.hubPrimary)

            Text("Book Factory")
                .font(.hubTitle)
                .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))

            Text("Configure your server to get started")
                .font(.hubBody)
                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))

            BookFactoryServerSetup(api: api) {
                initializeViewModels()
                Task {
                    await libraryVM?.loadBooks()
                    libraryVM?.startBackgroundRefresh()
                }
            }
            .padding(.horizontal, HubLayout.standardPadding)

            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AdaptiveColors.background(for: colorScheme))
    }

    // MARK: - Main Content

    private var mainContent: some View {
        ZStack(alignment: .bottom) {
            // Content fills the full area
            Group {
                switch selectedTab {
                case .library:
                    BookLibraryView()
                case .queue:
                    QueueManagerView()
                case .settings:
                    BookFactorySettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Mini player (floats above bubble bar)
            VStack(spacing: 8) {
                MiniPlayerView()
                    .padding(.horizontal, HubLayout.standardPadding)

                // Floating bubble tab bar — hidden when reading a book
                if !appState.isReadingBook {
                    floatingBubbleBar
                        .transition(.scale(scale: 0.8).combined(with: .opacity))
                }
            }
            .padding(.bottom, 8)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: appState.isReadingBook)
        }
        .background(AdaptiveColors.background(for: colorScheme))
        .task {
            await libraryVM?.loadBooks()
            libraryVM?.startBackgroundRefresh()
        }
    }

    // MARK: - Floating Bubble Bar

    private var floatingBubbleBar: some View {
        HStack(spacing: 4) {
            ForEach(BookFactoryTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = tab
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 14, weight: .medium))

                        if selectedTab == tab {
                            Text(tab.rawValue)
                                .font(.system(size: 13, weight: .semibold))
                                .transition(.scale(scale: 0.5).combined(with: .opacity))
                        }
                    }
                    .foregroundStyle(
                        selectedTab == tab
                            ? .white
                            : AdaptiveColors.textSecondary(for: colorScheme)
                    )
                    .padding(.horizontal, selectedTab == tab ? 14 : 10)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(selectedTab == tab ? Color.hubPrimary : Color.clear)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(AdaptiveColors.surface(for: colorScheme))
                .shadow(
                    color: colorScheme == .dark ? Color.black.opacity(0.4) : Color.black.opacity(0.12),
                    radius: 12,
                    x: 0,
                    y: 4
                )
        )
        .overlay(
            Capsule()
                .stroke(AdaptiveColors.border(for: colorScheme), lineWidth: 0.5)
        )
    }

    // MARK: - Helpers

    private func initializeViewModels() {
        guard libraryVM == nil else { return }
        let library = BookFactoryViewModel(api: api)
        let audio = AudioPlayerViewModel(api: api)
        let queue = QueueViewModel(api: api)
        libraryVM = library
        audioPlayerVM = audio
        queueVM = queue
    }
}

// MARK: - Server Setup Component

struct BookFactoryServerSetup: View {
    @Environment(\.colorScheme) private var colorScheme
    let api: BookFactoryAPI
    let onSaved: () -> Void

    @State private var urlText = ""
    @State private var username = ""
    @State private var password = ""
    @State private var isConnecting = false
    @State private var connectionError: String?

    var body: some View {
        VStack(spacing: HubLayout.itemSpacing) {
            HubTextField(placeholder: "Server address (e.g. 192.168.1.100:3443)", text: $urlText)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)

            HubTextField(placeholder: "Username", text: $username)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)

            HubTextField(placeholder: "Password", text: $password, isSecure: true)

            if let error = connectionError {
                Text(error)
                    .font(.hubCaption)
                    .foregroundStyle(Color.hubAccentRed)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            HubButton("Connect", icon: "arrow.right", isLoading: isConnecting) {
                Task { await connect() }
            }
            .disabled(urlText.isEmpty || username.isEmpty || password.isEmpty)
        }
    }

    private func connect() async {
        isConnecting = true
        connectionError = nil

        api.saveServerURL(urlText)

        do {
            let _ = try await api.login(username: username, password: password)
            onSaved()
        } catch {
            connectionError = error.localizedDescription
        }

        isConnecting = false
    }
}

#Preview {
    BookFactoryView()
}
