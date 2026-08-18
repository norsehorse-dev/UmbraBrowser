// BottomToolbarView.swift
// Umbra — Privacy-First Browser

import SwiftUI

struct BottomToolbarView: View {
    @EnvironmentObject var tabManager: TabManager
    @EnvironmentObject var bookmarkService: BookmarkService
    @Binding var showSettings: Bool
    @State private var showCommandPalette = false

    private var activeTab: BrowserTab? { tabManager.activeTab }

    var body: some View {
        HStack(spacing: 0) {
            // Bookmark
            toolbarButton(
                icon: isCurrentPageBookmarked ? "bookmark.fill" : "bookmark",
                enabled: activeTab?.url != nil,
                tint: isCurrentPageBookmarked ? UmbraTheme.accent : nil
            ) {
                toggleBookmark()
            }

            // Command palette (search everything)
            toolbarButton(icon: "text.magnifyingglass") {
                showCommandPalette = true
            }

            // Tabs
            Button {
                tabManager.showTabSwitcher = true
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(UmbraTheme.textSecondary, lineWidth: 1.5)
                        .frame(width: 22, height: 22)

                    Text("\(tabManager.tabCount)")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(UmbraTheme.textSecondary)
                }
            }
            .frame(maxWidth: .infinity)

            // New tab
            toolbarButton(icon: "plus") {
                tabManager.createNewTab()
            }

            // Settings
            toolbarButton(icon: "gearshape") {
                showSettings = true
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .padding(.bottom, 2)
        .background(UmbraTheme.surface)
        .sheet(isPresented: $showCommandPalette) {
            CommandPaletteView()
        }
    }

    private var isCurrentPageBookmarked: Bool {
        guard let url = activeTab?.url else { return false }
        return bookmarkService.isBookmarked(url: url)
    }

    private func toggleBookmark() {
        guard let tab = activeTab, let url = tab.url else { return }

        if bookmarkService.isBookmarked(url: url) {
            if let bookmark = bookmarkService.bookmarks.first(where: { $0.url == url }) {
                bookmarkService.removeBookmark(bookmark)
            }
        } else {
            bookmarkService.addBookmark(title: tab.title, url: url)
        }
    }

    @ViewBuilder
    private func toolbarButton(
        icon: String,
        enabled: Bool = true,
        tint: Color? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(
                    enabled
                        ? (tint ?? UmbraTheme.textSecondary)
                        : UmbraTheme.textMuted.opacity(0.3)
                )
        }
        .disabled(!enabled)
        .frame(maxWidth: .infinity)
    }
}
