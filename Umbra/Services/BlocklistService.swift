// BlocklistService.swift
// Umbra — Privacy-First Browser

import Combine
import Foundation
import WebKit

// MARK: - Blocklist Metadata

struct BlocklistManifest: Codable {
    let version: Int
    let generated: String
    let lists: [BlocklistInfo]
}

struct BlocklistInfo: Codable {
    let name: String
    let type: String  // "ads", "trackers", "mixed"
    let file: String
    let rules: Int
    let size: Int
    let checksum: String
}

enum BlockCategory: String, CaseIterable, Identifiable {
    case ads = "ads"
    case trackers = "trackers"
    case scripts = "scripts"
    case mixed = "mixed"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .ads: return "Ads"
        case .trackers: return "Trackers"
        case .scripts: return "Scripts"
        case .mixed: return "Other"
        }
    }

    var iconName: String {
        switch self {
        case .ads: return "rectangle.badge.xmark"
        case .trackers: return "eye.slash.fill"
        case .scripts: return "chevron.left.forwardslash.chevron.right"
        case .mixed: return "shield.fill"
        }
    }

    var color: String {
        switch self {
        case .ads: return "F85149"
        case .trackers: return "7C6BF0"
        case .scripts: return "D29922"
        case .mixed: return "8B949E"
        }
    }
}

// MARK: - BlocklistService

@MainActor
final class BlocklistService: ObservableObject {
    static let shared = BlocklistService()

    @Published var isLoaded: Bool = false
    @Published var isLoading: Bool = false
    @Published var ruleLists: [String: WKContentRuleList] = [:]  // keyed by list name
    @Published var manifest: BlocklistManifest?
    @Published var lastError: String?

    private let ruleStore = WKContentRuleListStore.default()
    private let baseURL = "https://umbra.norsehor.se/api/blocklists"
    private let cacheDirectory: URL
    private let checksumKey = "umbra.blocklist.checksums"

    init() {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        self.cacheDirectory = caches.appendingPathComponent("Blocklists", isDirectory: true)
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    // MARK: - All Compiled Rule Lists (for TabManager)

    var allRuleLists: [WKContentRuleList] {
        Array(ruleLists.values)
    }

    /// Category for a given list name
    func category(for listName: String) -> BlockCategory {
        guard let info = manifest?.lists.first(where: { $0.name == listName }) else {
            return .mixed
        }
        return BlockCategory(rawValue: info.type) ?? .mixed
    }

    // MARK: - Load Rules

    /// Main entry point — fetch manifest, download updated lists, compile
    func loadRules() async {
        guard !isLoading else { return }
        isLoading = true
        lastError = nil

        do {
            // 1. Fetch manifest from server
            let fetchedManifest = try await fetchManifest()
            self.manifest = fetchedManifest

            // 2. For each list, check if we need to re-download
            for listInfo in fetchedManifest.lists {
                let cachedChecksum = getCachedChecksum(for: listInfo.name)

                if cachedChecksum == listInfo.checksum {
                    // Try to load from already-compiled WKContentRuleListStore
                    if let existing = try? await lookupCompiledList(identifier: listInfo.name) {
                        ruleLists[listInfo.name] = existing
                        continue
                    }
                }

                // Download and compile
                let json = try await downloadList(name: listInfo.name, checksum: cachedChecksum)
                if let json = json {
                    if let compiled = try await compileRules(json: json, identifier: listInfo.name) {
                        ruleLists[listInfo.name] = compiled
                        saveCachedChecksum(listInfo.checksum, for: listInfo.name)
                    }
                }
            }

            isLoaded = true
        } catch {
            print("[Umbra] BlocklistService error: \(error)")
            lastError = error.localizedDescription

            // Fallback: try loading from disk cache
            await loadFromCache()

            // If still nothing, use embedded fallback
            if ruleLists.isEmpty {
                await loadFallbackRules()
            }
        }

        isLoading = false
    }

    /// Load from disk cache when server is unreachable
    private func loadFromCache() async {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil) else {
            return
        }

        for file in files where file.pathExtension == "json" {
            let name = file.deletingPathExtension().lastPathComponent
            if let data = try? Data(contentsOf: file),
               let json = String(data: data, encoding: .utf8),
               let compiled = try? await compileRules(json: json, identifier: name) {
                ruleLists[name] = compiled
            }
        }

        if !ruleLists.isEmpty {
            isLoaded = true
        }
    }

    /// Load embedded fallback rules when server is unreachable and no cache
    private func loadFallbackRules() async {
        let json = BlocklistService.fallbackCoreRules()
        if let compiled = try? await compileRules(json: json, identifier: "umbra-fallback") {
            ruleLists["umbra-fallback"] = compiled
            isLoaded = true
        }
    }

    // MARK: - Network

    private func fetchManifest() async throws -> BlocklistManifest {
        guard let url = URL(string: baseURL) else {
            throw URLError(.badURL)
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        // Server returns json_ok($manifest) which produces:
        // {"ok":true,"version":...,"generated":"...","lists":[...]}
        // The manifest fields are at the root level, not nested in "data"
        let manifest = try JSONDecoder().decode(APIManifestResponse.self, from: data)
        return BlocklistManifest(
            version: manifest.version,
            generated: manifest.generated,
            lists: manifest.lists
        )
    }

    private func downloadList(name: String, checksum: String?) async throws -> String? {
        var urlString = "\(baseURL)?list=\(name)"
        if let checksum = checksum {
            urlString += "&check=\(checksum)"
        }

        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        // 304 = not modified
        if httpResponse.statusCode == 304 {
            return nil
        }

        guard httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        guard let json = String(data: data, encoding: .utf8) else {
            throw URLError(.cannotDecodeContentData)
        }

        // Cache to disk
        let cachePath = cacheDirectory.appendingPathComponent("\(name).json")
        try data.write(to: cachePath)

        return json
    }

    // MARK: - Compilation

    private func compileRules(json: String, identifier: String) async throws -> WKContentRuleList? {
        return try await withCheckedThrowingContinuation { continuation in
            ruleStore?.compileContentRuleList(
                forIdentifier: identifier,
                encodedContentRuleList: json
            ) { ruleList, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ruleList)
                }
            }
        }
    }

    private func lookupCompiledList(identifier: String) async throws -> WKContentRuleList? {
        return try await withCheckedThrowingContinuation { continuation in
            ruleStore?.lookUpContentRuleList(forIdentifier: identifier) { ruleList, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ruleList)
                }
            }
        }
    }

    // MARK: - Checksum Cache

    private func getCachedChecksum(for name: String) -> String? {
        let checksums = UserDefaults.standard.dictionary(forKey: checksumKey) as? [String: String]
        return checksums?[name]
    }

    private func saveCachedChecksum(_ checksum: String, for name: String) {
        var checksums = UserDefaults.standard.dictionary(forKey: checksumKey) as? [String: String] ?? [:]
        checksums[name] = checksum
        UserDefaults.standard.set(checksums, forKey: checksumKey)
    }

    // MARK: - Fallback Rules

    static func fallbackCoreRules() -> String {
        let adDomains = [
            "doubleclick\\.net", "googlesyndication\\.com", "googleadservices\\.com",
            "google-analytics\\.com", "googletagmanager\\.com",
            "amazon-adsystem\\.com", "ads-twitter\\.com", "analytics\\.twitter\\.com",
            "connect\\.facebook\\.net", "criteo\\.com", "criteo\\.net",
            "outbrain\\.com", "taboola\\.com", "adnxs\\.com",
            "rubiconproject\\.com", "pubmatic\\.com", "openx\\.net",
            "moatads\\.com", "serving-sys\\.com"
        ]

        let trackerDomains = [
            "scorecardresearch\\.com", "quantserve\\.com",
            "hotjar\\.com", "mixpanel\\.com", "segment\\.io", "segment\\.com",
            "fullstory\\.com", "mouseflow\\.com", "crazyegg\\.com",
            "optimizely\\.com", "amplitude\\.com", "heapanalytics\\.com",
            "branch\\.io", "app-measurement\\.com", "appsflyer\\.com",
            "adjust\\.com", "braze\\.com"
        ]

        var rules: [[String: Any]] = []

        // Block third-party requests to ad domains (url-filter matches the REQUEST url)
        for domain in adDomains {
            rules.append([
                "trigger": [
                    "url-filter": "https?://([^/]*\\.)?" + domain,
                    "load-type": ["third-party"]
                ],
                "action": ["type": "block"]
            ])
        }

        // Block third-party requests to tracker domains
        for domain in trackerDomains {
            rules.append([
                "trigger": [
                    "url-filter": "https?://([^/]*\\.)?" + domain,
                    "load-type": ["third-party"]
                ],
                "action": ["type": "block"]
            ])
        }

        // Block common ad URL path patterns (third-party only)
        let patterns = [
            ".*/ads/.*", ".*/adserver/.*", ".*/adclick/.*",
            ".*/pagead/.*"
        ]

        for pattern in patterns {
            rules.append([
                "trigger": ["url-filter": pattern, "load-type": ["third-party"]],
                "action": ["type": "block"]
            ])
        }

        guard let data = try? JSONSerialization.data(withJSONObject: rules),
              let json = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return json
    }
}

// MARK: - API Response (matches json_ok() output from server)

private struct APIManifestResponse: Codable {
    let ok: Bool
    let version: Int
    let generated: String
    let lists: [BlocklistInfo]
}
