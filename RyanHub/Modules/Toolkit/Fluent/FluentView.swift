import SwiftUI
import WebKit

// MARK: - Fluent View

/// WebView wrapper that loads the Fluent PWA for English learning.
/// Features: progress bar, back/forward navigation, pull-to-refresh,
/// dark mode support, error handling with retry, and overflow menu.
struct FluentView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var viewModel = FluentViewModel()

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
            // Leading: back/forward navigation
            ToolbarItemGroup(placement: .topBarLeading) {
                HStack(spacing: 4) {
                    Button {
                        viewModel.shouldReload = false
                        // Go back via JavaScript — simpler than holding a webview ref
                        goBackAction()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(
                                viewModel.canGoBack
                                    ? Color.hubPrimary
                                    : AdaptiveColors.textSecondary(for: colorScheme).opacity(0.4)
                            )
                    }
                    .disabled(!viewModel.canGoBack)

                    Button {
                        goForwardAction()
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(
                                viewModel.canGoForward
                                    ? Color.hubPrimary
                                    : AdaptiveColors.textSecondary(for: colorScheme).opacity(0.4)
                            )
                    }
                    .disabled(!viewModel.canGoForward)
                }
            }

            // Trailing: reload + overflow menu
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    viewModel.reload()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color.hubPrimary)
                }

                Menu {
                    Button {
                        viewModel.resetToHome()
                    } label: {
                        Label("Go to Home", systemImage: "house")
                    }

                    Divider()

                    Button {
                        viewModel.openInSafari()
                    } label: {
                        Label("Open in Safari", systemImage: "safari")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color.hubPrimary)
                }
            }
        }
    }

    // MARK: - WebView Content

    private var webViewContent: some View {
        ZStack(alignment: .top) {
            FluentWebView(
                url: viewModel.baseURL,
                viewModel: viewModel,
                colorScheme: colorScheme
            )
            .ignoresSafeArea(edges: .bottom)

            // Loading progress bar at the top
            if viewModel.isLoading {
                ProgressView(value: viewModel.loadingProgress)
                    .progressViewStyle(.linear)
                    .tint(Color.hubPrimary)
                    .animation(.easeInOut(duration: 0.2), value: viewModel.loadingProgress)
            }
        }
    }

    // MARK: - Error View

    private var errorView: some View {
        VStack(spacing: HubLayout.sectionSpacing) {
            Spacer()

            // Error icon
            ZStack {
                Circle()
                    .fill(AdaptiveColors.surface(for: colorScheme))
                    .frame(width: 96, height: 96)
                    .shadow(
                        color: Color.hubPrimary.opacity(0.1),
                        radius: 20, x: 0, y: 8
                    )

                Image(systemName: "wifi.exclamationmark")
                    .font(.system(size: 36, weight: .light))
                    .foregroundStyle(Color.hubPrimary)
            }

            // Error text
            VStack(spacing: HubLayout.itemSpacing) {
                Text("Unable to Load")
                    .font(.hubHeading)
                    .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))

                Text(viewModel.errorMessage ?? "Check your internet connection and try again.")
                    .font(.hubBody)
                    .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, HubLayout.standardPadding * 2)
            }

            // Retry + Home buttons
            VStack(spacing: HubLayout.itemSpacing) {
                HubButton("Try Again", icon: "arrow.clockwise") {
                    viewModel.retry()
                }

                HubSecondaryButton("Go to Home", icon: "house") {
                    viewModel.resetToHome()
                }
            }
            .padding(.horizontal, HubLayout.standardPadding * 3)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Navigation Helpers

    /// Trigger back navigation via the coordinator's stored webview reference.
    private func goBackAction() {
        // Post a notification that the coordinator will handle
        NotificationCenter.default.post(name: .fluentGoBack, object: nil)
    }

    /// Trigger forward navigation via the coordinator's stored webview reference.
    private func goForwardAction() {
        NotificationCenter.default.post(name: .fluentGoForward, object: nil)
    }
}

// MARK: - Navigation Notifications

extension Notification.Name {
    static let fluentGoBack = Notification.Name("FluentGoBack")
    static let fluentGoForward = Notification.Name("FluentGoForward")
}

// MARK: - Extended Coordinator for Navigation Notifications

extension FluentWebView.Coordinator {
    /// Subscribe to back/forward navigation notifications from the toolbar.
    func subscribeToNavigationNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleGoBack),
            name: .fluentGoBack,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleGoForward),
            name: .fluentGoForward,
            object: nil
        )
    }

    @objc private func handleGoBack() {
        webView?.goBack()
    }

    @objc private func handleGoForward() {
        webView?.goForward()
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        FluentView()
    }
}
