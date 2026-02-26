import Foundation
import NIOCore
import NIOPosix
import NIOSSH
/// Manages an SSH connection with PTY shell to a remote host.
/// Based on SwiftTerm's iOS SSH example, adapted for password auth.
@MainActor @Observable
final class SSHConnection {
    // MARK: - State

    enum State: Equatable {
        case disconnected
        case connecting
        case connected
        case failed(String)
    }

    var state: State = .disconnected
    var isConnected: Bool { state == .connected }

    /// Callback when data arrives from the remote shell.
    var onDataReceived: ((Data) -> Void)?

    // MARK: - Private

    private var group: EventLoopGroup?
    private var channel: Channel?
    private var sessionChannel: Channel?

    // MARK: - Connection

    /// Connect to the remote host via SSH with password authentication.
    func connect(host: String, port: Int = 22, username: String, password: String) {
        guard state != .connecting else { return }
        state = .connecting

        let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        self.group = group

        let serverAuthDelegate = AcceptAllHostKeysDelegate()
        let userAuthDelegate = PasswordAuthDelegate(
            username: username,
            password: password
        )

        let bootstrap = ClientBootstrap(group: group)
            .channelInitializer { channel in
                channel.eventLoop.makeCompletedFuture {
                    let sshHandler = NIOSSHHandler(
                        role: .client(
                            .init(
                                userAuthDelegate: userAuthDelegate,
                                serverAuthDelegate: serverAuthDelegate
                            )
                        ),
                        allocator: channel.allocator,
                        inboundChildChannelInitializer: nil
                    )
                    try channel.pipeline.syncOperations.addHandler(sshHandler)
                    try channel.pipeline.syncOperations.addHandler(
                        SSHErrorHandler { [weak self] error in
                            DispatchQueue.main.async {
                                self?.handleError(error)
                            }
                        }
                    )
                }
            }
            .channelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
            .channelOption(ChannelOptions.socket(SocketOptionLevel(IPPROTO_TCP), TCP_NODELAY), value: 1)

        bootstrap.connect(host: host, port: port).whenComplete { [weak self] result in
            guard let self else { return }
            switch result {
            case .failure(let error):
                DispatchQueue.main.async {
                    self.state = .failed("Connect failed: \(error.localizedDescription)")
                    self.shutdownGroup()
                }
            case .success(let channel):
                DispatchQueue.main.async {
                    self.channel = channel
                    self.createSessionChannel(on: channel)
                }
            }
        }
    }

    /// Send raw bytes to the remote shell.
    func send(_ data: Data) {
        guard let sessionChannel else { return }
        sessionChannel.eventLoop.execute {
            var buffer = sessionChannel.allocator.buffer(capacity: data.count)
            buffer.writeBytes(data)
            let payload = SSHChannelData(type: .channel, data: .byteBuffer(buffer))
            sessionChannel.writeAndFlush(payload, promise: nil)
        }
    }

    /// Send a string to the remote shell.
    func sendString(_ string: String) {
        guard let data = string.data(using: .utf8) else { return }
        send(data)
    }

    /// Notify the remote of terminal window size change.
    func resizeTerminal(cols: Int, rows: Int) {
        guard cols > 0, rows > 0, let sessionChannel else { return }
        sessionChannel.eventLoop.execute {
            let event = SSHChannelRequestEvent.WindowChangeRequest(
                terminalCharacterWidth: cols,
                terminalRowHeight: rows,
                terminalPixelWidth: 0,
                terminalPixelHeight: 0
            )
            sessionChannel.triggerUserOutboundEvent(event, promise: nil)
        }
    }

    /// Disconnect from the remote host.
    func disconnect() {
        if let channel, let group {
            self.channel = nil
            self.sessionChannel = nil
            channel.closeFuture.whenComplete { [weak self] _ in
                self?.shutdownGroup()
            }
            channel.close(promise: nil)
        } else {
            shutdownGroup()
        }
        state = .disconnected
    }

    // MARK: - Private

    private func createSessionChannel(on channel: Channel) {
        channel.pipeline.handler(type: NIOSSHHandler.self).whenComplete { [weak self] result in
            guard let self else { return }
            switch result {
            case .failure(let error):
                DispatchQueue.main.async {
                    self.state = .failed("SSH handshake failed: \(error.localizedDescription)")
                }
            case .success(let sshHandler):
                let promise = channel.eventLoop.makePromise(of: Channel.self)
                sshHandler.createChannel(promise, channelType: .session) { [weak self] childChannel, channelType in
                    guard let self else {
                        return channel.eventLoop.makeFailedFuture(SSHSessionError.invalidChannel)
                    }
                    guard channelType == .session else {
                        return channel.eventLoop.makeFailedFuture(SSHSessionError.invalidChannel)
                    }

                    return childChannel.eventLoop.makeCompletedFuture {
                        let handler = SSHShellHandler(
                            onData: { [weak self] data in
                                DispatchQueue.main.async {
                                    self?.onDataReceived?(data)
                                }
                            },
                            onExit: { [weak self] status in
                                DispatchQueue.main.async {
                                    self?.state = .disconnected
                                }
                            }
                        )
                        try childChannel.pipeline.syncOperations.addHandler(handler)
                        try childChannel.pipeline.syncOperations.addHandler(
                            SSHErrorHandler { [weak self] error in
                                DispatchQueue.main.async {
                                    self?.handleError(error)
                                }
                            }
                        )
                    }
                }

                promise.futureResult.whenComplete { [weak self] result in
                    guard let self else { return }
                    DispatchQueue.main.async {
                        switch result {
                        case .failure(let error):
                            self.state = .failed("Channel failed: \(error.localizedDescription)")
                        case .success(let childChannel):
                            self.sessionChannel = childChannel
                            self.state = .connected

                            // Request PTY + shell
                            childChannel.eventLoop.execute {
                                let pty = SSHChannelRequestEvent.PseudoTerminalRequest(
                                    wantReply: false,
                                    term: "xterm-256color",
                                    terminalCharacterWidth: 80,
                                    terminalRowHeight: 24,
                                    terminalPixelWidth: 0,
                                    terminalPixelHeight: 0,
                                    terminalModes: SSHTerminalModes([:])
                                )
                                childChannel.triggerUserOutboundEvent(pty, promise: nil)

                                let env = SSHChannelRequestEvent.EnvironmentRequest(
                                    wantReply: false,
                                    name: "LANG",
                                    value: "en_US.UTF-8"
                                )
                                childChannel.triggerUserOutboundEvent(env, promise: nil)

                                childChannel.triggerUserOutboundEvent(
                                    SSHChannelRequestEvent.ShellRequest(wantReply: false),
                                    promise: nil
                                )
                            }
                        }
                    }
                }
            }
        }
    }

    private func handleError(_ error: Error) {
        if state != .disconnected {
            state = .failed(error.localizedDescription)
        }
    }

    private func shutdownGroup() {
        if let group {
            self.group = nil
            group.shutdownGracefully { _ in }
        }
    }

}

// MARK: - SSH Helper Types

enum SSHSessionError: LocalizedError {
    case invalidChannel

    var errorDescription: String? {
        switch self {
        case .invalidChannel: return "Invalid SSH channel type"
        }
    }
}

/// Accepts all host keys (suitable for trusted local network connections).
private final class AcceptAllHostKeysDelegate: NIOSSHClientServerAuthenticationDelegate {
    func validateHostKey(
        hostKey: NIOSSHPublicKey,
        validationCompletePromise: EventLoopPromise<Void>
    ) {
        validationCompletePromise.succeed(())
    }
}

/// Password authentication delegate.
private final class PasswordAuthDelegate: NIOSSHClientUserAuthenticationDelegate {
    private let username: String
    private let password: String

    init(username: String, password: String) {
        self.username = username
        self.password = password
    }

    func nextAuthenticationType(
        availableMethods: NIOSSHAvailableUserAuthenticationMethods,
        nextChallengePromise: EventLoopPromise<NIOSSHUserAuthenticationOffer?>
    ) {
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

/// Handles incoming SSH channel data (shell output) and lifecycle events.
private final class SSHShellHandler: ChannelInboundHandler {
    typealias InboundIn = SSHChannelData

    private let onData: (Data) -> Void
    private let onExit: (Int) -> Void

    init(onData: @escaping (Data) -> Void, onExit: @escaping (Int) -> Void) {
        self.onData = onData
        self.onExit = onExit
    }

    func handlerAdded(context: ChannelHandlerContext) {
        context.channel.setOption(ChannelOptions.allowRemoteHalfClosure, value: true)
            .whenFailure { error in
                context.fireErrorCaught(error)
            }
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let payload = unwrapInboundIn(data)
        guard case .byteBuffer(var buffer) = payload.data else { return }
        guard let bytes = buffer.readBytes(length: buffer.readableBytes), !bytes.isEmpty else { return }
        onData(Data(bytes))
    }

    func userInboundEventTriggered(context: ChannelHandlerContext, event: Any) {
        if let status = event as? SSHChannelRequestEvent.ExitStatus {
            onExit(status.exitStatus)
        } else {
            context.fireUserInboundEventTriggered(event)
        }
    }
}

/// Catches SSH errors and forwards them to a handler.
private final class SSHErrorHandler: ChannelInboundHandler {
    typealias InboundIn = Any

    private let onError: (Error) -> Void

    init(onError: @escaping (Error) -> Void) {
        self.onError = onError
    }

    func errorCaught(context: ChannelHandlerContext, error: Error) {
        onError(error)
        context.close(promise: nil)
    }
}
