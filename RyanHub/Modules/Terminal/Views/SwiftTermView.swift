import SwiftUI
import SwiftTerm

/// UIViewRepresentable wrapper around SwiftTerm's TerminalView for use in SwiftUI.
struct SwiftTermView: UIViewRepresentable {
    typealias UIViewType = SwiftTerm.TerminalView

    /// The SSH connection to pipe input/output through.
    let ssh: SSHConnection
    /// Called when terminal size changes (cols, rows).
    var onSizeChange: ((Int, Int) -> Void)?

    func makeUIView(context: Context) -> SwiftTerm.TerminalView {
        let tv = SwiftTerm.TerminalView(frame: .zero)
        tv.translatesAutoresizingMaskIntoConstraints = false

        // Dark theme with good contrast
        tv.nativeForegroundColor = .init(white: 0.9, alpha: 1)
        tv.nativeBackgroundColor = .init(red: 0.04, green: 0.04, blue: 0.06, alpha: 1)

        // Font: use a readable monospace size
        let fontSize: CGFloat = 13
        tv.font = UIFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)

        // Set delegate for user input
        tv.terminalDelegate = context.coordinator

        // Store reference so we can feed data later
        context.coordinator.terminalView = tv

        // Wire up SSH data → terminal display
        ssh.onDataReceived = { [weak coordinator = context.coordinator] data in
            coordinator?.feedData(data)
        }

        return tv
    }

    func updateUIView(_ uiView: SwiftTerm.TerminalView, context: Context) {
        context.coordinator.ssh = ssh
        context.coordinator.onSizeChange = onSizeChange
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(ssh: ssh, onSizeChange: onSizeChange)
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, SwiftTerm.TerminalViewDelegate {
        var ssh: SSHConnection
        var onSizeChange: ((Int, Int) -> Void)?
        weak var terminalView: SwiftTerm.TerminalView?

        init(ssh: SSHConnection, onSizeChange: ((Int, Int) -> Void)?) {
            self.ssh = ssh
            self.onSizeChange = onSizeChange
            super.init()
        }

        func feedData(_ data: Data) {
            guard let tv = terminalView else { return }
            let bytes = Array(data)
            tv.feed(byteArray: bytes[bytes.startIndex...])
        }

        // MARK: - TerminalViewDelegate

        func send(source: SwiftTerm.TerminalView, data: ArraySlice<UInt8>) {
            let payload = Data(data)
            Task { @MainActor in
                ssh.send(payload)
            }
        }

        func sizeChanged(source: SwiftTerm.TerminalView, newCols: Int, newRows: Int) {
            onSizeChange?(newCols, newRows)
            Task { @MainActor in
                ssh.resizeTerminal(cols: newCols, rows: newRows)
            }
        }

        func setTerminalTitle(source: SwiftTerm.TerminalView, title: String) {}
        func scrolled(source: SwiftTerm.TerminalView, position: Double) {}
        func hostCurrentDirectoryUpdate(source: SwiftTerm.TerminalView, directory: String?) {}
        func requestOpenLink(source: SwiftTerm.TerminalView, link: String, params: [String: String]) {}
        func bell(source: SwiftTerm.TerminalView) {}
        func rangeChanged(source: SwiftTerm.TerminalView, startY: Int, endY: Int) {}

        func clipboardCopy(source: SwiftTerm.TerminalView, content: Data) {
            if let str = String(data: content, encoding: .utf8) {
                UIPasteboard.general.string = str
            }
        }

        func iTermContent(source: SwiftTerm.TerminalView, content: ArraySlice<UInt8>) {}
    }
}
