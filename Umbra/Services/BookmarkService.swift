// BookmarkService.swift
// Umbra — Privacy-First Browser

import Combine
import Foundation
import CryptoKit
import Security

@MainActor
final class BookmarkService: ObservableObject {
    @Published var bookmarks: [Bookmark] = []
    @Published var folders: [BookmarkFolder] = []

    private let keychainKey = "com.umbra.browser.bookmarks.key"
    private let storageURL: URL

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.storageURL = docs.appendingPathComponent("bookmarks.enc")
        loadBookmarks()
    }

    // MARK: - CRUD

    func addBookmark(title: String, url: URL, folder: String? = nil, favicon: Data? = nil) {
        let bookmark = Bookmark(
            title: title,
            url: url,
            folder: folder,
            favicon: favicon,
            sortOrder: bookmarks.count
        )
        bookmarks.append(bookmark)
        saveBookmarks()
    }

    func removeBookmark(_ bookmark: Bookmark) {
        bookmarks.removeAll { $0.id == bookmark.id }
        saveBookmarks()
    }

    func updateBookmark(_ bookmark: Bookmark) {
        guard let index = bookmarks.firstIndex(where: { $0.id == bookmark.id }) else { return }
        bookmarks[index] = bookmark
        saveBookmarks()
    }

    func addFolder(name: String) {
        let folder = BookmarkFolder(name: name, sortOrder: folders.count)
        folders.append(folder)
        saveBookmarks()
    }

    func removeFolder(_ folder: BookmarkFolder) {
        // Move bookmarks out of folder
        for i in bookmarks.indices {
            if bookmarks[i].folder == folder.name {
                bookmarks[i].folder = nil
            }
        }
        folders.removeAll { $0.id == folder.id }
        saveBookmarks()
    }

    func bookmarks(in folder: String?) -> [Bookmark] {
        bookmarks.filter { $0.folder == folder }.sorted { $0.sortOrder < $1.sortOrder }
    }

    func isBookmarked(url: URL) -> Bool {
        bookmarks.contains { $0.url == url }
    }

    // MARK: - Encrypted Storage (AES-256-GCM via CryptoKit)

    private func getOrCreateKey() -> SymmetricKey {
        // Try to load from Keychain
        if let keyData = loadKeyFromKeychain() {
            return SymmetricKey(data: keyData)
        }

        // Generate new key
        let key = SymmetricKey(size: .bits256)
        let keyData = key.withUnsafeBytes { Data($0) }
        saveKeyToKeychain(keyData)
        return key
    }

    private func saveBookmarks() {
        let payload = BookmarkPayload(bookmarks: bookmarks, folders: folders)

        guard let jsonData = try? JSONEncoder().encode(payload) else {
            print("[Umbra] Failed to encode bookmarks")
            return
        }

        let key = getOrCreateKey()

        do {
            let sealedBox = try AES.GCM.seal(jsonData, using: key)
            guard let combined = sealedBox.combined else { return }
            try combined.write(to: storageURL)
        } catch {
            print("[Umbra] Failed to encrypt bookmarks: \(error)")
        }
    }

    private func loadBookmarks() {
        guard FileManager.default.fileExists(atPath: storageURL.path) else { return }

        do {
            let encryptedData = try Data(contentsOf: storageURL)
            let key = getOrCreateKey()
            let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
            let decryptedData = try AES.GCM.open(sealedBox, using: key)
            let payload = try JSONDecoder().decode(BookmarkPayload.self, from: decryptedData)
            self.bookmarks = payload.bookmarks
            self.folders = payload.folders
        } catch {
            print("[Umbra] Failed to decrypt bookmarks: \(error)")
        }
    }

    // MARK: - Keychain

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

private struct BookmarkPayload: Codable {
    let bookmarks: [Bookmark]
    let folders: [BookmarkFolder]
}
