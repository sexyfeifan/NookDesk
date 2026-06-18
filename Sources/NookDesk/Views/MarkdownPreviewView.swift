import SwiftUI
import WebKit

struct MarkdownPreviewView: NSViewRepresentable {
    let markdown: String

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        let coordinator = context.coordinator
        coordinator.pendingMarkdown = markdown

        // Cancel any in-flight debounce timer
        coordinator.debounceTimer?.invalidate()

        // If first load (no previous content), render immediately
        if coordinator.lastRenderedMarkdown == nil {
            coordinator.lastRenderedMarkdown = markdown
            let html = Self.renderHTML(from: markdown)
            webView.loadHTMLString(html, baseURL: nil)
            return
        }

        // Debounce: wait 300ms of idle time before rendering
        coordinator.debounceTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { [weak webView] _ in
            guard let webView = webView else { return }
            let pending = coordinator.pendingMarkdown
            guard pending != coordinator.lastRenderedMarkdown else { return }
            coordinator.lastRenderedMarkdown = pending
            let html = Self.renderHTML(from: pending)
            DispatchQueue.main.async {
                webView.loadHTMLString(html, baseURL: nil)
            }
        }
    }

    final class Coordinator {
        var debounceTimer: Timer?
        var lastRenderedMarkdown: String?
        var pendingMarkdown: String = ""
    }

    static func renderHTML(from markdown: String) -> String {
        let escaped = markdown
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")

        // Simple Markdown → HTML conversion for preview
        var lines = escaped.components(separatedBy: "\n")
        var html = ""
        var inCodeBlock = false
        var inList = false
        var listType = ""

        for line in lines {
            // Code blocks
            if line.hasPrefix("```") {
                if inCodeBlock {
                    html += "</code></pre>\n"
                    inCodeBlock = false
                } else {
                    html += "<pre><code>"
                    inCodeBlock = true
                }
                continue
            }

            if inCodeBlock {
                html += line + "\n"
                continue
            }

            // Close list if needed
            if inList && !line.hasPrefix("- ") && !line.hasPrefix("* ") && !line.hasPrefix("1. ") && !line.trimmingCharacters(in: .whitespaces).isEmpty {
                html += "</\(listType)>\n"
                inList = false
            }

            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Headings
            if trimmed.hasPrefix("###### ") {
                html += "<h6>\(String(trimmed.dropFirst(7)))</h6>\n"
            } else if trimmed.hasPrefix("##### ") {
                html += "<h5>\(String(trimmed.dropFirst(6)))</h5>\n"
            } else if trimmed.hasPrefix("#### ") {
                html += "<h4>\(String(trimmed.dropFirst(5)))</h4>\n"
            } else if trimmed.hasPrefix("### ") {
                html += "<h3>\(String(trimmed.dropFirst(4)))</h3>\n"
            } else if trimmed.hasPrefix("## ") {
                html += "<h2>\(String(trimmed.dropFirst(3)))</h2>\n"
            } else if trimmed.hasPrefix("# ") {
                html += "<h1>\(String(trimmed.dropFirst(2)))</h1>\n"
            }
            // Horizontal rule
            else if trimmed == "---" || trimmed == "***" || trimmed == "___" {
                html += "<hr>\n"
            }
            // Unordered list
            else if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
                if !inList {
                    html += "<ul>\n"
                    inList = true
                    listType = "ul"
                }
                html += "<li>\(applyInlineStyles(String(trimmed.dropFirst(2))))</li>\n"
            }
            // Ordered list
            else if let range = trimmed.range(of: #"^\d+\. "#, options: .regularExpression) {
                if !inList {
                    html += "<ol>\n"
                    inList = true
                    listType = "ol"
                }
                let content = String(trimmed[range.upperBound...])
                html += "<li>\(applyInlineStyles(content))</li>\n"
            }
            // Blockquote
            else if trimmed.hasPrefix("> ") {
                html += "<blockquote>\(applyInlineStyles(String(trimmed.dropFirst(2))))</blockquote>\n"
            }
            // Empty line
            else if trimmed.isEmpty {
                html += "<br>\n"
            }
            // Regular paragraph
            else {
                html += "<p>\(applyInlineStyles(trimmed))</p>\n"
            }
        }

        if inList {
            html += "</\(listType)>\n"
        }
        if inCodeBlock {
            html += "</code></pre>\n"
        }

        return """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <style>
            body {
                font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Helvetica, Arial, sans-serif;
                font-size: 14px;
                line-height: 1.6;
                padding: 16px;
                color: #1a1a1a;
                max-width: 100%;
            }
            h1, h2, h3, h4, h5, h6 { margin-top: 16px; margin-bottom: 8px; font-weight: 600; }
            h1 { font-size: 24px; border-bottom: 1px solid #eaecef; padding-bottom: 8px; }
            h2 { font-size: 20px; border-bottom: 1px solid #eaecef; padding-bottom: 6px; }
            h3 { font-size: 16px; }
            p { margin: 8px 0; }
            code { background: #f0f0f0; padding: 2px 6px; border-radius: 3px; font-size: 13px; }
            pre { background: #f6f8fa; padding: 12px; border-radius: 6px; overflow-x: auto; }
            pre code { background: none; padding: 0; }
            blockquote { border-left: 4px solid #dfe2e5; margin: 8px 0; padding: 4px 16px; color: #6a737d; }
            ul, ol { padding-left: 24px; }
            li { margin: 4px 0; }
            hr { border: none; border-top: 1px solid #eaecef; margin: 16px 0; }
            a { color: #0366d6; text-decoration: none; }
            a:hover { text-decoration: underline; }
            img { max-width: 100%; border-radius: 8px; }
            strong { font-weight: 600; }
            em { font-style: italic; }
            del { text-decoration: line-through; color: #6a737d; }
        </style>
        </head>
        <body>\(html)</body>
        </html>
        """
    }

    static func applyInlineStyles(_ text: String) -> String {
        var result = text
        // Bold: **text** or __text__
        result = result.replacingOccurrences(of: #"\*\*(.+?)\*\*"#, with: "<strong>$1</strong>", options: .regularExpression)
        result = result.replacingOccurrences(of: #"__(.+?)__"#, with: "<strong>$1</strong>", options: .regularExpression)
        // Italic: *text* or _text_
        result = result.replacingOccurrences(of: #"\*(.+?)\*"#, with: "<em>$1</em>", options: .regularExpression)
        result = result.replacingOccurrences(of: #"(?<!\w)_(.+?)_(?!\w)"#, with: "<em>$1</em>", options: .regularExpression)
        // Strikethrough: ~~text~~
        result = result.replacingOccurrences(of: #"~~(.+?)~~"#, with: "<del>$1</del>", options: .regularExpression)
        // Inline code: `text`
        result = result.replacingOccurrences(of: #"`([^`]+)`"#, with: "<code>$1</code>", options: .regularExpression)
        // Links: [text](url)
        result = result.replacingOccurrences(of: #"\[([^\]]+)\]\(([^)]+)\)"#, with: #"<a href="$2">$1</a>"#, options: .regularExpression)
        // Images: ![alt](url)
        result = result.replacingOccurrences(of: #"!\[([^\]]*)\]\(([^)]+)\)"#, with: #"<img src="$2" alt="$1">"#, options: .regularExpression)
        return result
    }
}
