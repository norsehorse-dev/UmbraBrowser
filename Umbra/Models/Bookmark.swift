// Bookmark.swift
// Umbra — Privacy-First Browser

import Foundation

struct Bookmark: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var url: URL
    var folder: String?
    var favicon: Data?
    var createdAt: Date
    var sortOrder: Int

    init(
        id: UUID = UUID(),
        title: String,
        url: URL,
        folder: String? = nil,
        favicon: Data? = nil,
        createdAt: Date = Date(),
        sortOrder: Int = 0
    ) {
        self.id = id
        self.title = title
        self.url = url
        self.folder = folder
        self.favicon = favicon
        self.createdAt = createdAt
        self.sortOrder = sortOrder
    }
}

struct BookmarkFolder: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var sortOrder: Int

    init(id: UUID = UUID(), name: String, sortOrder: Int = 0) {
        self.id = id
        self.name = name
        self.sortOrder = sortOrder
    }
}
