import SwiftUI
import SwiftTerm

/// UIViewRepresentable wrapper around SwiftTerm's TerminalView for use in SwiftUI.
struct SwiftTermView: UIViewRepresentable {
    typealias UIViewType = SwiftTerm.TerminalView

    let ssh: SSHConnection
    let colorScheme: ColorScheme
    var onSizeChange: ((Int, Int) -> Void)?

    func makeUIView(context: Context) -> SwiftTerm.TerminalView {
        let tv = SwiftTerm.TerminalView(frame: .zero)
        tv.translatesAutoresizingMaskIntoConstraints = false

        applyTheme(to: tv)

        let fontSize: CGFloat = 13
        tv.font = UIFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)

        tv.terminalDelegate = context.coordinator
        context.coordinator.terminalView = tv

        ssh.onDataReceived = { [weak coordinator = context.coordinator] data in
            coordinator?.feedData(data)
        }

        return tv
    }

    func updateUIView(_ uiView: SwiftTerm.TerminalView, context: Context) {
        context.coordinator.ssh = ssh
        context.coordinator.onSizeChange = onSizeChange
        applyTheme(to: uiView)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(ssh: ssh, onSizeChange: onSizeChange)
    }

    private func applyTheme(to tv: SwiftTerm.TerminalView) {
        if colorScheme == .dark {
            // Match app dark background #0A0A0F
            tv.nativeBackgroundColor = UIColor(red: 0x0A / 255.0, green: 0x0A / 255.0, blue: 0x0F / 255.0, alpha: 1)
            tv.nativeForegroundColor = UIColor(white: 0.9, alpha: 1)
        } else {
            // Light mode: dark terminal on light surface
            tv.nativeBackgroundColor = UIColor(red: 0xF0 / 255.0, green: 0xF0 / 255.0, blue: 0xF2 / 255.0, alpha: 1)
            tv.nativeForegroundColor = UIColor(red: 0x1A / 255.0, green: 0x1A / 255.0, blue: 0x1A / 255.0, alpha: 1)
        }
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
