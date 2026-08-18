// BrowserWebView.swift
// Umbra — Privacy-First Browser

import SwiftUI
import WebKit

struct BrowserWebView: UIViewRepresentable {
    @ObservedObject var tab: BrowserTab
    @EnvironmentObject var tabManager: TabManager
    @EnvironmentObject var settingsService: SettingsService
    @EnvironmentObject var historyService: HistoryService

    func makeUIView(context: Context) -> WKWebView {
        tab.webView.navigationDelegate = context.coordinator
        tab.webView.uiDelegate = context.coordinator
        return tab.webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        // No-op — tab manages its own state
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(tab: tab, tabManager: tabManager, settings: settingsService, history: historyService)
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        let tab: BrowserTab
        let tabManager: TabManager
        let settings: SettingsService
        let history: HistoryService

        init(tab: BrowserTab, tabManager: TabManager, settings: SettingsService, history: HistoryService) {
            self.tab = tab
            self.tabManager = tabManager
            self.settings = settings
            self.history = history
        }

        // MARK: - WKNavigationDelegate

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let url = navigationAction.request.url else {
                decisionHandler(.allow)
                return
            }

            // Only apply HTTPS upgrade, UTM stripping to main frame navigations
            // Iframes and subframes pass through untouched
            let isMainFrame = navigationAction.targetFrame?.isMainFrame ?? false

            if isMainFrame {
                // HTTPS-first: upgrade http to https
                if settings.httpsFirst && url.scheme == "http" {
                    var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
                    components?.scheme = "https"
                    if let httpsURL = components?.url {
                        decisionHandler(.cancel)
                        Task { @MainActor in
                            self.tab.isInsecureFallback = false
                            self.tab.httpWarningDismissed = false
                            self.tab.load(httpsURL)
                        }
                        return
                    }
                }

                // UTM stripping
                if settings.stripUTM {
                    let stripped = url.strippingTrackingParams()
                    if stripped != url {
                        decisionHandler(.cancel)
                        Task { @MainActor in
                            self.tab.load(stripped)
                        }
                        return
                    }
                }
            }

            // Handle target="_blank" links — applies to all frames
            if navigationAction.targetFrame == nil {
                decisionHandler(.cancel)
                Task { @MainActor in
                    self.tab.load(url)
                }
                return
            }

            decisionHandler(.allow)
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            Task { @MainActor in
                tab.resetBlockCounts()
                tab.sslCertificate = nil
            }
        }

        // MARK: - SSL Certificate Capture

        func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
            let protectionSpace = challenge.protectionSpace

            if protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
               let serverTrust = protectionSpace.serverTrust {

                // Extract certificate info
                Task { @MainActor in
                    if let certInfo = SSLCertificateInfo.from(protectionSpace: protectionSpace) {
                        self.tab.sslCertificate = certInfo
                    }
                }

                // Accept the certificate (WKWebView handles validation)
                let credential = URLCredential(trust: serverTrust)
                completionHandler(.useCredential, credential)
            } else {
                completionHandler(.performDefaultHandling, nil)
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // Fetch block count from injected script
            Task { @MainActor in
                tab.fetchBlockCount()

                // Record in history
                if let url = tab.url, !tab.isReaderModeActive {
                    history.addEntry(url: url, title: tab.title)
                }

                // Check reader mode availability
                tab.checkReaderAvailability()

                // Capture thumbnail for tab switcher
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.tab.captureThumbnail()
                }

                // Also fetch detailed breakdown
                webView.evaluateJavaScript("JSON.stringify(window.__umbraBlockDetails || {})") { [weak self] result, _ in
                    guard let jsonString = result as? String,
                          let data = jsonString.data(using: .utf8),
                          let details = try? JSONDecoder().decode([String: Int].self, from: data) else { return }
                    Task { @MainActor in
                        for (key, value) in details where value > 0 {
                            self?.tab.blockBreakdown[key] = value
                        }
                    }
                }
            }

            // Fetch favicon
            let faviconJS = """
            (function() {
                var link = document.querySelector("link[rel~='icon']") ||
                           document.querySelector("link[rel~='shortcut icon']") ||
                           document.querySelector("link[rel~='apple-touch-icon']");
                return link ? link.href : (window.location.origin + '/favicon.ico');
            })();
            """
            webView.evaluateJavaScript(faviconJS) { [weak self] result, _ in
                guard let urlString = result as? String,
                      let url = URL(string: urlString) else { return }
                Task {
                    await self?.loadFavicon(from: url)
                }
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            let nsError = error as NSError
            if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
                return
            }
            print("[Umbra] Navigation failed: \(error.localizedDescription)")
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            let nsError = error as NSError
            if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
                return
            }

            // If HTTPS failed and httpsFirst is on, fall back to HTTP with warning
            if settings.httpsFirst,
               let failedURL = webView.url ?? navigationURLFromError(nsError),
               failedURL.scheme == "https" {
                var components = URLComponents(url: failedURL, resolvingAgainstBaseURL: false)
                components?.scheme = "http"
                if let httpURL = components?.url {
                    Task { @MainActor in
                        self.tab.isInsecureFallback = true
                        self.tab.httpWarningDismissed = false
                        self.tab.load(httpURL)
                    }
                    return
                }
            }

            print("[Umbra] Provisional navigation failed: \(error.localizedDescription)")
        }

        /// Extract the URL from NSError's userInfo when webView.url is nil
        private func navigationURLFromError(_ error: NSError) -> URL? {
            if let urlString = error.userInfo[NSURLErrorFailingURLStringErrorKey] as? String {
                return URL(string: urlString)
            }
            return error.userInfo[NSURLErrorFailingURLErrorKey] as? URL
        }

        // MARK: - WKUIDelegate

        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            if let url = navigationAction.request.url {
                Task { @MainActor in
                    tabManager.createNewTab(url: url)
                }
            }
            return nil
        }

        func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
            completionHandler()
        }

        func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
            completionHandler(true)
        }

        func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (String?) -> Void) {
            completionHandler(nil)
        }

        // MARK: - Favicon

        @MainActor
        private func loadFavicon(from url: URL) async {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let image = UIImage(data: data) {
                    tab.favicon = image
                }
            } catch {
                // Favicon load failed, that's fine
            }
        }
    }
}
