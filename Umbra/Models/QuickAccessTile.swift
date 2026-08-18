// QuickAccessTile.swift
// Umbra — Privacy-First Browser

import Foundation

struct QuickAccessTile: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var url: URL
    var iconURL: URL?

    init(id: UUID = UUID(), title: String, url: URL, iconURL: URL? = nil) {
        self.id = id
        self.title = title
        self.url = url
        self.iconURL = iconURL
    }

    static let defaults: [QuickAccessTile] = [
        QuickAccessTile(
            title: "DuckDuckGo",
            url: URL(string: "https://duckduckgo.com")!
        ),
        QuickAccessTile(
            title: "Wikipedia",
            url: URL(string: "https://wikipedia.org")!
        ),
        QuickAccessTile(
            title: "Reddit",
            url: URL(string: "https://reddit.com")!
        ),
        QuickAccessTile(
            title: "GitHub",
            url: URL(string: "https://github.com")!
        ),
        QuickAccessTile(
            title: "Hacker News",
            url: URL(string: "https://news.ycombinator.com")!
        ),
        QuickAccessTile(
            title: "Stack Overflow",
            url: URL(string: "https://stackoverflow.com")!
        )
    ]
}
