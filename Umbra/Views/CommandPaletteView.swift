// CommandPaletteView.swift
// Umbra — Privacy-First Browser

import SwiftUI

struct CommandPaletteItem: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let subtitle: String
    let category: Category
    let action: () -> Void

    enum Category: String {
        case tab = "Tabs"
        case bookmark = "Bookmarks"
        case history = "History"
        case action = "Actions"
    }
}

struct CommandPaletteView: View {
    @EnvironmentObject var tabManager: TabManager
    @EnvironmentObject var bookmarkService: BookmarkService
    @EnvironmentObject var historyService: HistoryService
    @Environment(\.dismiss) private var dismiss
    @State private var query: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                UmbraTheme.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Search field
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 15))
                            .foregroundColor(UmbraTheme.textMuted)

                        TextField("Search tabs, bookmarks, history...", text: $query)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .font(.system(size: 15))
                            .foregroundColor(UmbraTheme.textPrimary)
                            .focused($isFocused)

                        if !query.isEmpty {
                            Button {
                                query = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(UmbraTheme.textMuted)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(UmbraTheme.surfaceElevated)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                    // Results
                    let items = buildResults()
                    if items.isEmpty && !query.isEmpty {
                        Spacer()
                        VStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 28))
                                .foregroundColor(UmbraTheme.textMuted)
                            Text("No results")
                                .font(.system(size: 15))
                                .foregroundColor(UmbraTheme.textMuted)
                        }
                        Spacer()
                    } else if items.isEmpty {
                        // Show quick actions when empty
                        List {
                            Section {
                                actionRow(icon: "plus", title: "New Tab") {
                                    tabManager.createNewTab()
                                    dismiss()
                                }
                                actionRow(icon: "arrow.clockwise", title: "Reload Page") {
                                    tabManager.activeTab?.reload()
                                    dismiss()
                                }
                                actionRow(icon: "bookmark", title: "Bookmark This Page") {
                                    if let tab = tabManager.activeTab, let url = tab.url {
                                        bookmarkService.addBookmark(title: tab.title, url: url)
                                    }
                                    dismiss()
                                }
                                actionRow(icon: "doc.plaintext", title: "Reader Mode") {
                                    tabManager.activeTab?.toggleReaderMode()
                                    dismiss()
                                }
                            } header: {
                                sectionHeader("Quick actions")
                            }
                        }
                        .scrollContentBackground(.hidden)
                        .listStyle(.insetGrouped)
                    } else {
                        List {
                            let grouped = Dictionary(grouping: items, by: { $0.category.rawValue })
                            let order: [CommandPaletteItem.Category] = [.tab, .bookmark, .history, .action]

                            ForEach(order, id: \.rawValue) { category in
                                if let group = grouped[category.rawValue], !group.isEmpty {
                                    Section {
                                        ForEach(group) { item in
                                            Button {
                                                item.action()
                                                dismiss()
                                            } label: {
                                                HStack(spacing: 12) {
                                                    Image(systemName: item.icon)
                                                        .font(.system(size: 13))
                                                        .foregroundColor(UmbraTheme.textMuted)
                                                        .frame(width: 22)

                                                    VStack(alignment: .leading, spacing: 1) {
                                                        Text(item.title)
                                                            .font(.system(size: 14))
                                                            .foregroundColor(UmbraTheme.textPrimary)
                                                            .lineLimit(1)

                                                        Text(item.subtitle)
                                                            .font(.system(size: 11))
                                                            .foregroundColor(UmbraTheme.textMuted)
                                                            .lineLimit(1)
                                                    }
                                                }
                                            }
                                            .listRowBackground(UmbraTheme.surface)
                                        }
                                    } header: {
                                        sectionHeader(category.rawValue)
                                    }
                                }
                            }
                        }
                        .scrollContentBackground(.hidden)
                        .listStyle(.insetGrouped)
                    }
                }
            }
            .navigationTitle("Command Palette")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(UmbraTheme.accent)
                }
            }
            .toolbarBackground(UmbraTheme.surface, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    isFocused = true
                }
            }
        }
    }

    // MARK: - Build Results

    private func buildResults() -> [CommandPaletteItem] {
        guard !query.isEmpty else { return [] }
        let lowered = query.lowercased()
        var results: [CommandPaletteItem] = []

        // Search open tabs
        for tab in tabManager.tabs {
            let titleMatch = tab.title.lowercased().contains(lowered)
            let urlMatch = tab.url?.absoluteString.lowercased().contains(lowered) ?? false
            if titleMatch || urlMatch {
                let capturedTab = tab
                results.append(CommandPaletteItem(
                    icon: "square.on.square",
                    title: tab.title,
                    subtitle: tab.url?.displayHost ?? "New Tab",
                    category: .tab,
                    action: { tabManager.activateTab(capturedTab) }
                ))
            }
        }

        // Search bookmarks
        for bookmark in bookmarkService.bookmarks.prefix(100) {
            let titleMatch = bookmark.title.lowercased().contains(lowered)
            let urlMatch = bookmark.url.absoluteString.lowercased().contains(lowered)
            if titleMatch || urlMatch {
                let url = bookmark.url
                results.append(CommandPaletteItem(
                    icon: "bookmark.fill",
                    title: bookmark.title,
                    subtitle: bookmark.url.displayHost,
                    category: .bookmark,
                    action: { tabManager.activeTab?.load(url) }
                ))
            }
        }

        // Search history
        for entry in historyService.entries.prefix(200) {
            let titleMatch = entry.title.lowercased().contains(lowered)
            let urlMatch = entry.url.absoluteString.lowercased().contains(lowered)
            if titleMatch || urlMatch {
                let url = entry.url
                results.append(CommandPaletteItem(
                    icon: "clock",
                    title: entry.title,
                    subtitle: entry.domain,
                    category: .history,
                    action: { tabManager.activeTab?.load(url) }
                ))
            }
        }

        // Search actions
        let actions: [(String, String, String, () -> Void)] = [
            ("plus", "New Tab", "Open a new empty tab", { tabManager.createNewTab() }),
            ("arrow.clockwise", "Reload", "Reload current page", { tabManager.activeTab?.reload() }),
            ("doc.plaintext", "Reader Mode", "Toggle reader mode", { tabManager.activeTab?.toggleReaderMode() }),
            ("magnifyingglass", "Find on Page", "Search text on current page", {}),
            ("gearshape", "Settings", "Open app settings", {}),
            ("trash", "Close All Tabs", "Close all open tabs", { tabManager.closeAllTabs() }),
        ]

        for (icon, title, subtitle, action) in actions {
            if title.lowercased().contains(lowered) {
                results.append(CommandPaletteItem(
                    icon: icon, title: title, subtitle: subtitle,
                    category: .action, action: action
                ))
            }
        }

        return results
    }

    // MARK: - Helpers

    @ViewBuilder
    private func actionRow(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(UmbraTheme.accent)
                    .frame(width: 22)

                Text(title)
                    .font(.system(size: 15))
                    .foregroundColor(UmbraTheme.textPrimary)
            }
        }
        .listRowBackground(UmbraTheme.surface)
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
