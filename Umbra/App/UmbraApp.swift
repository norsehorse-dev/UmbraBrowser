// UmbraApp.swift
// Umbra — Privacy-First Browser
// Bundle ID: com.umbra.browser

import SwiftUI

@main
struct UmbraApp: App {
    @StateObject private var tabManager = TabManager()
    @StateObject private var settingsService = SettingsService()
    @StateObject private var bookmarkService = BookmarkService()
    @StateObject private var whitelistService = WhitelistService()
    @StateObject private var blocklistService = BlocklistService()
    @StateObject private var storeManager = StoreManager()
    @StateObject private var historyService = HistoryService()
    @StateObject private var userscriptService = UserscriptService()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            MainBrowserView()
                .environmentObject(tabManager)
                .environmentObject(settingsService)
                .environmentObject(bookmarkService)
                .environmentObject(whitelistService)
                .environmentObject(blocklistService)
                .environmentObject(storeManager)
                .environmentObject(historyService)
                .environmentObject(userscriptService)
                .preferredColorScheme(.dark)
                .onAppear {
                    configureAppearance()
                    tabManager.whitelistService = whitelistService
                    tabManager.restoreSession()
                }
                .task {
                    await loadBlocklists()
                }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .background || newPhase == .inactive {
                        tabManager.saveSession()
                    }
                }
        }
    }

    private func loadBlocklists() async {
        await blocklistService.loadRules()
        tabManager.updateContentRuleLists(blocklistService.allRuleLists)
    }

    private func configureAppearance() {
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()
        navAppearance.backgroundColor = UIColor(UmbraTheme.background)
        navAppearance.titleTextAttributes = [.foregroundColor: UIColor(UmbraTheme.textPrimary)]
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance

        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithOpaqueBackground()
        tabAppearance.backgroundColor = UIColor(UmbraTheme.surface)
        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance
    }
}
