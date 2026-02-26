import Foundation
import NIOCore
import NIOPosix
import NIOSSH

/// ViewModel for the Settings module.
@MainActor @Observable
final class SettingsViewModel {
    // MARK: - State

    var isTesting: Bool = false
    var testResultIcon: String?
    var serverURLWarning: String?

    var isTestingSSH: Bool = false
    var sshTestResultIcon: String?
    var sshTestError: String?
    // MARK: - Computed

    var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    // MARK: - Public API

    func loadFromAppState(_ appState: AppState) {
        validateServerURL(appState.serverURL)
    }

    /// Validate WebSocket URL format and update warning message.
    func validateServerURL(_ url: String) {
        let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            serverURLWarning = nil
            return
        }
        if !trimmed.hasPrefix("ws://") && !trimmed.hasPrefix("wss://") {
            serverURLWarning = "URL must start with ws:// or wss://"
        } else if URL(string: trimmed) == nil {
            serverURLWarning = "Invalid URL format"
        } else {
            serverURLWarning = nil
        }
    }

    /// Test WebSocket connection to the given URL.
    func testConnection(url: String) {
        guard !isTesting else { return }
        isTesting = true
        testResultIcon = nil

        let client = WebSocketClient()
        Task {
            let success = await client.testConnection(to: url)
            self.isTesting = false
            self.testResultIcon = success ? "checkmark.circle.fill" : "xmark.circle.fill"

            // Reset icon after 3 seconds
            Task {
                try? await Task.sleep(for: .seconds(3))
                self.testResultIcon = nil
            }
        }
    }

    /// Test SSH connection with current settings.
    func testSSHConnection() {
        guard !isTestingSSH else { return }
        isTestingSSH = true
        sshTestResultIcon = nil
        sshTestError = nil

        let host = UserDefaults.standard.string(forKey: "ryanhub_ssh_host") ?? ""
        let username = UserDefaults.standard.string(forKey: "ryanhub_ssh_username") ?? ""
        let password = UserDefaults.standard.string(forKey: "ryanhub_ssh_password") ?? ""
        let port = UserDefaults.standard.object(forKey: "ryanhub_ssh_port") as? Int ?? 22

        guard !host.isEmpty, !username.isEmpty else {
            isTestingSSH = false
            sshTestResultIcon = "xmark.circle.fill"
            sshTestError = "Host and username are required"
            return
        }

        let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        let authDelegate = TestPasswordAuthDelegate(username: username, password: password)
        let hostKeyDelegate = TestAcceptAllHostKeysDelegate()

        let bootstrap = ClientBootstrap(group: group)
            .channelInitializer { channel in
                channel.eventLoop.makeCompletedFuture {
                    let sshHandler = NIOSSHHandler(
                        role: .client(
                            .init(
                                userAuthDelegate: authDelegate,
                                serverAuthDelegate: hostKeyDelegate
                            )
                        ),
                        allocator: channel.allocator,
                        inboundChildChannelInitializer: nil
                    )
                    try channel.pipeline.syncOperations.addHandler(sshHandler)
                }
            }
            .connectTimeout(.seconds(8))

        bootstrap.connect(host: host, port: port).whenComplete { [weak self] result in
            switch result {
            case .failure(let error):
                DispatchQueue.main.async {
                    self?.isTestingSSH = false
                    self?.sshTestResultIcon = "xmark.circle.fill"
                    self?.sshTestError = error.localizedDescription
                    group.shutdownGracefully { _ in }
                }
            case .success(let channel):
                // TCP connected, now verify SSH auth by opening a session channel
                channel.pipeline.handler(type: NIOSSHHandler.self).whenComplete { [weak self] pipeResult in
                    switch pipeResult {
                    case .failure(let error):
                        DispatchQueue.main.async {
                            self?.isTestingSSH = false
                            self?.sshTestResultIcon = "xmark.circle.fill"
                            self?.sshTestError = error.localizedDescription
                        }
                        channel.close(promise: nil)
                        group.shutdownGracefully { _ in }
                    case .success(let sshHandler):
                        let promise = channel.eventLoop.makePromise(of: Channel.self)
                        sshHandler.createChannel(promise, channelType: .session) { childChannel, _ in
                            childChannel.eventLoop.makeSucceededVoidFuture()
                        }
                        promise.futureResult.whenComplete { [weak self] chResult in
                            DispatchQueue.main.async {
                                self?.isTestingSSH = false
                                switch chResult {
                                case .success(let childChannel):
                                    self?.sshTestResultIcon = "checkmark.circle.fill"
                                    childChannel.close(promise: nil)
                                case .failure(let error):
                                    self?.sshTestResultIcon = "xmark.circle.fill"
                                    self?.sshTestError = "Auth failed: \(error.localizedDescription)"
                                }
                            }
                            channel.close(promise: nil)
                            group.shutdownGracefully { _ in }
                        }
                    }
                }
            }
        }

        // Reset icon after 5 seconds
        Task {
            try? await Task.sleep(for: .seconds(5))
            self.sshTestResultIcon = nil
            self.sshTestError = nil
        }
    }
}

// MARK: - SSH Test Helpers (local to settings)

private final class TestPasswordAuthDelegate: NIOSSHClientUserAuthenticationDelegate {
    private let username: String
    private let password: String
    private var triedOnce = false

    init(username: String, password: String) {
        self.username = username
        self.password = password
    }

    func nextAuthenticationType(
        availableMethods: NIOSSHAvailableUserAuthenticationMethods,
        nextChallengePromise: EventLoopPromise<NIOSSHUserAuthenticationOffer?>
    ) {
        guard !triedOnce else {
            nextChallengePromise.succeed(nil)
            return
        }
        triedOnce = true
        guard availableMethods.contains(.password) else {
            nextChallengePromise.succeed(nil)
            return
        }
        nextChallengePromise.succeed(NIOSSHUserAuthenticationOffer(
            username: username,
            serviceName: "",
            offer: .password(.init(password: password))
        ))
    }
}

private final class TestAcceptAllHostKeysDelegate: NIOSSHClientServerAuthenticationDelegate {
    func validateHostKey(hostKey: NIOSSHPublicKey, validationCompletePromise: EventLoopPromise<Void>) {
        validationCompletePromise.succeed(())
    }
}
