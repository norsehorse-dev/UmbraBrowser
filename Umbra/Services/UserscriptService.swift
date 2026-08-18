// UserscriptService.swift
// Umbra — Privacy-First Browser

import Combine
import Foundation
import WebKit

struct Userscript: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var filename: String
    var enabled: Bool
    var injectionTime: InjectionTime
    var matchPatterns: [String]  // e.g. ["*://*.reddit.com/*", "*://github.com/*"]
    var addedAt: Date

    enum InjectionTime: String, Codable, CaseIterable {
        case atDocumentStart = "document_start"
        case atDocumentEnd = "document_end"

        var displayName: String {
            switch self {
            case .atDocumentStart: return "Page Start"
            case .atDocumentEnd: return "Page End"
            }
        }

        var wkInjectionTime: WKUserScriptInjectionTime {
            switch self {
            case .atDocumentStart: return .atDocumentStart
            case .atDocumentEnd: return .atDocumentEnd
            }
        }
    }

    init(
        id: UUID = UUID(),
        name: String,
        filename: String,
        enabled: Bool = true,
        injectionTime: InjectionTime = .atDocumentEnd,
        matchPatterns: [String] = ["*://*/*"],
        addedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.filename = filename
        self.enabled = enabled
        self.injectionTime = injectionTime
        self.matchPatterns = matchPatterns
        self.addedAt = addedAt
    }
}

@MainActor
final class UserscriptService: ObservableObject {
    @Published var scripts: [Userscript] = []

    private let metadataKey = "umbra.userscripts.metadata"

    var scriptsDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dir = docs.appendingPathComponent("Userscripts", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    init() {
        loadMetadata()
        syncWithDisk()
    }

    // MARK: - CRUD

    func addScript(name: String, source: String, injectionTime: Userscript.InjectionTime = .atDocumentEnd, matchPatterns: [String] = ["*://*/*"]) {
        let filename = sanitizeFilename(name) + ".js"
        let fileURL = scriptsDirectory.appendingPathComponent(filename)

        do {
            try source.write(to: fileURL, atomically: true, encoding: .utf8)
        } catch {
            print("[Umbra] Failed to write userscript: \(error)")
            return
        }

        let script = Userscript(
            name: name,
            filename: filename,
            enabled: true,
            injectionTime: injectionTime,
            matchPatterns: matchPatterns
        )
        scripts.append(script)
        saveMetadata()
    }

    func removeScript(_ script: Userscript) {
        let fileURL = scriptsDirectory.appendingPathComponent(script.filename)
        try? FileManager.default.removeItem(at: fileURL)
        scripts.removeAll { $0.id == script.id }
        saveMetadata()
    }

    func toggleScript(_ script: Userscript) {
        guard let index = scripts.firstIndex(where: { $0.id == script.id }) else { return }
        scripts[index].enabled.toggle()
        saveMetadata()
    }

    func updateScript(_ script: Userscript, source: String) {
        let fileURL = scriptsDirectory.appendingPathComponent(script.filename)
        try? source.write(to: fileURL, atomically: true, encoding: .utf8)
    }

    // MARK: - Script Loading

    /// Read the source code for a script
    func sourceCode(for script: Userscript) -> String? {
        let fileURL = scriptsDirectory.appendingPathComponent(script.filename)
        return try? String(contentsOf: fileURL, encoding: .utf8)
    }

    /// Get WKUserScripts to inject for a given URL
    func userScripts(for url: URL) -> [WKUserScript] {
        var result: [WKUserScript] = []

        for script in scripts where script.enabled {
            guard matchesURL(url, patterns: script.matchPatterns) else { continue }
            guard let source = sourceCode(for: script) else { continue }

            let wkScript = WKUserScript(
                source: source,
                injectionTime: script.injectionTime.wkInjectionTime,
                forMainFrameOnly: true
            )
            result.append(wkScript)
        }

        return result
    }

    /// Get all enabled scripts as WKUserScripts (for initial tab setup)
    var allEnabledScripts: [WKUserScript] {
        scripts
            .filter { $0.enabled }
            .compactMap { script -> WKUserScript? in
                guard let source = sourceCode(for: script) else { return nil }
                return WKUserScript(
                    source: source,
                    injectionTime: script.injectionTime.wkInjectionTime,
                    forMainFrameOnly: true
                )
            }
    }

    // MARK: - URL Matching

    /// Check if a URL matches any of the given patterns
    /// Patterns use the format: scheme://host/path where * is a wildcard
    private func matchesURL(_ url: URL, patterns: [String]) -> Bool {
        let urlString = url.absoluteString

        for pattern in patterns {
            if pattern == "*://*/*" || pattern == "<all_urls>" {
                return true
            }

            let regexPattern = pattern
                .replacingOccurrences(of: ".", with: "\\.")
                .replacingOccurrences(of: "*", with: ".*")
                .replacingOccurrences(of: "?", with: ".")

            if let regex = try? NSRegularExpression(pattern: "^" + regexPattern + "$", options: .caseInsensitive) {
                let range = NSRange(urlString.startIndex..<urlString.endIndex, in: urlString)
                if regex.firstMatch(in: urlString, range: range) != nil {
                    return true
                }
            }
        }
        return false
    }

    // MARK: - Persistence

    private func saveMetadata() {
        guard let data = try? JSONEncoder().encode(scripts) else { return }
        UserDefaults.standard.set(data, forKey: metadataKey)
    }

    private func loadMetadata() {
        guard let data = UserDefaults.standard.data(forKey: metadataKey),
              let saved = try? JSONDecoder().decode([Userscript].self, from: data) else { return }
        scripts = saved
    }

    /// Remove metadata for scripts whose files no longer exist
    private func syncWithDisk() {
        scripts = scripts.filter { script in
            let fileURL = scriptsDirectory.appendingPathComponent(script.filename)
            return FileManager.default.fileExists(atPath: fileURL.path)
        }
        saveMetadata()
    }

    // MARK: - Helpers

    private func sanitizeFilename(_ name: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let sanitized = name.unicodeScalars.filter { allowed.contains($0) }
        let result = String(String.UnicodeScalarView(sanitized))
        return result.isEmpty ? "userscript" : result
    }
}
