import SwiftUI
import WebKit

/// Full-screen book reader that loads and displays book content as styled HTML.
/// Automatically starts audio playback if the book has audio.
struct BookReaderView: View {
    let book: Book

    @Environment(\.colorScheme) private var colorScheme
    @Environment(BookFactoryAPI.self) private var api
    @Environment(AudioPlayerViewModel.self) private var audioPlayer

    @State private var htmlContent: String = ""
    @State private var isLoading = true
    @State private var error: String?

    var body: some View {
        Group {
            if isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Loading...")
                        .font(.cortexCaption)
                        .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error {
                ContentUnavailableView {
                    Label("Error", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(error)
                }
            } else {
                BookHTMLWebView(html: htmlContent, colorScheme: colorScheme)
            }
        }
        .background(AdaptiveColors.background(for: colorScheme))
        .navigationTitle(book.title)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadBookContent()

            // Auto-start audio if book has audio and not already playing this book
            if book.hasAudioBool && audioPlayer.currentBook?.id != book.id {
                await audioPlayer.startPlaying(bookId: book.id, title: book.title)
            }
        }
    }

    private func loadBookContent() async {
        isLoading = true
        error = nil
        do {
            let html = try await api.getString("/api/books/\(book.id)/content?format=html")
            htmlContent = wrapHTML(html, title: book.title)
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    /// Wraps raw HTML content in a styled page that adapts to light/dark mode.
    private func wrapHTML(_ body: String, title: String) -> String {
        // Use Cortex design system colors for the reader
        let darkBg = "#0A0A0F"
        let lightBg = "#F5F5F7"
        let darkText = "#E5E5E5"
        let lightText = "#1A1A1A"
        let accentColor = "#6366F1"

        return """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1">
        <style>
        :root {
            color-scheme: light dark;
        }
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, 'Noto Serif SC', Georgia, serif;
            font-size: 17px;
            line-height: 1.8;
            color: \(lightText);
            background: \(lightBg);
            padding: 20px 16px 80px 16px;
            -webkit-text-size-adjust: 100%;
        }
        @media (prefers-color-scheme: dark) {
            body { color: \(darkText); background: \(darkBg); }
            h1, h2, h3 { color: #F5F5F5; }
            blockquote { border-color: #555; color: #9CA3AF; }
            code { background: #252540; }
            pre { background: #1C1C2E; }
        }
        h1 { font-size: 1.6em; margin: 1.2em 0 0.6em; font-weight: 700; }
        h2 { font-size: 1.3em; margin: 1em 0 0.5em; font-weight: 600; }
        h3 { font-size: 1.1em; margin: 0.8em 0 0.4em; font-weight: 600; }
        p { margin: 0.8em 0; }
        ul, ol { margin: 0.8em 0; padding-left: 1.5em; }
        li { margin: 0.3em 0; }
        blockquote {
            border-left: 3px solid \(accentColor);
            padding: 0.5em 1em;
            margin: 1em 0;
            color: #6B7280;
            font-style: italic;
        }
        code {
            background: #F0F0F2;
            padding: 0.15em 0.4em;
            border-radius: 3px;
            font-size: 0.9em;
        }
        pre {
            background: #F0F0F2;
            padding: 1em;
            border-radius: 8px;
            overflow-x: auto;
            margin: 1em 0;
        }
        pre code { background: none; padding: 0; }
        hr { border: none; border-top: 1px solid rgba(0,0,0,0.06); margin: 2em 0; }
        @media (prefers-color-scheme: dark) {
            hr { border-color: rgba(255,255,255,0.08); }
        }
        img { max-width: 100%; height: auto; border-radius: 8px; }
        table { border-collapse: collapse; width: 100%; margin: 1em 0; }
        th, td { border: 1px solid #ddd; padding: 0.5em; text-align: left; font-size: 0.9em; }
        @media (prefers-color-scheme: dark) {
            th, td { border-color: rgba(255,255,255,0.08); }
        }
        </style>
        </head>
        <body>
        \(body)
        </body>
        </html>
        """
    }
}

// MARK: - WKWebView Wrapper

struct BookHTMLWebView: UIViewRepresentable {
    let html: String
    let colorScheme: ColorScheme

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.contentInsetAdjustmentBehavior = .always
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        webView.loadHTMLString(html, baseURL: nil)
    }
}
