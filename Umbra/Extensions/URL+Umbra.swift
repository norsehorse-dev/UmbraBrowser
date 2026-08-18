// URL+Umbra.swift
// Umbra — Privacy-First Browser

import Foundation

extension URL {
    /// Strip tracking parameters from URLs
    static let trackingParams: Set<String> = [
        "utm_source", "utm_medium", "utm_campaign", "utm_term", "utm_content",
        "fbclid", "gclid", "gclsrc", "dclid", "gbraid", "wbraid",
        "msclkid", "twclid", "sc_campaign", "sc_channel", "sc_content",
        "sc_medium", "sc_outcome", "sc_geo", "sc_country",
        "mc_cid", "mc_eid", "oly_anon_id", "oly_enc_id",
        "_openstat", "vero_id", "wickedid", "yclid", "rb_clickid",
        "s_cid", "ml_subscriber", "ml_subscriber_hash",
        "ttclid", "li_fat_id"
    ]

    func strippingTrackingParams() -> URL {
        guard var components = URLComponents(url: self, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems,
              !queryItems.isEmpty else {
            return self
        }

        let filtered = queryItems.filter { item in
            !URL.trackingParams.contains(item.name.lowercased())
        }

        components.queryItems = filtered.isEmpty ? nil : filtered
        return components.url ?? self
    }

    /// Display-friendly host string
    var displayHost: String {
        guard let host = self.host else { return self.absoluteString }
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }
}

extension String {
    /// Convert user input to URL — handle search queries vs URLs
    func toNavigableURL(searchEngine: SearchEngine = .duckduckgo) -> URL? {
        let trimmed = self.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // Already a valid URL with scheme
        if let url = URL(string: trimmed), let scheme = url.scheme,
           ["http", "https"].contains(scheme.lowercased()) {
            return url
        }

        // Looks like a domain (contains a dot, no spaces)
        if trimmed.contains(".") && !trimmed.contains(" ") {
            let withScheme = "https://\(trimmed)"
            if let url = URL(string: withScheme) {
                return url
            }
        }

        // Treat as search query
        let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? trimmed
        return URL(string: searchEngine.searchURL(for: encoded))
    }
}
