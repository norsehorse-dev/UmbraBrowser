// MainBrowserView.swift
// Umbra — Privacy-First Browser

import SwiftUI

struct MainBrowserView: View {
    @EnvironmentObject var tabManager: TabManager
    @EnvironmentObject var settingsService: SettingsService
    @State private var showSettings = false

    var body: some View {
        ZStack {
            UmbraTheme.background.ignoresSafeArea()

            if !settingsService.hasCompletedOnboarding {
                OnboardingView()
            } else {
                VStack(spacing: 0) {
                    // Active tab content
                    if let activeTab = tabManager.activeTab {
                        ActiveTabContainer(tab: activeTab)
                            .id(activeTab.id)
                    }

                    // Progress bar
                    if let activeTab = tabManager.activeTab, activeTab.isLoading {
                        ProgressView(value: activeTab.estimatedProgress)
                            .progressViewStyle(LinearProgressViewStyle())
                            .tint(UmbraTheme.accent)
                            .frame(height: 2)
                    }

                    // Address bar
                    AddressBarView()

                    // Bottom toolbar
                    BottomToolbarView(showSettings: $showSettings)
                }
            }
        }
        .sheet(isPresented: $tabManager.showTabSwitcher) {
            TabSwitcherView()
                .onAppear {
                    tabManager.captureAllThumbnails()
                }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
    }
}

/// Separate view that observes the active tab so SwiftUI re-renders
/// when the tab's URL changes (e.g., from nil to a real URL after search).
struct ActiveTabContainer: View {
    @ObservedObject var tab: BrowserTab

    var body: some View {
        ZStack {
            if tab.url == nil {
                NewTabView()
            } else {
                BrowserWebView(tab: tab)

                // HTTP warning interstitial — shown when HTTPS falls back to HTTP
                if tab.isInsecureFallback && !tab.httpWarningDismissed {
                    HTTPWarningView(tab: tab)
                        .transition(.opacity)
                        .zIndex(10)
                }
            }
        }
        .animation(UmbraTheme.animationDefault, value: tab.isInsecureFallback)
        .animation(UmbraTheme.animationDefault, value: tab.httpWarningDismissed)
    }
}
