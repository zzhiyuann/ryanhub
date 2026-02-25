import SwiftUI

/// Entry point for the Book Factory toolkit module.
/// Shows a tabbed interface with library, queue, and settings.
struct BookFactoryView: View {
    @Environment(\.colorScheme) private var colorScheme

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
        VStack(spacing: CortexLayout.sectionSpacing) {
            Spacer()

            Image(systemName: "books.vertical.fill")
                .font(.system(size: 56))
                .foregroundStyle(Color.cortexPrimary)

            Text("Book Factory")
                .font(.cortexTitle)
                .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))

            Text("Configure your server to get started")
                .font(.cortexBody)
                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))

            BookFactoryServerSetup(api: api) {
                initializeViewModels()
                Task {
                    await libraryVM?.loadBooks()
                    libraryVM?.startBackgroundRefresh()
                }
            }
            .padding(.horizontal, CortexLayout.standardPadding)

            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AdaptiveColors.background(for: colorScheme))
    }

    // MARK: - Main Content

    private var mainContent: some View {
        VStack(spacing: 0) {
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

            // Mini player above tab bar
            MiniPlayerView()

            // Tab bar
            tabBar
        }
        .background(AdaptiveColors.background(for: colorScheme))
        .task {
            await libraryVM?.loadBooks()
            libraryVM?.startBackgroundRefresh()
        }
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(BookFactoryTab.allCases, id: \.self) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 20))
                        Text(tab.rawValue)
                            .font(.caption2)
                    }
                    .foregroundStyle(
                        selectedTab == tab
                            ? Color.cortexPrimary
                            : AdaptiveColors.textSecondary(for: colorScheme)
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 4)
        .background(AdaptiveColors.surface(for: colorScheme))
        .overlay(alignment: .top) {
            AdaptiveColors.border(for: colorScheme)
                .frame(height: 0.5)
        }
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
        VStack(spacing: CortexLayout.itemSpacing) {
            CortexTextField(placeholder: "Server address (e.g. 192.168.1.100:3443)", text: $urlText)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)

            CortexTextField(placeholder: "Username", text: $username)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)

            CortexTextField(placeholder: "Password", text: $password, isSecure: true)

            if let error = connectionError {
                Text(error)
                    .font(.cortexCaption)
                    .foregroundStyle(Color.cortexAccentRed)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            CortexButton("Connect", icon: "arrow.right", isLoading: isConnecting) {
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
