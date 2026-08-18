// TabManager.swift
// Umbra — Privacy-First Browser

import Combine
import Foundation
import WebKit
import SwiftUI

@MainActor
final class TabManager: ObservableObject {
    @Published var tabs: [BrowserTab] = []
    @Published var activeTabID: UUID?
    @Published var showTabSwitcher: Bool = false

    var activeTab: BrowserTab? {
        guard let id = activeTabID else { return nil }
        return tabs.first { $0.id == id }
    }

    var tabCount: Int { tabs.count }

    // Content rule lists to attach to new tabs
    var contentRuleLists: [WKContentRuleList] = []

    // Reference to whitelist service for per-site blocking toggle
    var whitelistService: WhitelistService?

    init() {
        // Create initial tab
        createNewTab()
    }

    // MARK: - Tab Lifecycle

    @discardableResult
    func createNewTab(url: URL? = nil) -> BrowserTab {
        let blockingDisabled: Bool
        if let url = url, let whitelist = whitelistService {
            blockingDisabled = whitelist.isWhitelisted(url: url)
        } else {
            blockingDisabled = false
        }

        let tab = BrowserTab(
            contentRuleLists: contentRuleLists,
            blockingDisabled: blockingDisabled
        )
        tabs.append(tab)
        activeTabID = tab.id

        if let url = url {
            tab.load(url)
        }

        return tab
    }

    func closeTab(_ tab: BrowserTab) {
        guard let index = tabs.firstIndex(of: tab) else { return }

        tabs.remove(at: index)

        // If we closed the active tab, activate an adjacent one
        if activeTabID == tab.id {
            if tabs.isEmpty {
                createNewTab()
            } else {
                let newIndex = min(index, tabs.count - 1)
                activeTabID = tabs[newIndex].id
            }
        }

        // Clean up the web view's data store
        tab.dataStore.fetchDataRecords(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes()) { records in
            tab.dataStore.removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), for: records) {}
        }
    }

    func closeTab(at index: Int) {
        guard index >= 0 && index < tabs.count else { return }
        closeTab(tabs[index])
    }

    func closeAllTabs() {
        let allTabs = tabs
        tabs.removeAll()
        activeTabID = nil

        for tab in allTabs {
            tab.dataStore.fetchDataRecords(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes()) { records in
                tab.dataStore.removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), for: records) {}
            }
        }

        createNewTab()
    }

    func activateTab(_ tab: BrowserTab) {
        // Capture thumbnail of the tab we're leaving
        activeTab?.captureThumbnail()
        activeTabID = tab.id
    }

    func activateTab(at index: Int) {
        guard index >= 0 && index < tabs.count else { return }
        activeTab?.captureThumbnail()
        activeTabID = tabs[index].id
    }

    /// Capture thumbnails for all tabs (call before showing tab switcher)
    func captureAllThumbnails() {
        for tab in tabs {
            tab.captureThumbnail()
        }
    }

    func moveTab(from source: IndexSet, to destination: Int) {
        tabs.move(fromOffsets: source, toOffset: destination)
    }

    // MARK: - Content Rules

    func updateContentRuleLists(_ lists: [WKContentRuleList]) {
        self.contentRuleLists = lists
    }

    // MARK: - Session Save/Restore

    func saveSession() {
        let activeIndex = tabs.firstIndex(where: { $0.id == activeTabID }) ?? 0
        let tabData = tabs.map { tab in
            (url: tab.url, title: tab.title, isPinned: tab.isPinned)
        }
        SessionRestoreService.saveSession(tabs: tabData, activeIndex: activeIndex)
    }

    func restoreSession() {
        guard let session = SessionRestoreService.loadSession() else { return }
        guard !session.tabs.isEmpty else { return }

        // Close the default empty tab
        if tabs.count == 1 && tabs.first?.url == nil {
            tabs.removeAll()
        }

        for savedTab in session.tabs {
            guard let url = URL(string: savedTab.url) else { continue }
            let tab = createNewTab(url: url)
            tab.isPinned = savedTab.isPinned
        }

        // Activate the previously active tab
        let index = min(session.activeIndex, tabs.count - 1)
        if index >= 0 && index < tabs.count {
            activeTabID = tabs[index].id
        }
    }

    // MARK: - Pinned Tabs

    var pinnedTabs: [BrowserTab] {
        tabs.filter { $0.isPinned }
    }

    var unpinnedTabs: [BrowserTab] {
        tabs.filter { !$0.isPinned }
    }

    // MARK: - Audio Polling

    func pollAudioState() {
        for tab in tabs {
            tab.checkAudioPlaying()
        }
    }
}
