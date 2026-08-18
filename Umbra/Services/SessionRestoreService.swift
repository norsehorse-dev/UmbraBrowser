// SessionRestoreService.swift
// Umbra — Privacy-First Browser

import Foundation

struct SavedTab: Codable {
    let url: String
    let title: String
    let isPinned: Bool
}

struct SavedSession: Codable {
    let tabs: [SavedTab]
    let activeIndex: Int
    let savedAt: Date
}

enum SessionRestoreService {
    private static var storageURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("session.json")
    }

    /// Save current tab state
    static func saveSession(tabs: [(url: URL?, title: String, isPinned: Bool)], activeIndex: Int) {
        let savedTabs = tabs.compactMap { tab -> SavedTab? in
            guard let url = tab.url else { return nil }
            return SavedTab(url: url.absoluteString, title: tab.title, isPinned: tab.isPinned)
        }

        guard !savedTabs.isEmpty else { return }

        let session = SavedSession(
            tabs: savedTabs,
            activeIndex: min(activeIndex, savedTabs.count - 1),
            savedAt: Date()
        )

        do {
            let data = try JSONEncoder().encode(session)
            try data.write(to: storageURL)
        } catch {
            print("[Umbra] Failed to save session: \(error)")
        }
    }

    /// Load saved session
    static func loadSession() -> SavedSession? {
        guard FileManager.default.fileExists(atPath: storageURL.path) else { return nil }

        do {
            let data = try Data(contentsOf: storageURL)
            let session = try JSONDecoder().decode(SavedSession.self, from: data)

            // Don't restore sessions older than 7 days
            if session.savedAt.timeIntervalSinceNow < -7 * 24 * 3600 {
                clearSession()
                return nil
            }

            return session
        } catch {
            print("[Umbra] Failed to load session: \(error)")
            return nil
        }
    }

    /// Clear saved session
    static func clearSession() {
        try? FileManager.default.removeItem(at: storageURL)
    }

    /// Check if a saved session exists
    static var hasSavedSession: Bool {
        FileManager.default.fileExists(atPath: storageURL.path)
    }
}
