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

        // Replace default accessory with shortcut bar
        let coordinator = context.coordinator
        let accessoryBar = ShortcutAccessoryView { data in
            Task { @MainActor in
                coordinator.ssh.send(data)
            }
        }
        accessoryBar.isDark = colorScheme == .dark
        tv.inputAccessoryView = accessoryBar

        return tv
    }

    func updateUIView(_ uiView: SwiftTerm.TerminalView, context: Context) {
        context.coordinator.ssh = ssh
        context.coordinator.onSizeChange = onSizeChange
        applyTheme(to: uiView)

        if let accessory = uiView.inputAccessoryView as? ShortcutAccessoryView {
            accessory.isDark = colorScheme == .dark
        }
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

// MARK: - Shortcut Accessory View

/// Keyboard accessory toolbar with terminal shortcut keys.
/// Appears above the system keyboard when the terminal is focused.
final class ShortcutAccessoryView: UIView {
    private let onSend: (Data) -> Void
    private let blurView = UIVisualEffectView()
    private var buttons: [UIButton] = []

    var isDark: Bool = true {
        didSet { updateAppearance() }
    }

    init(onSend: @escaping (Data) -> Void) {
        self.onSend = onSend
        super.init(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 40))
        autoresizingMask = .flexibleWidth
        setupUI()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupUI() {
        // Blur background matching keyboard
        blurView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(blurView)
        NSLayoutConstraint.activate([
            blurView.topAnchor.constraint(equalTo: topAnchor),
            blurView.bottomAnchor.constraint(equalTo: bottomAnchor),
            blurView.leadingAnchor.constraint(equalTo: leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])

        // Top separator
        let separator = UIView()
        separator.translatesAutoresizingMaskIntoConstraints = false
        separator.backgroundColor = UIColor.separator
        addSubview(separator)
        NSLayoutConstraint.activate([
            separator.topAnchor.constraint(equalTo: topAnchor),
            separator.leadingAnchor.constraint(equalTo: leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: trailingAnchor),
            separator.heightAnchor.constraint(equalToConstant: 0.5),
        ])

        // Scroll view for buttons
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.alwaysBounceHorizontal = true
        addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor, constant: 1),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])

        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .horizontal
        stack.spacing = 6
        stack.alignment = .center
        scrollView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 8),
            stack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -8),
            stack.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor),
        ])

        // Shortcut definitions: (label, bytes, accent color or nil for default)
        let shortcuts: [(String, Data, UIColor?)] = [
            ("C-c", Data([0x03]), .systemRed),
            ("Tab", Data([0x09]), nil),
            ("\u{2191}", Data([0x1B, 0x5B, 0x41]), nil),
            ("\u{2193}", Data([0x1B, 0x5B, 0x42]), nil),
            ("Esc", Data([0x1B]), nil),
            ("C-z", Data([0x1A]), nil),
            ("C-d", Data([0x04]), nil),
            ("C-l", Data([0x0C]), nil),
            ("y", "y".data(using: .utf8)!, .systemGreen),
            ("n", "n".data(using: .utf8)!, .systemRed),
            ("/", "/".data(using: .utf8)!, nil),
            ("q", "q".data(using: .utf8)!, nil),
        ]

        for (label, data, accent) in shortcuts {
            let btn = makeButton(title: label, data: data, accent: accent)
            stack.addArrangedSubview(btn)
            buttons.append(btn)
        }

        updateAppearance()
    }

    private func makeButton(title: String, data: Data, accent: UIColor?) -> UIButton {
        var config = UIButton.Configuration.filled()
        config.title = title
        config.cornerStyle = .medium
        config.contentInsets = NSDirectionalEdgeInsets(top: 5, leading: 10, bottom: 5, trailing: 10)
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var out = incoming
            out.font = UIFont.monospacedSystemFont(ofSize: 12, weight: .semibold)
            return out
        }

        let btn = UIButton(configuration: config)
        btn.tag = buttons.count
        btn.addAction(UIAction { [weak self] _ in
            self?.onSend(data)
        }, for: .touchUpInside)

        // Store accent color for theme updates
        btn.accessibilityHint = accent != nil ? "accent" : nil
        if let accent {
            btn.tintColor = accent
        }

        return btn
    }

    private func updateAppearance() {
        blurView.effect = UIBlurEffect(style: isDark ? .dark : .light)

        for btn in buttons {
            var config = btn.configuration ?? .filled()
            if btn.accessibilityHint == "accent" {
                // Keep accent-colored buttons as-is
                config.baseBackgroundColor = btn.tintColor.withAlphaComponent(isDark ? 0.2 : 0.15)
                config.baseForegroundColor = btn.tintColor
            } else {
                config.baseBackgroundColor = isDark
                    ? UIColor.white.withAlphaComponent(0.1)
                    : UIColor.black.withAlphaComponent(0.06)
                config.baseForegroundColor = isDark
                    ? UIColor.white.withAlphaComponent(0.7)
                    : UIColor.black.withAlphaComponent(0.6)
            }
            btn.configuration = config
        }
    }
}
