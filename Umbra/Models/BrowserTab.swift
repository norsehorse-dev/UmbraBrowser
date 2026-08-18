// BrowserTab.swift
// Umbra — Privacy-First Browser

import Combine
import Foundation
import WebKit
import SwiftUI

@MainActor
final class BrowserTab: ObservableObject, Identifiable {
    let id: UUID
    let dataStore: WKWebsiteDataStore
    let webView: WKWebView

    @Published var url: URL?
    @Published var title: String = "New Tab"
    @Published var favicon: UIImage?
    @Published var isLoading: Bool = false
    @Published var estimatedProgress: Double = 0
    @Published var canGoBack: Bool = false
    @Published var canGoForward: Bool = false
    @Published var blockedCount: Int = 0
    @Published var blockBreakdown: [String: Int] = [:]  // category -> count

    /// Whether this tab has blocking disabled (whitelisted)
    @Published var isBlockingDisabled: Bool = false

    /// SSL certificate info for current page
    @Published var sslCertificate: SSLCertificateInfo?

    /// Whether current page fell back to HTTP (HTTPS failed)
    @Published var isInsecureFallback: Bool = false

    /// Whether user dismissed the HTTP warning for this navigation
    @Published var httpWarningDismissed: Bool = false

    /// Tab thumbnail snapshot for the tab switcher
    @Published var thumbnail: UIImage?

    /// Reader mode
    @Published var isReaderModeAvailable: Bool = false
    @Published var isReaderModeActive: Bool = false
    private var originalURL: URL?  // URL before reader mode was activated

    /// Tab pinning
    @Published var isPinned: Bool = false

    /// Audio detection
    @Published var isPlayingAudio: Bool = false
    @Published var isMuted: Bool = false

    /// Find in page
    @Published var currentFindQuery: String = ""
    @Published var findResultCount: Int = 0

    private var observations: [NSKeyValueObservation] = []

    init(contentRuleLists: [WKContentRuleList] = [], blockingDisabled: Bool = false) {
        self.id = UUID()
        self.isBlockingDisabled = blockingDisabled

        // Each tab gets its own non-persistent data store — full isolation
        let store = WKWebsiteDataStore.nonPersistent()
        self.dataStore = store

        let config = WKWebViewConfiguration()
        config.websiteDataStore = store
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = [.all]

        // Attach content blocking rules (unless site is whitelisted)
        if !blockingDisabled {
            for ruleList in contentRuleLists {
                config.userContentController.add(ruleList)
            }
        }

        // Anti-fingerprinting script injected at document start
        let antiFingerprint = BrowserTab.antiFingerPrintScript()
        let userScript = WKUserScript(
            source: antiFingerprint,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )
        config.userContentController.addUserScript(userScript)

        // Block counting script — uses PerformanceObserver to detect blocked resources
        let blockCounter = BrowserTab.blockCounterScript()
        let counterScript = WKUserScript(
            source: blockCounter,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        )
        config.userContentController.addUserScript(counterScript)

        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = true
        config.defaultWebpagePreferences = prefs

        let wv = WKWebView(frame: .zero, configuration: config)
        wv.allowsBackForwardNavigationGestures = true
        wv.allowsLinkPreview = true
        wv.isOpaque = false
        wv.backgroundColor = UIColor(UmbraTheme.background)
        wv.scrollView.backgroundColor = UIColor(UmbraTheme.background)

        self.webView = wv

        setupObservations()
    }

    private func setupObservations() {
        // KVO observations — read value from webView param, dispatch to main

        let wv = webView

        observations.append(wv.observe(\.estimatedProgress) { [weak self] wv, _ in
            let v = wv.estimatedProgress
            DispatchQueue.main.async { self?.estimatedProgress = v }
        })

        observations.append(wv.observe(\.title) { [weak self] wv, _ in
            let v = wv.title
            DispatchQueue.main.async {
                if let t = v, !t.isEmpty { self?.title = t }
            }
        })

        observations.append(wv.observe(\.url) { [weak self] wv, _ in
            let v = wv.url
            DispatchQueue.main.async { self?.url = v }
        })

        observations.append(wv.observe(\.isLoading) { [weak self] wv, _ in
            let v = wv.isLoading
            DispatchQueue.main.async { self?.isLoading = v }
        })

        observations.append(wv.observe(\.canGoBack) { [weak self] wv, _ in
            let v = wv.canGoBack
            DispatchQueue.main.async { self?.canGoBack = v }
        })

        observations.append(wv.observe(\.canGoForward) { [weak self] wv, _ in
            let v = wv.canGoForward
            DispatchQueue.main.async { self?.canGoForward = v }
        })
    }

    // MARK: - Navigation

    func load(_ url: URL) {
        let stripped = url.strippingTrackingParams()
        let request = URLRequest(url: stripped)
        webView.load(request)
    }

    func goBack() {
        webView.goBack()
    }

    func goForward() {
        webView.goForward()
    }

    func reload() {
        webView.reload()
    }

    func stopLoading() {
        webView.stopLoading()
    }

    // MARK: - Thumbnail

    /// Capture a snapshot of the current webView for the tab switcher
    func captureThumbnail() {
        guard url != nil else { return }

        let config = WKSnapshotConfiguration()
        config.snapshotWidth = 300  // points, not pixels — keeps it lightweight

        webView.takeSnapshot(with: config) { [weak self] image, error in
            DispatchQueue.main.async {
                if let image = image {
                    self?.thumbnail = image
                }
            }
        }
    }

    // MARK: - Reader Mode

    /// Check if current page has enough content for reader mode
    func checkReaderAvailability() {
        guard url != nil, !isReaderModeActive else { return }
        webView.evaluateJavaScript(ReaderModeService.availabilityCheckScript) { [weak self] result, _ in
            DispatchQueue.main.async {
                self?.isReaderModeAvailable = (result as? Bool) ?? false
            }
        }
    }

    /// Toggle reader mode on/off
    func toggleReaderMode() {
        if isReaderModeActive {
            // Exit reader mode — go back to original page
            isReaderModeActive = false
            if let originalURL = originalURL {
                load(originalURL)
                self.originalURL = nil
            } else {
                webView.goBack()
            }
        } else {
            // Enter reader mode — extract content and display
            originalURL = url
            webView.evaluateJavaScript(ReaderModeService.extractionScript) { [weak self] result, _ in
                guard let jsonString = result as? String,
                      let data = jsonString.data(using: .utf8),
                      let article = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    return
                }

                let title = article["title"] as? String ?? ""
                let byline = article["byline"] as? String ?? ""
                let siteName = article["siteName"] as? String ?? ""
                let content = article["content"] as? String ?? ""

                guard !content.isEmpty else { return }

                let html = ReaderModeService.buildReaderHTML(
                    title: title, byline: byline, siteName: siteName, content: content
                )

                DispatchQueue.main.async {
                    self?.isReaderModeActive = true
                    self?.webView.loadHTMLString(html, baseURL: self?.url)
                }
            }
        }
    }

    // MARK: - Tab Pinning

    func togglePin() {
        isPinned.toggle()
    }

    // MARK: - Audio Detection

    func checkAudioPlaying() {
        let js = """
        (function() {
            var audios = document.querySelectorAll('audio, video');
            for (var i = 0; i < audios.length; i++) {
                if (!audios[i].paused && !audios[i].muted) return true;
            }
            return false;
        })();
        """
        webView.evaluateJavaScript(js) { [weak self] result, _ in
            DispatchQueue.main.async {
                self?.isPlayingAudio = (result as? Bool) ?? false
            }
        }
    }

    func toggleMute() {
        isMuted.toggle()
        let js = """
        (function() {
            var audios = document.querySelectorAll('audio, video');
            audios.forEach(function(el) { el.muted = \(isMuted ? "true" : "false"); });
        })();
        """
        webView.evaluateJavaScript(js)
    }

    // MARK: - Find in Page

    func findInPage(_ query: String) {
        currentFindQuery = query
        if query.isEmpty {
            clearFindHighlights()
            return
        }

        let js = """
        (function() {
            window.__umbraFindCleanup && window.__umbraFindCleanup();
            var highlights = [];
            var body = document.body;
            var walker = document.createTreeWalker(body, NodeFilter.SHOW_TEXT, null, false);
            var count = 0;
            var query = '\(query.replacingOccurrences(of: "'", with: "\\'"))'.toLowerCase();
            while (walker.nextNode()) {
                var node = walker.currentNode;
                var text = node.textContent.toLowerCase();
                if (text.includes(query)) count++;
            }
            window.getSelection().removeAllRanges();
            if (window.find) {
                window.find(query, false, false, true);
            }
            return count;
        })();
        """
        webView.evaluateJavaScript(js) { [weak self] result, _ in
            DispatchQueue.main.async {
                self?.findResultCount = (result as? Int) ?? 0
            }
        }
    }

    func findNext() {
        guard !currentFindQuery.isEmpty else { return }
        let js = "window.find('\(currentFindQuery.replacingOccurrences(of: "'", with: "\\'"))', false, false, true);"
        webView.evaluateJavaScript(js)
    }

    func findPrevious() {
        guard !currentFindQuery.isEmpty else { return }
        let js = "window.find('\(currentFindQuery.replacingOccurrences(of: "'", with: "\\'"))', false, true, true);"
        webView.evaluateJavaScript(js)
    }

    func clearFindHighlights() {
        currentFindQuery = ""
        findResultCount = 0
        webView.evaluateJavaScript("window.getSelection().removeAllRanges();")
    }

    // MARK: - Block Counting

    /// Called by the navigation delegate when a resource is blocked
    func incrementBlockCount(category: String = "mixed") {
        blockedCount += 1
        blockBreakdown[category, default: 0] += 1
    }

    /// Reset counters for new page load
    func resetBlockCounts() {
        blockedCount = 0
        blockBreakdown = [:]
    }

    /// Fetch the block count from the injected counter script
    func fetchBlockCount() {
        webView.evaluateJavaScript("window.__umbraBlockCount || 0") { [weak self] result, _ in
            Task { @MainActor in
                if let count = result as? Int, count > (self?.blockedCount ?? 0) {
                    self?.blockedCount = count
                }
            }
        }
    }

    /// JavaScript that counts blocked resources via failed network requests
    static func blockCounterScript() -> String {
        return """
        (function() {
            'use strict';
            window.__umbraBlockCount = 0;
            window.__umbraBlockDetails = { ads: 0, trackers: 0, scripts: 0, other: 0 };

            // Known ad/tracker domain patterns for classification
            const adPatterns = /doubleclick|googlesyndication|googleadservices|amazon-adsystem|ads-twitter|criteo|outbrain|taboola|adnxs|rubiconproject|pubmatic|openx|moatads|serving-sys/i;
            const trackerPatterns = /google-analytics|googletagmanager|facebook\\.net|scorecardresearch|quantserve|hotjar|mixpanel|segment\\.io|fullstory|mouseflow|amplitude|heapanalytics|branch\\.io|app-measurement|appsflyer|adjust\\.com|braze/i;

            function classify(url) {
                if (adPatterns.test(url)) return 'ads';
                if (trackerPatterns.test(url)) return 'trackers';
                if (url.endsWith('.js') || url.includes('/script')) return 'scripts';
                return 'other';
            }

            // Monitor failed resource loads (blocked by content rules)
            // Uses PerformanceObserver only — read-only, non-invasive
            if (window.PerformanceObserver) {
                try {
                    const observer = new PerformanceObserver(function(list) {
                        list.getEntries().forEach(function(entry) {
                            if (entry.transferSize === 0 && entry.decodedBodySize === 0 &&
                                entry.name && !entry.name.startsWith('data:')) {
                                window.__umbraBlockCount++;
                                var cat = classify(entry.name);
                                window.__umbraBlockDetails[cat]++;
                            }
                        });
                    });
                    observer.observe({ entryTypes: ['resource'] });
                } catch(e) {}
            }
        })();
        """
    }

    // MARK: - Anti-Fingerprinting

    static func antiFingerPrintScript() -> String {
        return """
        (function() {
            'use strict';

            // Override canvas fingerprinting — only for small canvases (fingerprint-sized)
            // Large canvases are real content (maps, charts, visualizations)
            const origToDataURL = HTMLCanvasElement.prototype.toDataURL;
            HTMLCanvasElement.prototype.toDataURL = function(type) {
                if (this.width <= 500 && this.height <= 500) {
                    const ctx = this.getContext('2d');
                    if (ctx) {
                        try {
                            const imageData = ctx.getImageData(0, 0, this.width, this.height);
                            for (let i = 0; i < imageData.data.length; i += 4) {
                                imageData.data[i] = imageData.data[i] ^ 1;
                            }
                            ctx.putImageData(imageData, 0, 0);
                        } catch(e) {}
                    }
                }
                return origToDataURL.apply(this, arguments);
            };

            // Override canvas toBlob — same size threshold
            const origToBlob = HTMLCanvasElement.prototype.toBlob;
            HTMLCanvasElement.prototype.toBlob = function(callback, type, quality) {
                if (this.width <= 500 && this.height <= 500) {
                    const ctx = this.getContext('2d');
                    if (ctx) {
                        try {
                            const imageData = ctx.getImageData(0, 0, this.width, this.height);
                            for (let i = 0; i < imageData.data.length; i += 4) {
                                imageData.data[i] = imageData.data[i] ^ 1;
                            }
                            ctx.putImageData(imageData, 0, 0);
                        } catch(e) {}
                    }
                }
                return origToBlob.apply(this, arguments);
            };

            // Limit WebGL renderer info
            const getParameterOrig = WebGLRenderingContext.prototype.getParameter;
            WebGLRenderingContext.prototype.getParameter = function(param) {
                if (param === 0x9245 || param === 0x9246) { // UNMASKED_VENDOR/RENDERER
                    return 'Apple GPU';
                }
                return getParameterOrig.apply(this, arguments);
            };

            // Spoof hardwareConcurrency
            Object.defineProperty(navigator, 'hardwareConcurrency', {
                get: function() { return 4; }
            });

            // Spoof deviceMemory
            Object.defineProperty(navigator, 'deviceMemory', {
                get: function() { return 8; }
            });

            // AudioContext override REMOVED — was breaking audio/video playback
        })();
        """
    }
}

extension BrowserTab: Equatable {
    static func == (lhs: BrowserTab, rhs: BrowserTab) -> Bool {
        lhs.id == rhs.id
    }
}

extension BrowserTab: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
