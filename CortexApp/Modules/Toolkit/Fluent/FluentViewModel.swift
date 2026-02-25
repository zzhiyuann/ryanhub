import Foundation
import WebKit

// MARK: - Fluent View Model

/// Manages the state of the Fluent PWA WebView.
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

    // MARK: - Configuration

    /// The base URL of the Fluent PWA.
    let baseURL = URL(string: "https://fluent-gilt.vercel.app/")!

    /// Whether the webview has finished initial load at least once.
    var hasLoadedOnce = false

    // MARK: - Actions

    /// Reset the webview to the base URL.
    func resetToHome() {
        currentURL = baseURL
        hasError = false
        errorMessage = nil
    }

    /// Open the current URL in Safari.
    func openInSafari() {
        guard let url = currentURL ?? Optional(baseURL) else { return }
        UIApplication.shared.open(url)
    }
}

// MARK: - Fluent WebView (UIViewRepresentable)

import SwiftUI

/// WKWebView wrapper for loading the Fluent PWA.
struct FluentWebView: UIViewRepresentable {
    let url: URL
    let viewModel: FluentViewModel

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
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear

        // Observe loading progress
        context.coordinator.observeWebView(webView)

        // Load the URL
        let request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad)
        webView.load(request)

        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        // If the URL changed externally (e.g., reset to home), reload
        if let currentURL = viewModel.currentURL,
           currentURL != webView.url,
           currentURL == viewModel.baseURL {
            let request = URLRequest(url: currentURL)
            webView.load(request)
        }
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, WKNavigationDelegate {
        let viewModel: FluentViewModel
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
