import SwiftUI
import WebKit

/// Shared holder so ContentView can query the active webview's scroll position.
final class WebViewHolder: ObservableObject {
    weak var webView: WKWebView?

    /// JS to get scroll fraction from either a wiki page (window scroll) or CodeMirror (.cm-scroller).
    func captureScrollFraction(isEditor: Bool, completion: @escaping (Double) -> Void) {
        guard let wv = webView else { completion(0); return }
        let js = isEditor
            ? "__getScrollFraction()"
            : "window.scrollY / Math.max(1, document.body.scrollHeight - window.innerHeight)"
        wv.evaluateJavaScript(js) { result, _ in
            completion((result as? Double) ?? 0)
        }
    }
}

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
    /// Shared scroll fraction (0–1) for preserving position across view switches.
    @Binding var scrollFraction: Double
    /// Shared holder so ContentView can query scroll.
    var holder: WebViewHolder? = nil

    func makeCoordinator() -> Coordinator { Coordinator(onNavigate: onNavigate) }

    func makeNSView(context: Context) -> WKWebView {
        let wv = WKWebView()
        wv.navigationDelegate = context.coordinator
        wv.setValue(false, forKey: "drawsBackground")
        holder?.webView = wv
        return wv
    }

    func updateNSView(_ wv: WKWebView, context: Context) {
        context.coordinator.onNavigate = onNavigate
        // Ensure the web view inherits the app's effective appearance
        // so CSS prefers-color-scheme responds to the manual toggle.
        wv.appearance = NSApp.effectiveAppearance
        if wv.url != fileURL || context.coordinator.lastReloadToken != reloadToken {
            let isReload = wv.url == fileURL && context.coordinator.lastReloadToken != reloadToken
            context.coordinator.lastReloadToken = reloadToken
            // Save scroll position before reload
            if isReload {
                wv.evaluateJavaScript("window.scrollY / Math.max(1, document.body.scrollHeight - window.innerHeight)") { result, _ in
                    if let fraction = result as? Double, fraction.isFinite {
                        context.coordinator.pendingScrollFraction = fraction
                    }
                }
            } else {
                // Switching to a new page — use the shared fraction from the binding
                context.coordinator.pendingScrollFraction = scrollFraction
            }
            context.coordinator.scrollFractionBinding = $scrollFraction
            wv.loadFileURL(fileURL, allowingReadAccessTo: allowingReadAccessTo)
        }
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        var onNavigate: ((URL) -> Void)?
        var lastReloadToken: Int = 0
        var pendingScrollFraction: Double = 0
        var scrollFractionBinding: Binding<Double>?

        init(onNavigate: ((URL) -> Void)?) {
            self.onNavigate = onNavigate
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // Restore scroll position after page load
            let fraction = pendingScrollFraction
            if fraction > 0.01 {
                // Small delay to let layout settle
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    webView.evaluateJavaScript(
                        "window.scrollTo(0, \(fraction) * (document.body.scrollHeight - window.innerHeight))"
                    )
                }
            }
        }

        /// Called by ContentView before switching away — captures current scroll.
        func captureScroll(_ webView: WKWebView, completion: @escaping (Double) -> Void) {
            webView.evaluateJavaScript("window.scrollY / Math.max(1, document.body.scrollHeight - window.innerHeight)") { result, _ in
                completion((result as? Double) ?? 0)
            }
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
