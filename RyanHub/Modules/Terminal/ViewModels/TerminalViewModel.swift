import Foundation
import SwiftUI

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

    /// Attach to a tmux session.
    func attachTmuxSession(_ name: String) {
        currentTmuxSession = name
        ssh.sendString("tmux attach -t '\(name)'\n")
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

    /// Create a new tmux session and run claude inside it.
    func newClaudeSession() {
        let shortId = UUID().uuidString.prefix(4).lowercased()
        let name = "new-\(shortId)"

        // Create detached session via exec channel (no echo in terminal)
        ssh.execCommand("tmux new-session -d -s '\(name)' 'claude; zsh'") { [weak self] _ in
            DispatchQueue.main.async {
                // Attach via interactive shell
                self?.ssh.sendString("tmux attach -t '\(name)'\n")
                self?.currentTmuxSession = name
            }
        }
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
