import SwiftUI
import WebKit

/// Full-screen book reader that loads and displays book content as styled HTML.
/// Automatically starts audio playback if the book has audio.
struct BookReaderView: View {
    let book: Book

    @Environment(\.colorScheme) private var colorScheme
    @Environment(BookFactoryAPI.self) private var api
    @Environment(AudioPlayerViewModel.self) private var audioPlayer
    @Environment(AppState.self) private var appState

    @State private var rawHTML: String = ""
    @State private var isLoading = true
    @State private var error: String?

    var body: some View {
        Group {
            if isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Loading...")
                        .font(.hubCaption)
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
                BookHTMLWebView(html: wrapHTML(rawHTML), colorScheme: colorScheme)
            }
        }
        .background(AdaptiveColors.background(for: colorScheme))
        .navigationTitle(book.title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { appState.isReadingBook = true }
        .onDisappear { appState.isReadingBook = false }
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
            rawHTML = try await api.getString("/api/books/\(book.id)/content?format=html")
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    /// Wraps raw HTML content in a styled page. Colors are set directly based on
    /// the current colorScheme — no CSS media queries, so dark mode always works.
    private func wrapHTML(_ body: String) -> String {
        let isDark = colorScheme == .dark

        let bgColor = isDark ? "#0A0A0F" : "#F5F5F7"
        let textColor = isDark ? "#E0E0E5" : "#1A1A1A"
        let headingColor = isDark ? "#F5F5F7" : "#111111"
        let subheadingColor = isDark ? "#C8C8D0" : "#333333"
        let mutedColor = isDark ? "#9CA3AF" : "#6B7280"
        let surfaceColor = isDark ? "#1C1C2E" : "#FFFFFF"
        let codeBg = isDark ? "#252540" : "#F0F0F2"
        let borderColor = isDark ? "rgba(255,255,255,0.08)" : "rgba(0,0,0,0.06)"
        let accentColor = "#6366F1"
        let linkColor = isDark ? "#818CF8" : "#6366F1"

        return """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no">
        <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }

        body {
            font-family: -apple-system, 'SF Pro Text', 'Noto Serif SC', Georgia, serif;
            font-size: 17px;
            line-height: 1.75;
            color: \(textColor);
            background: \(bgColor);
            padding: 16px 14px 100px 14px;
            -webkit-text-size-adjust: 100%;
            word-wrap: break-word;
            overflow-wrap: break-word;
        }

        /* Headings */
        h1 {
            font-size: 1.5em;
            font-weight: 700;
            color: \(headingColor);
            margin: 1.4em 0 0.5em;
            line-height: 1.3;
            letter-spacing: -0.01em;
        }
        h2 {
            font-size: 1.25em;
            font-weight: 600;
            color: \(headingColor);
            margin: 1.2em 0 0.4em;
            line-height: 1.35;
        }
        h3 {
            font-size: 1.1em;
            font-weight: 600;
            color: \(subheadingColor);
            margin: 1em 0 0.35em;
            line-height: 1.4;
        }
        h4, h5, h6 {
            font-size: 1em;
            font-weight: 600;
            color: \(subheadingColor);
            margin: 0.8em 0 0.3em;
        }

        /* First heading — no top margin */
        body > h1:first-child,
        body > h2:first-child {
            margin-top: 0.3em;
        }

        /* Body text */
        p {
            margin: 0.7em 0;
        }

        /* Lists */
        ul, ol {
            margin: 0.6em 0;
            padding-left: 1.4em;
        }
        li {
            margin: 0.25em 0;
        }
        li > ul, li > ol {
            margin: 0.15em 0;
        }

        /* Blockquotes */
        blockquote {
            border-left: 3px solid \(accentColor);
            padding: 0.4em 0.9em;
            margin: 0.8em 0;
            color: \(mutedColor);
            font-style: italic;
            background: \(isDark ? "rgba(99,102,241,0.06)" : "rgba(99,102,241,0.04)");
            border-radius: 0 6px 6px 0;
        }
        blockquote p {
            margin: 0.3em 0;
        }

        /* Code */
        code {
            background: \(codeBg);
            padding: 0.12em 0.35em;
            border-radius: 4px;
            font-size: 0.88em;
            font-family: 'SF Mono', Menlo, monospace;
        }
        pre {
            background: \(codeBg);
            padding: 0.8em 1em;
            border-radius: 8px;
            overflow-x: auto;
            margin: 0.8em 0;
            border: 1px solid \(borderColor);
        }
        pre code {
            background: none;
            padding: 0;
            font-size: 0.85em;
            line-height: 1.5;
        }

        /* Links */
        a {
            color: \(linkColor);
            text-decoration: none;
        }

        /* Horizontal rules */
        hr {
            border: none;
            border-top: 1px solid \(borderColor);
            margin: 1.5em 0;
        }

        /* Images */
        img {
            max-width: 100%;
            height: auto;
            border-radius: 8px;
            margin: 0.6em 0;
        }

        /* Tables */
        table {
            border-collapse: collapse;
            width: 100%;
            margin: 0.8em 0;
            font-size: 0.92em;
            overflow-x: auto;
            display: block;
        }
        th, td {
            border: 1px solid \(borderColor);
            padding: 0.45em 0.6em;
            text-align: left;
        }
        th {
            background: \(isDark ? "rgba(255,255,255,0.04)" : "rgba(0,0,0,0.03)");
            font-weight: 600;
        }

        /* Strong & emphasis */
        strong, b { color: \(headingColor); }
        em, i { color: \(isDark ? "#D0D0D8" : "#333"); }

        /* Footnotes & small text */
        sup { font-size: 0.75em; }
        small { font-size: 0.85em; color: \(mutedColor); }
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
        // Override the web content to match iOS appearance
        webView.underPageBackgroundColor = colorScheme == .dark
            ? UIColor(red: 0x0A/255, green: 0x0A/255, blue: 0x0F/255, alpha: 1)
            : UIColor(red: 0xF5/255, green: 0xF5/255, blue: 0xF7/255, alpha: 1)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        webView.underPageBackgroundColor = colorScheme == .dark
            ? UIColor(red: 0x0A/255, green: 0x0A/255, blue: 0x0F/255, alpha: 1)
            : UIColor(red: 0xF5/255, green: 0xF5/255, blue: 0xF7/255, alpha: 1)
        webView.loadHTMLString(html, baseURL: nil)
    }
}
