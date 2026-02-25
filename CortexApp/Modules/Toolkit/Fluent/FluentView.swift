import SwiftUI
import WebKit

// MARK: - Fluent View

/// WebView wrapper that loads the Fluent PWA for English learning.
/// Supports back navigation, reload, open in Safari, and offline error handling.
struct FluentView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var viewModel = FluentViewModel()
    @State private var webView: WKWebView?

    var body: some View {
        ZStack {
            AdaptiveColors.background(for: colorScheme)
                .ignoresSafeArea()

            if viewModel.hasError {
                errorView
            } else {
                webViewContent
            }
        }
        .navigationTitle(viewModel.pageTitle ?? L10n.toolkitFluent)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                // Reload button
                Button {
                    webView?.reload()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .foregroundStyle(Color.cortexPrimary)
                }

                // Open in Safari
                Menu {
                    Button {
                        viewModel.openInSafari()
                    } label: {
                        Label("Open in Safari", systemImage: "safari")
                    }

                    Button {
                        viewModel.resetToHome()
                        webView?.load(URLRequest(url: viewModel.baseURL))
                    } label: {
                        Label("Go to Home", systemImage: "house")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(Color.cortexPrimary)
                }
            }
        }
    }

    // MARK: - WebView Content

    private var webViewContent: some View {
        ZStack(alignment: .top) {
            FluentWebView(url: viewModel.baseURL, viewModel: viewModel)
                .ignoresSafeArea(edges: .bottom)
                .overlay {
                    // Capture the webview reference for toolbar actions
                    WebViewFinder { foundWebView in
                        self.webView = foundWebView
                    }
                }

            // Loading progress bar
            if viewModel.isLoading {
                VStack(spacing: 0) {
                    ProgressView(value: viewModel.loadingProgress)
                        .progressViewStyle(.linear)
                        .tint(.cortexPrimary)
                }
            }
        }
    }

    // MARK: - Error View

    private var errorView: some View {
        VStack(spacing: 20) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))

            VStack(spacing: 8) {
                Text("Unable to Load")
                    .font(.cortexHeading)
                    .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))

                Text(viewModel.errorMessage ?? "Check your internet connection and try again.")
                    .font(.cortexBody)
                    .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            CortexButton("Try Again", icon: "arrow.clockwise") {
                viewModel.hasError = false
                viewModel.errorMessage = nil
                webView?.load(URLRequest(url: viewModel.baseURL))
            }
            .padding(.horizontal, 48)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - WebView Finder

/// Helper to find the WKWebView in the view hierarchy for toolbar actions.
/// This bridges between SwiftUI toolbar buttons and the UIKit webview.
private struct WebViewFinder: UIViewRepresentable {
    let onFound: (WKWebView) -> Void

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.isHidden = true
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        // Walk up the view hierarchy to find the WKWebView
        DispatchQueue.main.async {
            if let webView = findWebView(in: uiView) {
                onFound(webView)
            }
        }
    }

    private func findWebView(in view: UIView) -> WKWebView? {
        // Search siblings and parent's children
        guard let superview = view.superview else { return nil }
        return findWebViewRecursive(in: superview)
    }

    private func findWebViewRecursive(in view: UIView) -> WKWebView? {
        if let webView = view as? WKWebView {
            return webView
        }
        for subview in view.subviews {
            if let found = findWebViewRecursive(in: subview) {
                return found
            }
        }
        return nil
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        FluentView()
    }
}
