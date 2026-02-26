import Foundation
import SwiftUI
import os.log

private let termLog = Logger(subsystem: "com.zwang.ryanhub", category: "Terminal")

/// Represents a tmux session discovered on the remote host.
struct TmuxSession: Identifiable, Equatable {
    let id: String        // tmux session name (e.g. "cortex-a3f2")
    let windowCount: Int
    let createdAt: Date?
    let attached: Bool

    /// Display name: the tmux session name itself (which Claude Code renames to a task summary)
    var displayName: String { id }
}

/// ViewModel for the Terminal tab.
@MainActor @Observable
final class TerminalViewModel {
    // MARK: - Configuration (persisted)

    var sshHost: String {
        didSet { UserDefaults.standard.set(sshHost, forKey: Keys.sshHost) }
    }
    var sshPort: Int {
        didSet { UserDefaults.standard.set(sshPort, forKey: Keys.sshPort) }
    }
    var sshUsername: String {
        didSet { UserDefaults.standard.set(sshUsername, forKey: Keys.sshUsername) }
    }
    var sshPassword: String {
        didSet { UserDefaults.standard.set(sshPassword, forKey: Keys.sshPassword) }
    }

    // MARK: - State

    let ssh = SSHConnection()

    var tmuxSessions: [TmuxSession] = []
    var currentTmuxSession: String?
    var showSessionPicker = false
    var isLoadingSessions = false
    var errorMessage: String?

    /// Whether the SSH config has been set up at least once.
    var isConfigured: Bool {
        !sshHost.isEmpty && !sshUsername.isEmpty
    }

    // MARK: - Init

    init() {
        self.sshHost = UserDefaults.standard.string(forKey: Keys.sshHost) ?? "100.89.67.80"
        self.sshPort = UserDefaults.standard.object(forKey: Keys.sshPort) as? Int ?? 22
        self.sshUsername = UserDefaults.standard.string(forKey: Keys.sshUsername) ?? "zwang"
        self.sshPassword = UserDefaults.standard.string(forKey: Keys.sshPassword) ?? ""
    }

    // MARK: - Actions

    /// Connect to the remote host via SSH.
    func connect() {
        guard isConfigured else {
            errorMessage = "SSH not configured. Set host and username in Settings."
            return
        }

        ssh.connect(
            host: sshHost,
            port: sshPort,
            username: sshUsername,
            password: sshPassword
        )
    }

    /// Disconnect from the remote host.
    func disconnect() {
        ssh.disconnect()
        tmuxSessions = []
        currentTmuxSession = nil
    }

    /// Auto-enter tmux after SSH connects.
    /// Waits for shell prompt to be ready (via onShellReady callback), then sends tmux command.
    func autoEnterTmux() {
        guard ssh.isConnected else {
            debugLog("autoEnterTmux: SSH not connected, aborting")
            return
        }

        let shortId = UUID().uuidString.prefix(4).lowercased()
        let name = "claude-\(shortId)"

        debugLog("autoEnterTmux: registering onShellReady callback")

        // If shell data already arrived (shellReadyFired), send immediately.
        // Otherwise, register a callback for when the first shell data arrives.
        if ssh.shellReadyFired {
            debugLog("autoEnterTmux: shell already ready, sending now")
            sendTmuxEntry(name: name)
        } else {
            ssh.onShellReady = { [weak self] in
                debugLog("autoEnterTmux: shell ready callback fired, sending tmux command")
                // Small extra delay to let the prompt fully render
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    self?.sendTmuxEntry(name: name)
                }
            }
        }
    }

    /// Actually send the tmux entry command and detect session name.
    private func sendTmuxEntry(name: String) {
        guard ssh.isConnected else { return }
        debugLog("sendTmuxEntry: sending tmux command to shell")
        ssh.sendString("tmux attach 2>/dev/null || tmux new-session -s '\(name)' 'claude; zsh'\r")

        // Figure out which session we landed in
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.ssh.execCommand("tmux display-message -p '#{session_name}' 2>/dev/null") { output in
                DispatchQueue.main.async {
                    if let session = output?.trimmingCharacters(in: .whitespacesAndNewlines), !session.isEmpty {
                        self?.currentTmuxSession = session
                    } else {
                        self?.currentTmuxSession = name
                    }
                }
            }
        }
    }

    /// Kill a tmux session by name.
    func killTmuxSession(_ name: String) {
        let isCurrentSession = (currentTmuxSession == name)

        ssh.execCommand("tmux kill-session -t '\(name)'") { [weak self] _ in
            DispatchQueue.main.async {
                self?.tmuxSessions.removeAll { $0.id == name }

                if isCurrentSession {
                    // tmux auto-switches to next session, or exits if none left
                    // Refresh to find out what we landed on
                    self?.refreshTmuxSessions()
                    self?.currentTmuxSession = self?.tmuxSessions.first?.id
                }
            }
        }
    }

    /// List tmux sessions on the remote host via a separate exec channel (no terminal echo).
    func refreshTmuxSessions() {
        guard ssh.isConnected else { return }
        isLoadingSessions = true

        let command = "tmux ls -F '#{session_name}|#{session_windows}|#{session_created}|#{session_attached}' 2>/dev/null || true"

        ssh.execCommand(command) { [weak self] output in
            DispatchQueue.main.async {
                if let output {
                    self?.parseTmuxOutput(output)
                }
                self?.isLoadingSessions = false
            }
        }
    }

    /// Switch to a tmux session using tmux prefix key (works regardless of running program).
    func attachTmuxSession(_ name: String) {
        currentTmuxSession = name
        // Ctrl+B (tmux prefix) → : (command mode) → switch-client -t 'name' → Enter
        ssh.send(Data([0x02]))  // Ctrl+B
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            self?.ssh.sendString(":switch-client -t '\(name)'\r")
        }
    }

    /// Detach from current tmux session (Ctrl+B, d).
    func detachTmuxSession() {
        // tmux prefix key (Ctrl+B) then 'd'
        ssh.send(Data([0x02]))  // Ctrl+B
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.ssh.sendString("d")
            self?.currentTmuxSession = nil
        }
    }

    /// Create a new tmux session with Claude and switch to it.
    func newClaudeSession() {
        if currentTmuxSession != nil {
            // Already in tmux — create detached and switch via prefix key
            let shortId = UUID().uuidString.prefix(4).lowercased()
            let name = "claude-\(shortId)"

            ssh.execCommand("tmux new-session -d -s '\(name)' 'claude; zsh'") { [weak self] _ in
                DispatchQueue.main.async {
                    self?.currentTmuxSession = name
                    // Ctrl+B : switch-client (intercepted by tmux, not the running program)
                    self?.ssh.send(Data([0x02]))
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        self?.ssh.sendString(":switch-client -t '\(name)'\r")
                    }
                }
            }
        } else {
            // Not in tmux yet — send directly to shell
            createNewClaudeSession()
        }
    }

    /// Create a new Claude tmux session from the bare shell (initial setup).
    private func createNewClaudeSession() {
        let shortId = UUID().uuidString.prefix(4).lowercased()
        let name = "claude-\(shortId)"
        ssh.sendString("tmux new-session -s '\(name)' 'claude; zsh'\r")
        currentTmuxSession = name
    }

    // MARK: - Keyboard Shortcuts

    /// Send Ctrl+C (interrupt)
    func sendCtrlC() {
        ssh.send(Data([0x03]))
    }

    /// Send Tab (completion)
    func sendTab() {
        ssh.send(Data([0x09]))
    }

    /// Send Escape
    func sendEscape() {
        ssh.send(Data([0x1B]))
    }

    /// Send arrow up
    func sendArrowUp() {
        ssh.send(Data([0x1B, 0x5B, 0x41]))  // ESC [ A
    }

    /// Send arrow down
    func sendArrowDown() {
        ssh.send(Data([0x1B, 0x5B, 0x42]))  // ESC [ B
    }

    /// Send Ctrl+Z (suspend)
    func sendCtrlZ() {
        ssh.send(Data([0x1A]))
    }

    /// Send Ctrl+D (EOF)
    func sendCtrlD() {
        ssh.send(Data([0x04]))
    }

    /// Send Ctrl+L (clear screen)
    func sendCtrlL() {
        ssh.send(Data([0x0C]))
    }

    /// Send 'y' (yes - for confirmations)
    func sendY() {
        ssh.sendString("y")
    }

    /// Send 'n' (no - for confirmations)
    func sendN() {
        ssh.sendString("n")
    }

    /// Send '/' (search in less/vim)
    func sendSlash() {
        ssh.sendString("/")
    }

    /// Send 'q' (quit in less/vim)
    func sendQ() {
        ssh.sendString("q")
    }

    // MARK: - Private

    private func parseTmuxOutput(_ output: String) {
        var sessions: [TmuxSession] = []
        let lines = output.components(separatedBy: "\n")

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }

            let parts = trimmed.components(separatedBy: "|")
            guard parts.count >= 4 else { continue }

            let name = parts[0].trimmingCharacters(in: .whitespaces)
            let windows = Int(parts[1].trimmingCharacters(in: .whitespaces)) ?? 1
            let created: Date? = {
                if let ts = TimeInterval(parts[2].trimmingCharacters(in: .whitespaces)) {
                    return Date(timeIntervalSince1970: ts)
                }
                return nil
            }()
            let attached = parts[3].trimmingCharacters(in: .whitespaces) == "1"

            guard !name.isEmpty else { continue }

            sessions.append(TmuxSession(
                id: name,
                windowCount: windows,
                createdAt: created,
                attached: attached
            ))
        }

        tmuxSessions = sessions
    }

    // MARK: - Keys

    private enum Keys {
        static let sshHost = "ryanhub_ssh_host"
        static let sshPort = "ryanhub_ssh_port"
        static let sshUsername = "ryanhub_ssh_username"
        static let sshPassword = "ryanhub_ssh_password"
    }
}
