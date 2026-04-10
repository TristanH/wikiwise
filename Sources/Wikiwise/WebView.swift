import SwiftUI
import WebKit

private extension URL {
    /// URL without the fragment (#anchor) component.
    var deletingFragment: URL {
        var components = URLComponents(url: self, resolvingAgainstBaseURL: false)
        components?.fragment = nil
        return components?.url ?? self
    }
}

/// Minimal SwiftUI wrapper around WKWebView that loads local HTML files.
/// External links (http/https) are opened in the user's default browser.
/// Local link clicks (wikilinks) are intercepted and reported via `onNavigate`.
struct WebView: NSViewRepresentable {
    let fileURL: URL
    let allowingReadAccessTo: URL
    var onNavigate: ((URL) -> Void)? = nil
    /// Increment to force a reload even when the URL hasn't changed
    /// (e.g. after CSS change recompiles the same page).
    var reloadToken: Int = 0

    func makeCoordinator() -> Coordinator { Coordinator(onNavigate: onNavigate) }

    func makeNSView(context: Context) -> WKWebView {
        let wv = WKWebView()
        wv.navigationDelegate = context.coordinator
        return wv
    }

    func updateNSView(_ wv: WKWebView, context: Context) {
        context.coordinator.onNavigate = onNavigate
        if wv.url != fileURL || context.coordinator.lastReloadToken != reloadToken {
            context.coordinator.lastReloadToken = reloadToken
            wv.loadFileURL(fileURL, allowingReadAccessTo: allowingReadAccessTo)
        }
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        var onNavigate: ((URL) -> Void)?
        var lastReloadToken: Int = 0

        init(onNavigate: ((URL) -> Void)?) {
            self.onNavigate = onNavigate
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            guard let url = navigationAction.request.url else {
                decisionHandler(.allow)
                return
            }
            // Open http/https links in the default browser
            if url.scheme == "http" || url.scheme == "https" {
                NSWorkspace.shared.open(url)
                decisionHandler(.cancel)
                return
            }
            // Intercept local file link clicks (wikilinks) — let ContentView handle navigation.
            // Allow same-page anchor links (#fragment) to scroll normally.
            if navigationAction.navigationType == .linkActivated,
               url.isFileURL,
               let onNavigate = onNavigate {
                let currentBase = webView.url?.deletingFragment
                let targetBase = url.deletingFragment
                if currentBase == targetBase && url.fragment != nil {
                    // Same page, different anchor — let the webview handle scrolling
                    decisionHandler(.allow)
                    return
                }
                onNavigate(url)
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }
    }
}
