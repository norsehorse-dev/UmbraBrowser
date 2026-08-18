// HistoryService.swift
// Umbra — Privacy-First Browser

import Combine
import Foundation
import CryptoKit
import Security

struct HistoryEntry: Identifiable, Codable, Equatable {
    let id: UUID
    let url: URL
    let title: String
    let visitedAt: Date
    let domain: String

    init(id: UUID = UUID(), url: URL, title: String, visitedAt: Date = Date()) {
        self.id = id
        self.url = url
        self.title = title
        self.visitedAt = visitedAt
        self.domain = url.host?.replacingOccurrences(of: "www.", with: "") ?? url.absoluteString
    }
}

struct HistoryGroup: Identifiable {
    let id: String  // date string
    let date: Date
    let entries: [HistoryEntry]

    var displayDate: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

@MainActor
final class HistoryService: ObservableObject {
    @Published var entries: [HistoryEntry] = []

    private let keychainKey = "com.umbra.browser.history.key"
    private let storageURL: URL
    private let maxEntries = 10000

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.storageURL = docs.appendingPathComponent("history.enc")
        loadHistory()
    }

    // MARK: - Add Entry

    func addEntry(url: URL, title: String) {
        // Skip about:blank, empty URLs
        guard let host = url.host, !host.isEmpty else { return }

        // Don't duplicate the same URL within 1 minute
        let oneMinuteAgo = Date().addingTimeInterval(-60)
        if entries.first(where: { $0.url == url && $0.visitedAt > oneMinuteAgo }) != nil {
            return
        }

        let entry = HistoryEntry(url: url, title: title)
        entries.insert(entry, at: 0)

        // Trim to max
        if entries.count > maxEntries {
            entries = Array(entries.prefix(maxEntries))
        }

        saveHistory()
    }

    // MARK: - Search

    func search(query: String) -> [HistoryEntry] {
        guard !query.isEmpty else { return entries }
        let lowered = query.lowercased()
        return entries.filter {
            $0.title.lowercased().contains(lowered) ||
            $0.domain.lowercased().contains(lowered) ||
            $0.url.absoluteString.lowercased().contains(lowered)
        }
    }

    // MARK: - Grouped by Date

    var groupedByDate: [HistoryGroup] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: entries) { entry in
            calendar.startOfDay(for: entry.visitedAt)
        }
        return grouped.map { date, entries in
            HistoryGroup(
                id: date.ISO8601Format(),
                date: date,
                entries: entries.sorted { $0.visitedAt > $1.visitedAt }
            )
        }
        .sorted { $0.date > $1.date }
    }

    // MARK: - Clear

    func clearAll() {
        entries.removeAll()
        saveHistory()
    }

    func clearLastHour() {
        let oneHourAgo = Date().addingTimeInterval(-3600)
        entries.removeAll { $0.visitedAt > oneHourAgo }
        saveHistory()
    }

    func clearToday() {
        let startOfToday = Calendar.current.startOfDay(for: Date())
        entries.removeAll { $0.visitedAt >= startOfToday }
        saveHistory()
    }

    func removeEntry(_ entry: HistoryEntry) {
        entries.removeAll { $0.id == entry.id }
        saveHistory()
    }

    // MARK: - Encrypted Storage (same pattern as BookmarkService)

    private func getOrCreateKey() -> SymmetricKey {
        if let keyData = loadKeyFromKeychain() {
            return SymmetricKey(data: keyData)
        }
        let key = SymmetricKey(size: .bits256)
        let keyData = key.withUnsafeBytes { Data($0) }
        saveKeyToKeychain(keyData)
        return key
    }

    private func saveHistory() {
        guard let jsonData = try? JSONEncoder().encode(entries) else { return }
        let key = getOrCreateKey()
        do {
            let sealedBox = try AES.GCM.seal(jsonData, using: key)
            guard let combined = sealedBox.combined else { return }
            try combined.write(to: storageURL)
        } catch {
            print("[Umbra] Failed to encrypt history: \(error)")
        }
    }

    private func loadHistory() {
        guard FileManager.default.fileExists(atPath: storageURL.path) else { return }
        do {
            let encryptedData = try Data(contentsOf: storageURL)
            let key = getOrCreateKey()
            let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
            let decryptedData = try AES.GCM.open(sealedBox, using: key)
            self.entries = try JSONDecoder().decode([HistoryEntry].self, from: decryptedData)
        } catch {
            print("[Umbra] Failed to decrypt history: \(error)")
        }
    }

    private func saveKeyToKeychain(_ data: Data) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainKey,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    private func loadKeyFromKeychain() -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainKey,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else { return nil }
        return result as? Data
    }
}
