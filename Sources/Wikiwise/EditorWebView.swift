import SwiftUI
import WebKit

/// WKWebView wrapper running CodeMirror for markdown editing.
/// Swift → JS: setContent() to load a file.
/// JS → Swift: contentChanged message handler to auto-save.
struct EditorWebView: NSViewRepresentable {
    let fileURL: URL
    @Binding var fileContent: String

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let controller = WKUserContentController()
        controller.add(context.coordinator, name: "contentChanged")
        controller.add(context.coordinator, name: "editorReady")
        config.userContentController = controller

        let wv = WKWebView(frame: .zero, configuration: config)
        wv.setValue(false, forKey: "drawsBackground")
        context.coordinator.webView = wv
        context.coordinator.pendingContent = fileContent
        context.coordinator.currentFileURL = fileURL

        // Load editor.html from the resource bundle
        if let editorURL = wikiwiseBundle.url(forResource: "editor", withExtension: "html") {
            wv.loadFileURL(editorURL, allowingReadAccessTo: editorURL.deletingLastPathComponent())
        }

        return wv
    }

    func updateNSView(_ wv: WKWebView, context: Context) {
        wv.appearance = NSApp.effectiveAppearance
        // If the file changed, push new content to the editor
        if context.coordinator.currentFileURL != fileURL {
            context.coordinator.currentFileURL = fileURL
            context.coordinator.pendingContent = fileContent
            if context.coordinator.isReady {
                context.coordinator.pushContent(fileContent)
            }
        }
    }

    class Coordinator: NSObject, WKScriptMessageHandler {
        var parent: EditorWebView
        var webView: WKWebView?
        var isReady = false
        var pendingContent: String?
        var currentFileURL: URL?

        init(_ parent: EditorWebView) {
            self.parent = parent
        }

        func userContentController(_ controller: WKUserContentController,
                                   didReceive message: WKScriptMessage) {
            switch message.name {
            case "editorReady":
                isReady = true
                if let content = pendingContent {
                    pushContent(content)
                    pendingContent = nil
                }

            case "contentChanged":
                guard let content = message.body as? String,
                      !content.isEmpty,
                      let fileURL = currentFileURL else { return }
                // Save to disk (never save empty content — protects against
                // the editor firing before content is loaded)
                try? content.write(to: fileURL, atomically: true, encoding: .utf8)
                DispatchQueue.main.async {
                    self.parent.fileContent = content
                }

            default:
                break
            }
        }

        func pushContent(_ content: String) {
            let escaped = content
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "'", with: "\\'")
                .replacingOccurrences(of: "\n", with: "\\n")
                .replacingOccurrences(of: "\r", with: "\\r")
            webView?.evaluateJavaScript("setContent('\(escaped)')") { _, error in
                if let error = error {
                    print("[editor] Error setting content: \(error)")
                }
            }
        }
    }
}
