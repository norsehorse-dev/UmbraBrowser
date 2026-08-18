// SettingsView.swift
// Umbra — Privacy-First Browser

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settingsService: SettingsService
    @EnvironmentObject var bookmarkService: BookmarkService
    @EnvironmentObject var tabManager: TabManager
    @EnvironmentObject var whitelistService: WhitelistService
    @EnvironmentObject var blocklistService: BlocklistService
    @EnvironmentObject var storeManager: StoreManager
    @EnvironmentObject var historyService: HistoryService
    @EnvironmentObject var userscriptService: UserscriptService
    @Environment(\.dismiss) private var dismiss
    @State private var showClearDataConfirm = false
    @State private var showBookmarks = false
    @State private var showWhitelist = false
    @State private var showPaywall = false
    @State private var showHistory = false
    @State private var showUserscripts = false

    var body: some View {
        NavigationStack {
            ZStack {
                UmbraTheme.background.ignoresSafeArea()

                List {
                    // MARK: - Subscription
                    if !StoreManager.allFeaturesUnlocked {
                    Section {
                        Button {
                            if storeManager.isPro {
                                Task { await storeManager.manageSubscription() }
                            } else {
                                showPaywall = true
                            }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: storeManager.isPro ? "crown.fill" : "arrow.up.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(storeManager.isPro ? UmbraTheme.warning : UmbraTheme.accent)
                                    .frame(width: 28, height: 28)
                                    .background(
                                        (storeManager.isPro ? UmbraTheme.warning : UmbraTheme.accent).opacity(0.12)
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 6))

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(storeManager.isPro ? storeManager.currentTier.displayName : "Upgrade to Pro")
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(UmbraTheme.textPrimary)

                                    Text(storeManager.isPro ? "Manage subscription" : "Custom DNS, advanced blocklists, priority support")
                                        .font(.system(size: 12))
                                        .foregroundColor(UmbraTheme.textMuted)
                                }

                                Spacer()

                                if !storeManager.isPro {
                                    Text("PRO")
                                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                                        .foregroundColor(UmbraTheme.accent)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(UmbraTheme.accent.opacity(0.12))
                                        .clipShape(RoundedRectangle(cornerRadius: 4))
                                } else {
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12))
                                        .foregroundColor(UmbraTheme.textMuted)
                                }
                            }
                        }
                        .listRowBackground(UmbraTheme.surface)
                    } header: {
                        sectionHeader("Subscription")
                    }
                    }

                    // MARK: - Search
                    Section {
                        Picker("Search Engine", selection: $settingsService.searchEngine) {
                            ForEach(SearchEngine.allCases) { engine in
                                Text(engine.rawValue).tag(engine)
                            }
                        }
                        .listRowBackground(UmbraTheme.surface)
                    } header: {
                        sectionHeader("Search")
                    }

                    // MARK: - Privacy
                    Section {
                        settingsToggle(
                            "Block Ads",
                            icon: "shield.fill",
                            iconColor: UmbraTheme.success,
                            isOn: $settingsService.blockAds
                        )
                        settingsToggle(
                            "Block Trackers",
                            icon: "eye.slash.fill",
                            iconColor: UmbraTheme.accent,
                            isOn: $settingsService.blockTrackers
                        )
                        settingsToggle(
                            "Strip Tracking URLs",
                            icon: "link.badge.plus",
                            iconColor: UmbraTheme.warning,
                            isOn: $settingsService.stripUTM
                        )
                        settingsToggle(
                            "Anti-Fingerprinting",
                            icon: "hand.raised.fill",
                            iconColor: UmbraTheme.danger,
                            isOn: $settingsService.antiFingerprint
                        )
                        settingsToggle(
                            "HTTPS First",
                            icon: "lock.fill",
                            iconColor: UmbraTheme.success,
                            isOn: $settingsService.httpsFirst
                        )
                    } header: {
                        sectionHeader("Privacy & Security")
                    }

                    // MARK: - DNS
                    Section {
                        if storeManager.isPro {
                            Picker("DNS Provider", selection: $settingsService.dohProvider) {
                                ForEach(SettingsService.dohProviders, id: \.id) { provider in
                                    Text(provider.name).tag(provider.id)
                                }
                            }
                            .listRowBackground(UmbraTheme.surface)
                        } else {
                            // Free users see Cloudflare only, with Pro gate on custom
                            HStack {
                                settingsIcon("globe.badge.chevron.backward", color: UmbraTheme.accent)
                                Text("Cloudflare (1.1.1.1)")
                                    .foregroundColor(UmbraTheme.textPrimary)
                                Spacer()
                                Text("PRO")
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .foregroundColor(UmbraTheme.accent)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(UmbraTheme.accent.opacity(0.12))
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                            }
                            .listRowBackground(UmbraTheme.surface)
                            .onTapGesture {
                                showPaywall = true
                            }
                        }
                    } header: {
                        sectionHeader("Encrypted DNS")
                    }

                    // MARK: - Content Blocking
                    Section {
                        // Blocklist status
                        HStack {
                            settingsIcon("shield.checkerboard", color: UmbraTheme.success)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Blocklists")
                                    .foregroundColor(UmbraTheme.textPrimary)
                                if blocklistService.isLoaded {
                                    let ruleCount = blocklistService.manifest?.lists.reduce(0, { $0 + $1.rules }) ?? 0
                                    Text("\(blocklistService.ruleLists.count) lists, \(ruleCount) rules")
                                        .font(.system(size: 12))
                                        .foregroundColor(UmbraTheme.textMuted)
                                } else if blocklistService.isLoading {
                                    Text("Updating...")
                                        .font(.system(size: 12))
                                        .foregroundColor(UmbraTheme.warning)
                                } else if let error = blocklistService.lastError {
                                    Text("Error: \(error)")
                                        .font(.system(size: 12))
                                        .foregroundColor(UmbraTheme.danger)
                                        .lineLimit(1)
                                }
                            }
                            Spacer()
                            if blocklistService.isLoading {
                                ProgressView()
                                    .tint(UmbraTheme.accent)
                            } else {
                                Button {
                                    Task {
                                        await blocklistService.loadRules()
                                        tabManager.updateContentRuleLists(blocklistService.allRuleLists)
                                    }
                                } label: {
                                    Image(systemName: "arrow.clockwise")
                                        .font(.system(size: 13))
                                        .foregroundColor(UmbraTheme.accent)
                                }
                            }
                        }
                        .listRowBackground(UmbraTheme.surface)

                        // Whitelisted sites
                        Button {
                            showWhitelist = true
                        } label: {
                            HStack {
                                settingsIcon("shield.slash", color: UmbraTheme.warning)
                                Text("Whitelisted Sites")
                                    .foregroundColor(UmbraTheme.textPrimary)
                                Spacer()
                                Text("\(whitelistService.domains.count)")
                                    .foregroundColor(UmbraTheme.textMuted)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12))
                                    .foregroundColor(UmbraTheme.textMuted)
                            }
                        }
                        .listRowBackground(UmbraTheme.surface)
                    } header: {
                        sectionHeader("Content Blocking")
                    }

                    // MARK: - Userscripts
                    Section {
                        Button {
                            showUserscripts = true
                        } label: {
                            HStack {
                                settingsIcon("chevron.left.forwardslash.chevron.right", color: UmbraTheme.accent)
                                Text("Userscripts")
                                    .foregroundColor(UmbraTheme.textPrimary)
                                Spacer()
                                let enabledCount = userscriptService.scripts.filter(\.enabled).count
                                if enabledCount > 0 {
                                    Text("\(enabledCount) active")
                                        .foregroundColor(UmbraTheme.textMuted)
                                }
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12))
                                    .foregroundColor(UmbraTheme.textMuted)
                            }
                        }
                        .listRowBackground(UmbraTheme.surface)
                    } header: {
                        sectionHeader("Advanced")
                    }

                    // MARK: - Bookmarks & History
                    Section {
                        Button {
                            showBookmarks = true
                        } label: {
                            HStack {
                                settingsIcon("bookmark.fill", color: UmbraTheme.accent)
                                Text("Bookmarks")
                                    .foregroundColor(UmbraTheme.textPrimary)
                                Spacer()
                                Text("\(bookmarkService.bookmarks.count)")
                                    .foregroundColor(UmbraTheme.textMuted)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12))
                                    .foregroundColor(UmbraTheme.textMuted)
                            }
                        }
                        .listRowBackground(UmbraTheme.surface)

                        Button {
                            showHistory = true
                        } label: {
                            HStack {
                                settingsIcon("clock.fill", color: UmbraTheme.warning)
                                Text("History")
                                    .foregroundColor(UmbraTheme.textPrimary)
                                Spacer()
                                Text("\(historyService.entries.count)")
                                    .foregroundColor(UmbraTheme.textMuted)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12))
                                    .foregroundColor(UmbraTheme.textMuted)
                            }
                        }
                        .listRowBackground(UmbraTheme.surface)
                    } header: {
                        sectionHeader("Data")
                    }

                    // MARK: - Clear Data
                    Section {
                        Button {
                            showClearDataConfirm = true
                        } label: {
                            HStack {
                                settingsIcon("trash.fill", color: UmbraTheme.danger)
                                Text("Close All Tabs & Clear Data")
                                    .foregroundColor(UmbraTheme.danger)
                            }
                        }
                        .listRowBackground(UmbraTheme.surface)
                    }

                    // MARK: - Default Browser
                    Section {
                        Button {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        } label: {
                            HStack {
                                settingsIcon("globe.badge.chevron.backward", color: UmbraTheme.accent)
                                Text("Set as Default Browser")
                                    .foregroundColor(UmbraTheme.textPrimary)
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 12))
                                    .foregroundColor(UmbraTheme.textMuted)
                            }
                        }
                        .listRowBackground(UmbraTheme.surface)
                    }

                    // MARK: - About
                    Section {
                        HStack {
                            Text("Version")
                                .foregroundColor(UmbraTheme.textPrimary)
                            Spacer()
                            Text("1.0.0")
                                .foregroundColor(UmbraTheme.textMuted)
                        }
                        .listRowBackground(UmbraTheme.surface)

                        HStack {
                            Text("Built by")
                                .foregroundColor(UmbraTheme.textPrimary)
                            Spacer()
                            Text("NorseHorse")
                                .foregroundColor(UmbraTheme.textMuted)
                        }
                        .listRowBackground(UmbraTheme.surface)

                        Link(destination: URL(string: "https://umbra.norsehor.se/privacy")!) {
                            HStack {
                                Text("Privacy Policy")
                                    .foregroundColor(UmbraTheme.textPrimary)
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 12))
                                    .foregroundColor(UmbraTheme.textMuted)
                            }
                        }
                        .listRowBackground(UmbraTheme.surface)

                        Link(destination: URL(string: "https://umbra.norsehor.se/terms")!) {
                            HStack {
                                Text("Terms of Use")
                                    .foregroundColor(UmbraTheme.textPrimary)
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 12))
                                    .foregroundColor(UmbraTheme.textMuted)
                            }
                        }
                        .listRowBackground(UmbraTheme.surface)
                    } header: {
                        sectionHeader("About")
                    }
                }
                .scrollContentBackground(.hidden)
                .listStyle(.insetGrouped)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(UmbraTheme.accent)
                }
            }
            .toolbarBackground(UmbraTheme.surface, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .alert("Clear All Data?", isPresented: $showClearDataConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("Clear", role: .destructive) {
                    tabManager.closeAllTabs()
                    dismiss()
                }
            } message: {
                Text("This will close all tabs and clear all browsing data. Bookmarks will be kept.")
            }
            .sheet(isPresented: $showBookmarks) {
                BookmarksView()
            }
            .sheet(isPresented: $showWhitelist) {
                WhitelistView()
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
            .sheet(isPresented: $showHistory) {
                HistoryView()
            }
            .sheet(isPresented: $showUserscripts) {
                UserscriptsView()
            }
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func settingsToggle(
        _ title: String,
        icon: String,
        iconColor: Color,
        isOn: Binding<Bool>
    ) -> some View {
        Toggle(isOn: isOn) {
            HStack(spacing: 10) {
                settingsIcon(icon, color: iconColor)
                Text(title)
                    .foregroundColor(UmbraTheme.textPrimary)
            }
        }
        .tint(UmbraTheme.accent)
        .listRowBackground(UmbraTheme.surface)
    }

    @ViewBuilder
    private func settingsIcon(_ name: String, color: Color) -> some View {
        Image(systemName: name)
            .font(.system(size: 13))
            .foregroundColor(.white)
            .frame(width: 28, height: 28)
            .background(color)
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    @ViewBuilder
    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(UmbraTheme.textMuted)
            .textCase(.uppercase)
            .tracking(0.6)
    }
}
