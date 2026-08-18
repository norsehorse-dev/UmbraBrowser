// WhitelistService.swift
// Umbra — Privacy-First Browser

import Combine
import Foundation

@MainActor
final class WhitelistService: ObservableObject {
    @Published var domains: Set<String> = []

    private let storageKey = "umbra.whitelist.domains"

    init() {
        loadFromDisk()
    }

    // MARK: - Public API

    func isWhitelisted(domain: String) -> Bool {
        let normalized = normalize(domain)
        return domains.contains(normalized)
    }

    /// Check if a URL's host is whitelisted
    func isWhitelisted(url: URL) -> Bool {
        guard let host = url.host else { return false }
        let normalized = normalize(host)

        // Check exact match and parent domains
        // e.g., if "example.com" is whitelisted, "sub.example.com" should match
        var parts = normalized.split(separator: ".")
        while parts.count >= 2 {
            let candidate = parts.joined(separator: ".")
            if domains.contains(candidate) {
                return true
            }
            parts.removeFirst()
        }

        return false
    }

    func addDomain(_ domain: String) {
        let normalized = normalize(domain)
        guard !normalized.isEmpty else { return }
        domains.insert(normalized)
        saveToDisk()
    }

    func removeDomain(_ domain: String) {
        let normalized = normalize(domain)
        domains.remove(normalized)
        saveToDisk()
    }

    func toggleDomain(_ domain: String) {
        let normalized = normalize(domain)
        if domains.contains(normalized) {
            domains.remove(normalized)
        } else {
            domains.insert(normalized)
        }
        saveToDisk()
    }

    /// Toggle whitelist for a URL's host
    func toggleWhitelist(for url: URL) {
        guard let host = url.host else { return }
        toggleDomain(host)
    }

    func clearAll() {
        domains.removeAll()
        saveToDisk()
    }

    // MARK: - Persistence

    private func normalize(_ domain: String) -> String {
        var d = domain.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if d.hasPrefix("www.") {
            d = String(d.dropFirst(4))
        }
        return d
    }

    private func saveToDisk() {
        let array = Array(domains).sorted()
        UserDefaults.standard.set(array, forKey: storageKey)
    }

    private func loadFromDisk() {
        if let array = UserDefaults.standard.stringArray(forKey: storageKey) {
            domains = Set(array)
        }
    }
}
