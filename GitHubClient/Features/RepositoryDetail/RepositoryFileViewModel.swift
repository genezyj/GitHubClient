//
//  RepositoryFileViewModel.swift
//  GitHubClient
//

import Foundation

@MainActor
final class RepositoryFileViewModel {

    enum Preview: Equatable {
        case markdownHTML(String)
        case codeHTML(String)
        case image(URL)
        case unsupported
    }

    private let service: GitHubServiceProtocol
    let repository: GitHubRepository
    let item: RepositoryContent

    private var loadTask: Task<Void, Never>?

    private(set) var state: ViewState<Preview> = .idle {
        didSet { onStateChange?(state) }
    }

    var onStateChange: ((ViewState<Preview>) -> Void)?

    init(repository: GitHubRepository, item: RepositoryContent, service: GitHubServiceProtocol) {
        self.repository = repository
        self.item = item
        self.service = service
    }

    func load() {
        loadTask?.cancel()
        state = .loading

        switch item.fileKind {
        case .image:
            if let url = item.downloadUrl {
                state = .loaded(.image(url))
            } else {
                state = .loaded(.unsupported)
            }
        case .markdown:
            loadTask = Task { @MainActor [weak self] in
                guard let self else { return }
                do {
                    let html = try await self.service.fetchRenderedMarkdownHTML(
                        owner: self.repository.owner.login,
                        repo: self.repository.name,
                        path: self.item.path
                    )
                    if Task.isCancelled { return }
                    self.state = .loaded(.markdownHTML(Self.wrapHTML(html)))
                } catch {
                    await self.loadPlainTextFallback()
                }
            }
        case .text:
            loadTask = Task { @MainActor [weak self] in
                await self?.loadCode()
            }
        case .unsupported:
            state = .loaded(.unsupported)
        }
    }

    private func loadPlainTextFallback() async {
        await loadCode()
    }

    /// Fetches the raw file contents and renders them as a syntax-highlighted
    /// HTML page so code shows up with highlighting and a readable layout in
    /// `WKWebView`, matching how Markdown is presented.
    private func loadCode() async {
        do {
            let file = try await service.fetchRepositoryFile(
                owner: repository.owner.login,
                repo: repository.name,
                path: item.path
            )
            if Task.isCancelled { return }
            if let text = file.decodedTextContent {
                state = .loaded(.codeHTML(Self.wrapCodeHTML(code: text, filename: item.name)))
            } else {
                state = .loaded(.unsupported)
            }
        } catch {
            if Task.isCancelled { return }
            state = .error((error as? AppError) ?? .unknown)
        }
    }

    private static func wrapHTML(_ fragment: String) -> String {
        return """
        <!doctype html>
        <html>
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
        :root { color-scheme: light dark; }
        body {
          font: -apple-system-body;
          line-height: 1.48;
          padding: 16px;
          margin: 0;
          color: CanvasText;
          background: Canvas;
          word-wrap: break-word;
        }
        a { color: LinkText; }
        img { max-width: 100%; height: auto; }
        pre {
          overflow-x: auto;
          padding: 12px;
          border-radius: 8px;
          background: rgba(127, 127, 127, 0.14);
        }
        code, pre {
          font-family: ui-monospace, Menlo, Monaco, Consolas, monospace;
          font-size: 0.92em;
        }
        table {
          display: block;
          max-width: 100%;
          overflow-x: auto;
          border-collapse: collapse;
        }
        th, td {
          border: 1px solid rgba(127, 127, 127, 0.35);
          padding: 6px 8px;
        }
        blockquote {
          margin-left: 0;
          padding-left: 12px;
          border-left: 4px solid rgba(127, 127, 127, 0.35);
          color: GrayText;
        }
        </style>
        </head>
        <body>
        \(fragment)
        </body>
        </html>
        """
    }

    /// Wraps raw source in an HTML page that loads highlight.js for syntax
    /// highlighting. Highlighting is progressive enhancement: if the
    /// highlight.js assets cannot be reached, the code still renders as a
    /// readable monospaced block from the page CSS.
    static func wrapCodeHTML(code: String, filename: String) -> String {
        let escaped = escapeHTML(code)
        let language = highlightLanguage(for: filename)
        let codeClass = language.map { " class=\"language-\($0)\"" } ?? ""
        return """
        <!doctype html>
        <html>
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <link rel="stylesheet"
              href="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/styles/github.min.css"
              media="(prefers-color-scheme: light)">
        <link rel="stylesheet"
              href="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/styles/github-dark.min.css"
              media="(prefers-color-scheme: dark)">
        <style>
        :root { color-scheme: light dark; }
        html, body { margin: 0; padding: 0; background: Canvas; color: CanvasText; }
        pre { margin: 0; }
        pre code.hljs {
          display: block;
          padding: 16px;
          background: transparent;
          font-family: ui-monospace, Menlo, Monaco, Consolas, monospace;
          font-size: 13px;
          line-height: 1.45;
          -webkit-text-size-adjust: 100%;
          tab-size: 4;
        }
        </style>
        </head>
        <body>
        <pre><code\(codeClass)>\(escaped)</code></pre>
        <script src="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/highlight.min.js"></script>
        <script>
          if (window.hljs) { hljs.highlightAll(); }
        </script>
        </body>
        </html>
        """
    }

    private static func escapeHTML(_ string: String) -> String {
        return string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    /// Maps a filename to a highlight.js language hint. Returns `nil` when the
    /// extension is unknown so highlight.js can auto-detect the language.
    static func highlightLanguage(for filename: String) -> String? {
        let ext = (filename as NSString).pathExtension.lowercased()
        return languageByExtension[ext]
    }

    private static let languageByExtension: [String: String] = [
        "swift": "swift",
        "m": "objectivec", "mm": "objectivec", "h": "objectivec",
        "c": "c", "cc": "cpp", "cpp": "cpp", "hpp": "cpp",
        "js": "javascript", "jsx": "javascript",
        "ts": "typescript", "tsx": "typescript",
        "json": "json", "yml": "yaml", "yaml": "yaml",
        "xml": "xml", "html": "xml", "svg": "xml", "plist": "xml",
        "css": "css", "scss": "scss",
        "rb": "ruby", "py": "python", "go": "go", "rs": "rust",
        "java": "java", "kt": "kotlin",
        "sh": "bash", "zsh": "bash", "bash": "bash",
        "sql": "sql", "md": "markdown", "markdown": "markdown",
        "strings": "swift", "txt": "plaintext"
    ]
}
