import SwiftUI
import MWDATCore

struct RBMetaView: View {
    @State private var viewModel = RBMetaViewModel()
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            AdaptiveColors.background(for: colorScheme)
                .ignoresSafeArea()

            if viewModel.isStreaming {
                activeSessionView
            } else {
                idleView
            }
        }
        .onAppear {
            do {
                try Wearables.configure()
            } catch {
                // Already configured or unavailable — safe to ignore
            }
            viewModel.setupDAT(wearables: Wearables.shared)
            // Import any RB Meta photos/videos from Photo Library
            RBMetaMediaImporter.shared.importNewMedia()
        }
        .onOpenURL { url in
            guard
                let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                components.queryItems?.contains(where: { $0.name == "metaWearablesAction" }) == true
            else { return }
            Task {
                await viewModel.handleDATCallback(url: url)
            }
        }
        .alert("Error", isPresented: .init(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    // MARK: - Idle View

    private var idleView: some View {
        ScrollView {
            VStack(spacing: HubLayout.sectionSpacing) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "eyeglasses")
                        .font(.system(size: 48))
                        .foregroundStyle(Color.hubPrimary)
                    Text("RB Meta")
                        .font(.hubTitle)
                        .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                    Text("AI-powered smart glasses assistant")
                        .font(.hubCaption)
                        .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                }
                .padding(.top, 32)

                // Status cards
                VStack(spacing: HubLayout.itemSpacing) {
                    statusCard(
                        title: "Gemini Live",
                        status: RBMetaConfig.isConfigured ? "Configured" : "No API Key",
                        color: RBMetaConfig.isConfigured ? .hubAccentGreen : .hubAccentRed,
                        icon: "sparkles"
                    )

                    statusCard(
                        title: "OpenClaw",
                        status: RBMetaConfig.isOpenClawConfigured ? "Configured" : "Not Configured",
                        color: RBMetaConfig.isOpenClawConfigured ? .hubAccentGreen : .gray,
                        icon: "arrow.triangle.branch"
                    )

                    statusCard(
                        title: "Ray-Ban Meta",
                        status: glassesStatusText,
                        color: glassesStatusColor,
                        icon: "eyeglasses"
                    )
                }
                .padding(.horizontal, HubLayout.standardPadding)

                // Action buttons
                VStack(spacing: HubLayout.itemSpacing) {
                    HubButton("Start with iPhone Camera", isLoading: false) {
                        Task {
                            await viewModel.startIPhoneCamera()
                        }
                    }

                    if viewModel.hasActiveDevice {
                        HubButton("Start with Glasses", isLoading: false) {
                            Task {
                                await viewModel.startGlassesStreaming()
                            }
                        }
                    } else if viewModel.isRegistered {
                        HubSecondaryButton("Waiting for Glasses...") {}
                    } else {
                        HubSecondaryButton(viewModel.isRegistering ? "Connecting..." : "Connect Glasses") {
                            viewModel.connectGlasses()
                        }
                    }
                }
                .padding(.horizontal, HubLayout.standardPadding)

                // Info
                HubCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("How to use")
                            .font(.hubHeading)
                            .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))

                        infoRow(icon: "1.circle.fill", text: "Start a camera session (iPhone or glasses)")
                        infoRow(icon: "2.circle.fill", text: "Tap the AI button to connect Gemini")
                        infoRow(icon: "3.circle.fill", text: "Talk naturally — it sees what you see")
                        infoRow(icon: "4.circle.fill", text: "Ask it to do things via OpenClaw")
                    }
                    .padding(HubLayout.standardPadding)
                }
                .padding(.horizontal, HubLayout.standardPadding)
            }
            .padding(.bottom, 32)
        }
    }

    // MARK: - Active Session View

    private var activeSessionView: some View {
        ZStack {
            // Camera feed background
            if let frame = viewModel.currentVideoFrame {
                Image(uiImage: frame)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .ignoresSafeArea()
            } else {
                Color.black.ignoresSafeArea()
                VStack {
                    ProgressView()
                        .tint(.white)
                    Text("Waiting for video...")
                        .font(.hubCaption)
                        .foregroundStyle(.white.opacity(0.7))
                }
            }

            // Overlay
            VStack {
                // Top: status pills
                HStack(spacing: 8) {
                    geminiPill
                    openClawPill
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                Spacer()

                // Middle: transcripts
                VStack(spacing: 8) {
                    if !viewModel.userTranscript.isEmpty || !viewModel.aiTranscript.isEmpty {
                        transcriptOverlay
                    }

                    if viewModel.toolCallStatus != .idle {
                        toolCallOverlay
                    }
                }
                .padding(.horizontal, 16)

                // Bottom: controls
                HStack(spacing: 20) {
                    // Stop streaming
                    controlButton(icon: "xmark", color: .hubAccentRed) {
                        Task {
                            await viewModel.stopAll()
                        }
                    }

                    // Photo capture (glasses mode only)
                    if viewModel.streamingMode == .glasses {
                        controlButton(icon: "camera.fill", color: Color.hubPrimary) {
                            viewModel.captureGlassesPhoto()
                        }
                    }

                    Spacer()

                    // Speaking indicator
                    if viewModel.isModelSpeaking {
                        RBSpeakingIndicator()
                            .frame(width: 40, height: 24)
                    }

                    Spacer()

                    // AI toggle
                    controlButton(
                        icon: viewModel.isGeminiActive ? "sparkles" : "sparkles",
                        color: viewModel.isGeminiActive ? .hubAccentGreen : Color.hubPrimary
                    ) {
                        Task {
                            if viewModel.isGeminiActive {
                                viewModel.stopGeminiSession()
                            } else {
                                await viewModel.startGeminiSession()
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
            }
        }
    }

    // MARK: - Components

    private func statusCard(title: String, status: String, color: Color, icon: String) -> some View {
        HubCard {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(color)
                    .frame(width: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.hubBody)
                        .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                    Text(status)
                        .font(.hubCaption)
                        .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                }

                Spacer()

                Circle()
                    .fill(color)
                    .frame(width: 10, height: 10)
            }
            .padding(HubLayout.standardPadding)
        }
    }

    private func infoRow(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(Color.hubPrimary)
                .frame(width: 24)
            Text(text)
                .font(.hubCaption)
                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
        }
    }

    private var geminiPill: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(geminiStatusColor)
                .frame(width: 8, height: 8)
            Text(geminiStatusText)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.black.opacity(0.6))
        .cornerRadius(16)
    }

    private var openClawPill: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(openClawStatusColor)
                .frame(width: 8, height: 8)
            Text(openClawStatusText)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.black.opacity(0.6))
        .cornerRadius(16)
    }

    private var transcriptOverlay: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !viewModel.userTranscript.isEmpty {
                Text(viewModel.userTranscript)
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.7))
            }
            if !viewModel.aiTranscript.isEmpty {
                Text(viewModel.aiTranscript)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.6))
        .cornerRadius(12)
    }

    private var toolCallOverlay: some View {
        HStack(spacing: 8) {
            toolCallIcon
            Text(viewModel.toolCallStatus.displayText)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white)
                .lineLimit(1)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(toolCallBackground)
        .cornerRadius(16)
    }

    @ViewBuilder
    private var toolCallIcon: some View {
        switch viewModel.toolCallStatus {
        case .executing:
            ProgressView()
                .scaleEffect(0.7)
                .tint(.white)
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.system(size: 14))
        case .failed:
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(.red)
                .font(.system(size: 14))
        case .cancelled:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.yellow)
                .font(.system(size: 14))
        case .idle:
            EmptyView()
        }
    }

    private var toolCallBackground: Color {
        switch viewModel.toolCallStatus {
        case .executing: return Color.black.opacity(0.7)
        case .completed: return Color.black.opacity(0.6)
        case .failed: return Color.red.opacity(0.3)
        case .cancelled: return Color.black.opacity(0.6)
        case .idle: return Color.clear
        }
    }

    private func controlButton(icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(color.opacity(0.8))
                .clipShape(Circle())
        }
    }

    // MARK: - Status helpers

    private var geminiStatusColor: Color {
        switch viewModel.geminiConnectionState {
        case .ready: return .green
        case .connecting, .settingUp: return .yellow
        case .error: return .red
        case .disconnected: return .gray
        }
    }

    private var geminiStatusText: String {
        switch viewModel.geminiConnectionState {
        case .ready: return "Gemini"
        case .connecting, .settingUp: return "Gemini..."
        case .error: return "Error"
        case .disconnected: return "Gemini Off"
        }
    }

    private var openClawStatusColor: Color {
        switch viewModel.openClawConnectionState {
        case .connected: return .green
        case .checking: return .yellow
        case .unreachable: return .red
        case .notConfigured: return .gray
        }
    }

    private var openClawStatusText: String {
        switch viewModel.openClawConnectionState {
        case .connected: return "OpenClaw"
        case .checking: return "OpenClaw..."
        case .unreachable: return "OpenClaw Off"
        case .notConfigured: return "No OpenClaw"
        }
    }

    private var glassesStatusText: String {
        if viewModel.hasActiveDevice { return "Connected" }
        if viewModel.isRegistered { return "Registered" }
        if viewModel.isRegistering { return "Connecting..." }
        return "Not Connected"
    }

    private var glassesStatusColor: Color {
        if viewModel.hasActiveDevice { return .hubAccentGreen }
        if viewModel.isRegistered { return .hubAccentYellow }
        if viewModel.isRegistering { return .hubAccentYellow }
        return .gray
    }
}

// MARK: - Speaking Indicator

struct RBSpeakingIndicator: View {
    @State private var animating = false

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<4, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Color.white)
                    .frame(width: 3, height: animating ? CGFloat.random(in: 8...20) : 6)
                    .animation(
                        .easeInOut(duration: 0.3)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.1),
                        value: animating
                    )
            }
        }
        .onAppear { animating = true }
        .onDisappear { animating = false }
    }
}
