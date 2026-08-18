// SearchEngine.swift
// Umbra — Privacy-First Browser

import Foundation

enum SearchEngine: String, CaseIterable, Codable, Identifiable {
    case duckduckgo = "DuckDuckGo"
    case startpage = "Startpage"
    case brave = "Brave Search"

    var id: String { rawValue }

    var baseURL: String {
        switch self {
        case .duckduckgo: return "https://duckduckgo.com/"
        case .startpage: return "https://www.startpage.com/"
        case .brave: return "https://search.brave.com/"
        }
    }

    func searchURL(for query: String) -> String {
        switch self {
        case .duckduckgo: return "https://duckduckgo.com/?q=\(query)"
        case .startpage: return "https://www.startpage.com/do/dsearch?query=\(query)"
        case .brave: return "https://search.brave.com/search?q=\(query)"
        }
    }

    var iconName: String {
        switch self {
        case .duckduckgo: return "magnifyingglass"
        case .startpage: return "magnifyingglass.circle"
        case .brave: return "magnifyingglass.circle.fill"
        }
    }
}
