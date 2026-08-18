// SettingsService.swift
// Umbra — Privacy-First Browser

import Combine
import Foundation
import SwiftUI

@MainActor
final class SettingsService: ObservableObject {
    @AppStorage("searchEngine") var searchEngine: SearchEngine = .duckduckgo
    @AppStorage("blockAds") var blockAds: Bool = true
    @AppStorage("blockTrackers") var blockTrackers: Bool = true
    @AppStorage("stripUTM") var stripUTM: Bool = true
    @AppStorage("antiFingerprint") var antiFingerprint: Bool = true
    @AppStorage("httpsFirst") var httpsFirst: Bool = true
    @AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding: Bool = false

    // DNS-over-HTTPS provider
    @AppStorage("dohProvider") var dohProvider: String = "cloudflare"

    static let dohProviders: [(id: String, name: String, url: String)] = [
        ("cloudflare", "Cloudflare (1.1.1.1)", "https://cloudflare-dns.com/dns-query"),
        ("google", "Google (8.8.8.8)", "https://dns.google/dns-query"),
        ("quad9", "Quad9 (9.9.9.9)", "https://dns.quad9.net/dns-query")
    ]

    var selectedDOHURL: String {
        SettingsService.dohProviders.first { $0.id == dohProvider }?.url
            ?? SettingsService.dohProviders[0].url
    }
}

// Make SearchEngine work with @AppStorage
extension SearchEngine: RawRepresentable {
    // Already RawRepresentable via String rawValue
}
