import SwiftUI
import WebKit
import DevAppCore

struct MarkdownWebView: NSViewRepresentable {
    let html: String

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        let fullHTML = wrapInHTMLPage(html)
        webView.loadHTMLString(fullHTML, baseURL: nil)
    }

    private func wrapInHTMLPage(_ body: String) -> String {
        """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <style>
            :root { color-scheme: light dark; }
            body {
                font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", "Helvetica Neue", sans-serif;
                font-size: 14px;
                line-height: 1.6;
                color: var(--text);
                padding: 16px 20px;
                max-width: 100%;
                margin: 0;
                --text: #1d1d1f;
                --code-bg: #f5f5f7;
                --border: #d2d2d7;
                --link: #0066cc;
                --blockquote: #636366;
            }
            @media (prefers-color-scheme: dark) {
                body { --text: #f5f5f7; --code-bg: #2c2c2e; --border: #48484a; --link: #64b5f6; --blockquote: #aeaeb2; }
            }
            h1 { font-size: 1.8em; font-weight: 700; border-bottom: 1px solid var(--border); padding-bottom: 8px; margin-top: 24px; }
            h2 { font-size: 1.4em; font-weight: 600; border-bottom: 1px solid var(--border); padding-bottom: 6px; margin-top: 20px; }
            h3 { font-size: 1.2em; font-weight: 600; margin-top: 16px; }
            h4, h5, h6 { font-size: 1em; font-weight: 600; margin-top: 12px; }
            p { margin: 8px 0; }
            a { color: var(--link); text-decoration: none; }
            a:hover { text-decoration: underline; }
            code {
                font-family: "SF Mono", Menlo, monospace;
                font-size: 0.9em;
                background: var(--code-bg);
                padding: 2px 6px;
                border-radius: 4px;
            }
            pre {
                background: var(--code-bg);
                padding: 12px 16px;
                border-radius: 8px;
                overflow-x: auto;
                font-size: 0.85em;
                line-height: 1.5;
            }
            pre code { background: none; padding: 0; }
            blockquote {
                border-left: 3px solid var(--border);
                margin: 8px 0;
                padding: 4px 16px;
                color: var(--blockquote);
            }
            table { border-collapse: collapse; width: 100%; margin: 12px 0; }
            th, td { border: 1px solid var(--border); padding: 8px 12px; text-align: left; }
            th { font-weight: 600; background: var(--code-bg); }
            ul, ol { padding-left: 24px; margin: 8px 0; }
            li { margin: 4px 0; }
            hr { border: none; border-top: 1px solid var(--border); margin: 16px 0; }
            img { max-width: 100%; border-radius: 4px; }
            input[type="checkbox"] { margin-right: 6px; }
        </style>
        </head>
        <body>\(body)</body>
        </html>
        """
    }
}

public struct MarkdownPreviewView: View {
    @State private var markdown = ""
    @State private var renderedHTML = ""

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Markdown Preview")
                    .font(.title3)
                    .fontWeight(.semibold)
                Text("Write Markdown on the left, see rendered preview on the right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)

            HStack(spacing: 16) {
                // Editor
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("MARKDOWN")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                        Spacer()
                        CopyButton(text: markdown)
                    }
                    TextEditor(text: $markdown)
                        .font(.system(.body, design: .monospaced))
                        .scrollContentBackground(.hidden)
                        .padding(10)
                        .background(.fill.tertiary)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.separator, lineWidth: 0.5))
                }

                // Preview
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("PREVIEW")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                        Spacer()
                        CopyButton(text: renderedHTML)
                    }
                    MarkdownWebView(html: renderedHTML)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(.separator, lineWidth: 0.5))
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .onChange(of: markdown) { _, newValue in
            renderedHTML = MarkdownToHTML.convert(newValue)
        }
    }
}

extension MarkdownPreviewView {
    public static let descriptor = ToolDescriptor(
        id: "markdown-preview",
        name: "Markdown Preview",
        icon: "text.document",
        category: .conversion,
        searchKeywords: ["markdown", "preview", "md", "render", "预览"]
    )
}
