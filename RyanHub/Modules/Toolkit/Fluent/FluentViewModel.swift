import Foundation
import UIKit
import WebKit
import SwiftUI

// MARK: - Fluent View Model

/// Manages the state of the Fluent PWA WebView.
/// Tracks loading progress, navigation state, errors, and provides actions
/// for reload, back/forward navigation, and opening in Safari.
@Observable
final class FluentViewModel {
    // MARK: - State

    var isLoading = true
    var currentURL: URL?
    var canGoBack = false
    var canGoForward = false
    var pageTitle: String?
    var loadingProgress: Double = 0
    var hasError = false
    var errorMessage: String?

    /// Whether a reload was triggered (used to coordinate with the WebView representable).
    var shouldReload = false

    /// Whether we should navigate to home (used to coordinate with the WebView representable).
    var shouldNavigateHome = false

    // MARK: - Configuration

    /// The base URL of the Fluent PWA.
    let baseURL = URL(string: "https://fluent-eta.vercel.app/")!

    /// Whether the webview has finished initial load at least once.
    var hasLoadedOnce = false

    // MARK: - Actions

    /// Reset the webview to the base URL.
    func resetToHome() {
        hasError = false
        errorMessage = nil
        shouldNavigateHome = true
    }

    /// Reload the current page.
    func reload() {
        hasError = false
        errorMessage = nil
        shouldReload = true
    }

    /// Retry after an error by loading the base URL.
    func retry() {
        hasError = false
        errorMessage = nil
        shouldNavigateHome = true
    }

    /// Open the current URL in Safari.
    func openInSafari() {
        guard let url = currentURL ?? Optional(baseURL) else { return }
        UIApplication.shared.open(url)
    }
}

// MARK: - Fluent WebView (UIViewRepresentable)

/// WKWebView wrapper for loading the Fluent PWA.
/// Supports pull-to-refresh, dark mode background adaptation, KVO-based progress tracking,
/// and coordinated navigation actions from the parent SwiftUI view.
struct FluentWebView: UIViewRepresentable {
    let url: URL
    let viewModel: FluentViewModel
    let colorScheme: ColorScheme

    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        config.defaultWebpagePreferences.allowsContentJavaScript = true

        // Allow media playback without user gesture (for potential audio features)
        config.mediaTypesRequiringUserActionForPlayback = []

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.isOpaque = false
        webView.underPageBackgroundColor = uiBackgroundColor(for: colorScheme)
        webView.backgroundColor = uiBackgroundColor(for: colorScheme)
        webView.scrollView.backgroundColor = uiBackgroundColor(for: colorScheme)

        // Enable pull-to-refresh on the scroll view
        let refreshControl = UIRefreshControl()
        refreshControl.tintColor = UIColor(Color.hubPrimary)
        refreshControl.addTarget(
            context.coordinator,
            action: #selector(Coordinator.handlePullToRefresh(_:)),
            for: .valueChanged
        )
        webView.scrollView.refreshControl = refreshControl

        // Store reference in coordinator for later actions
        context.coordinator.webView = webView

        // Observe loading progress and navigation state
        context.coordinator.observeWebView(webView)

        // Subscribe to back/forward notifications from the toolbar
        context.coordinator.subscribeToNavigationNotifications()

        // Load the URL
        let request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad)
        webView.load(request)

        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        // Update background color when color scheme changes
        let bgColor = uiBackgroundColor(for: colorScheme)
        webView.underPageBackgroundColor = bgColor
        webView.backgroundColor = bgColor
        webView.scrollView.backgroundColor = bgColor

        // Handle reload request from view model
        if viewModel.shouldReload {
            viewModel.shouldReload = false
            webView.reload()
        }

        // Handle navigate-to-home request from view model
        if viewModel.shouldNavigateHome {
            viewModel.shouldNavigateHome = false
            let request = URLRequest(url: viewModel.baseURL)
            webView.load(request)
        }
    }

    /// Returns the appropriate UIColor for the WebView background based on color scheme.
    private func uiBackgroundColor(for scheme: ColorScheme) -> UIColor {
        scheme == .dark
            ? UIColor(red: 0x0A / 255.0, green: 0x0A / 255.0, blue: 0x0F / 255.0, alpha: 1)
            : UIColor(red: 0xF5 / 255.0, green: 0xF5 / 255.0, blue: 0xF7 / 255.0, alpha: 1)
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, WKNavigationDelegate {
        let viewModel: FluentViewModel
        weak var webView: WKWebView?
        private var progressObservation: NSKeyValueObservation?
        private var titleObservation: NSKeyValueObservation?
        private var canGoBackObservation: NSKeyValueObservation?
        private var canGoForwardObservation: NSKeyValueObservation?
        private var urlObservation: NSKeyValueObservation?

        init(viewModel: FluentViewModel) {
            self.viewModel = viewModel
        }

        func observeWebView(_ webView: WKWebView) {
            progressObservation = webView.observe(\.estimatedProgress) { [weak self] webView, _ in
                Task { @MainActor in
                    self?.viewModel.loadingProgress = webView.estimatedProgress
                }
            }

            titleObservation = webView.observe(\.title) { [weak self] webView, _ in
                Task { @MainActor in
                    self?.viewModel.pageTitle = webView.title
                }
            }

            canGoBackObservation = webView.observe(\.canGoBack) { [weak self] webView, _ in
                Task { @MainActor in
                    self?.viewModel.canGoBack = webView.canGoBack
                }
            }

            canGoForwardObservation = webView.observe(\.canGoForward) { [weak self] webView, _ in
                Task { @MainActor in
                    self?.viewModel.canGoForward = webView.canGoForward
                }
            }

            urlObservation = webView.observe(\.url) { [weak self] webView, _ in
                Task { @MainActor in
                    self?.viewModel.currentURL = webView.url
                }
            }
        }

        /// Handle pull-to-refresh gesture.
        @objc func handlePullToRefresh(_ sender: UIRefreshControl) {
            webView?.reload()
            // End refreshing after a short delay to allow navigation delegate to take over
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                sender.endRefreshing()
            }
        }

        // MARK: - WKNavigationDelegate

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            Task { @MainActor in
                viewModel.isLoading = true
                viewModel.hasError = false
                viewModel.errorMessage = nil
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            Task { @MainActor in
                viewModel.isLoading = false
                viewModel.hasLoadedOnce = true
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            Task { @MainActor in
                viewModel.isLoading = false
                // Ignore cancelled navigations
                let nsError = error as NSError
                if nsError.code != NSURLErrorCancelled {
                    viewModel.hasError = true
                    viewModel.errorMessage = error.localizedDescription
                }
            }
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            Task { @MainActor in
                viewModel.isLoading = false
                let nsError = error as NSError
                if nsError.code != NSURLErrorCancelled {
                    viewModel.hasError = true
                    viewModel.errorMessage = error.localizedDescription
                }
            }
        }
    }
}
