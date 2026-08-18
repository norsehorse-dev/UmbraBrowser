// AddressBarView.swift
// Umbra — Privacy-First Browser

import SwiftUI

struct AddressBarView: View {
    @EnvironmentObject var tabManager: TabManager
    @EnvironmentObject var settingsService: SettingsService
    @EnvironmentObject var whitelistService: WhitelistService
    @EnvironmentObject var bookmarkService: BookmarkService
    @EnvironmentObject var historyService: HistoryService
    @State private var inputText: String = ""
    @State private var isEditing: Bool = false
    @State private var showBlockBreakdown: Bool = false
    @State private var showSSLCertificate: Bool = false
    @State private var showFindBar: Bool = false
    @State private var findText: String = ""
    @FocusState private var isFocused: Bool
    @FocusState private var isFindFocused: Bool

    private var activeTab: BrowserTab? { tabManager.activeTab }

    var body: some View {
        VStack(spacing: 0) {
            // Find in page bar (slides down above address bar)
            if showFindBar {
                findBar
            }

            if isEditing {
                // Editing mode — text field + autocomplete
                VStack(spacing: 0) {
                    editingBar
                    if !inputText.isEmpty {
                        autocompleteDropdown
                    }
                }
            } else {
                // Display mode — centered domain with nav + actions
                displayBar
            }
        }
    }

    // MARK: - Display Bar

    private var displayBar: some View {
        HStack(spacing: 0) {
            // Left: nav arrows
            HStack(spacing: 4) {
                if let tab = activeTab, tab.url != nil {
                    Button { tab.goBack() } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(tab.canGoBack ? UmbraTheme.textSecondary : UmbraTheme.textMuted.opacity(0.3))
                            .frame(width: 36, height: 36)
                    }
                    .disabled(!tab.canGoBack)

                    Button { tab.goForward() } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(tab.canGoForward ? UmbraTheme.textSecondary : UmbraTheme.textMuted.opacity(0.3))
                            .frame(width: 36, height: 36)
                    }
                    .disabled(!tab.canGoForward)
                } else {
                    Color.clear.frame(width: 76, height: 36)
                }
            }

            Spacer(minLength: 4)

            // Center: lock + domain (tappable to edit)
            Button {
                startEditing()
            } label: {
                HStack(spacing: 6) {
                    if let tab = activeTab, tab.url != nil {
                        Button {
                            showSSLCertificate = true
                        } label: {
                            Image(systemName: lockIcon(for: tab))
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(lockColor(for: tab))
                        }
                    }

                    Text(displayURL)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(activeTab?.url != nil ? UmbraTheme.textPrimary : UmbraTheme.textMuted)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 4)

            // Right: reader mode + shield + overflow
            HStack(spacing: 2) {
                if let tab = activeTab, tab.url != nil {
                    // Reader mode button
                    if tab.isReaderModeAvailable || tab.isReaderModeActive {
                        Button {
                            tab.toggleReaderMode()
                        } label: {
                            Image(systemName: tab.isReaderModeActive ? "doc.plaintext.fill" : "doc.plaintext")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(tab.isReaderModeActive ? UmbraTheme.accent : UmbraTheme.textMuted)
                                .frame(width: 32, height: 36)
                        }
                    }

                    // Shield badge
                    Button {
                        showBlockBreakdown = true
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "shield.fill")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(tab.blockedCount > 0 ? UmbraTheme.success : UmbraTheme.textMuted.opacity(0.4))

                            if tab.blockedCount > 0 {
                                Text("\(tab.blockedCount)")
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundColor(UmbraTheme.success)
                            }
                        }
                        .frame(height: 36)
                        .padding(.horizontal, 4)
                    }

                    // Overflow menu
                    Menu {
                        if let url = tab.url {
                            ShareLink(item: settingsService.stripUTM ? url.strippingTrackingParams() : url) {
                                Label("Share", systemImage: "square.and.arrow.up")
                            }
                        }

                        Button {
                            tab.reload()
                        } label: {
                            Label("Reload", systemImage: "arrow.clockwise")
                        }

                        if tab.isLoading {
                            Button {
                                tab.stopLoading()
                            } label: {
                                Label("Stop", systemImage: "xmark")
                            }
                        }

                        Divider()

                        Button {
                            showFindBar.toggle()
                            if showFindBar {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    isFindFocused = true
                                }
                            } else {
                                tab.clearFindHighlights()
                                findText = ""
                            }
                        } label: {
                            Label(showFindBar ? "Close Find" : "Find on Page", systemImage: "magnifyingglass")
                        }

                        if tab.isReaderModeAvailable || tab.isReaderModeActive {
                            Button {
                                tab.toggleReaderMode()
                            } label: {
                                Label(tab.isReaderModeActive ? "Exit Reader" : "Reader Mode", systemImage: "doc.plaintext")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(UmbraTheme.textMuted)
                            .frame(width: 36, height: 36)
                    }
                } else {
                    Color.clear.frame(width: 76, height: 36)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(UmbraTheme.surface)
        .overlay(
            Rectangle()
                .fill(UmbraTheme.border.opacity(0.5))
                .frame(height: 0.5),
            alignment: .top
        )
        .sheet(isPresented: $showBlockBreakdown) {
            if let tab = activeTab {
                BlockBreakdownView(tab: tab)
            }
        }
        .sheet(isPresented: $showSSLCertificate) {
            if let tab = activeTab {
                SSLCertificateView(tab: tab)
            }
        }
    }

    // MARK: - Find Bar

    private var findBar: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13))
                    .foregroundColor(UmbraTheme.textMuted)

                TextField("Find on page", text: $findText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.system(size: 14))
                    .foregroundColor(UmbraTheme.textPrimary)
                    .focused($isFindFocused)
                    .onSubmit {
                        activeTab?.findInPage(findText)
                    }
                    .onChange(of: findText) { _, newValue in
                        activeTab?.findInPage(newValue)
                    }

                if let tab = activeTab, tab.findResultCount > 0 {
                    Text("\(tab.findResultCount)")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(UmbraTheme.textMuted)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(UmbraTheme.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            // Previous / Next
            Button { activeTab?.findPrevious() } label: {
                Image(systemName: "chevron.up")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(UmbraTheme.textSecondary)
            }
            .frame(width: 28)

            Button { activeTab?.findNext() } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(UmbraTheme.textSecondary)
            }
            .frame(width: 28)

            // Close
            Button {
                showFindBar = false
                activeTab?.clearFindHighlights()
                findText = ""
                isFindFocused = false
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(UmbraTheme.textMuted)
            }
            .frame(width: 28)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(UmbraTheme.surface)
        .overlay(
            Rectangle()
                .fill(UmbraTheme.border.opacity(0.5))
                .frame(height: 0.5),
            alignment: .bottom
        )
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    // MARK: - Editing Bar

    private var editingBar: some View {
        HStack(spacing: 8) {
            Button {
                isEditing = false
                isFocused = false
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(UmbraTheme.textSecondary)
                    .frame(width: 36, height: 36)
            }

            HStack(spacing: 7) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(UmbraTheme.textMuted)

                TextField("Search or enter URL", text: $inputText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.webSearch)
                    .font(.system(size: 14))
                    .foregroundColor(UmbraTheme.textPrimary)
                    .focused($isFocused)
                    .onSubmit {
                        navigateTo(inputText)
                    }

                if !inputText.isEmpty {
                    Button {
                        inputText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(UmbraTheme.textMuted)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(UmbraTheme.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(UmbraTheme.accent.opacity(0.5), lineWidth: 1)
            )
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(UmbraTheme.surface)
        .overlay(
            Rectangle()
                .fill(UmbraTheme.border.opacity(0.5))
                .frame(height: 0.5),
            alignment: .top
        )
        .onChange(of: isFocused) { _, focused in
            if !focused {
                isEditing = false
            }
        }
    }

    // MARK: - Autocomplete Dropdown

    private var autocompleteDropdown: some View {
        let suggestions = autocompleteSuggestions(for: inputText)
        return Group {
            if !suggestions.isEmpty {
                VStack(spacing: 0) {
                    ForEach(suggestions.prefix(6), id: \.url) { suggestion in
                        Button {
                            navigateTo(suggestion.url)
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: suggestion.icon)
                                    .font(.system(size: 12))
                                    .foregroundColor(UmbraTheme.textMuted)
                                    .frame(width: 20)

                                VStack(alignment: .leading, spacing: 1) {
                                    Text(suggestion.title)
                                        .font(.system(size: 14))
                                        .foregroundColor(UmbraTheme.textPrimary)
                                        .lineLimit(1)

                                    Text(suggestion.displayURL)
                                        .font(.system(size: 11))
                                        .foregroundColor(UmbraTheme.textMuted)
                                        .lineLimit(1)
                                }

                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                        }
                        .buttonStyle(.plain)

                        if suggestion.url != suggestions.prefix(6).last?.url {
                            Divider()
                                .background(UmbraTheme.border)
                                .padding(.leading, 46)
                        }
                    }
                }
                .background(UmbraTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(UmbraTheme.border, lineWidth: 0.5)
                )
                .padding(.horizontal, 10)
                .padding(.bottom, 4)
            }
        }
    }

    // MARK: - Autocomplete Engine

    struct AutocompleteSuggestion: Equatable {
        let title: String
        let url: String
        let displayURL: String
        let icon: String
    }

    private func autocompleteSuggestions(for query: String) -> [AutocompleteSuggestion] {
        guard !query.isEmpty else { return [] }
        let lowered = query.lowercased()
        var results: [AutocompleteSuggestion] = []
        var seen: Set<String> = []

        // Search bookmarks
        for bookmark in bookmarkService.bookmarks {
            let urlStr = bookmark.url.absoluteString.lowercased()
            let titleStr = bookmark.title.lowercased()
            if urlStr.contains(lowered) || titleStr.contains(lowered) {
                let key = bookmark.url.host ?? urlStr
                if !seen.contains(key) {
                    seen.insert(key)
                    results.append(AutocompleteSuggestion(
                        title: bookmark.title,
                        url: bookmark.url.absoluteString,
                        displayURL: bookmark.url.displayHost,
                        icon: "bookmark.fill"
                    ))
                }
            }
        }

        // Search history
        for entry in historyService.entries.prefix(500) {
            let urlStr = entry.url.absoluteString.lowercased()
            let titleStr = entry.title.lowercased()
            if urlStr.contains(lowered) || titleStr.contains(lowered) {
                let key = entry.url.host ?? urlStr
                if !seen.contains(key) {
                    seen.insert(key)
                    results.append(AutocompleteSuggestion(
                        title: entry.title,
                        url: entry.url.absoluteString,
                        displayURL: entry.domain,
                        icon: "clock"
                    ))
                }
            }
        }

        return results
    }

    // MARK: - Helpers

    private var displayURL: String {
        guard let tab = activeTab, let url = tab.url else {
            return "Search or enter URL"
        }
        return url.displayHost
    }

    private func lockIcon(for tab: BrowserTab) -> String {
        if tab.isInsecureFallback {
            return "lock.open.trianglebadge.exclamationmark.fill"
        }
        guard let url = tab.url else { return "lock.fill" }
        if url.scheme == "https" {
            if let cert = tab.sslCertificate, !cert.isValid {
                return "lock.trianglebadge.exclamationmark.fill"
            }
            return "lock.fill"
        }
        return "lock.open.fill"
    }

    private func lockColor(for tab: BrowserTab) -> Color {
        if tab.isInsecureFallback { return UmbraTheme.danger }
        guard let url = tab.url else { return UmbraTheme.textMuted }
        if url.scheme == "https" {
            if let cert = tab.sslCertificate, !cert.isValid { return UmbraTheme.danger }
            if let cert = tab.sslCertificate, cert.isExpiringSoon { return UmbraTheme.warning }
            return UmbraTheme.success
        }
        return UmbraTheme.danger
    }

    private func startEditing() {
        isEditing = true
        inputText = activeTab?.url?.absoluteString ?? ""
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            isFocused = true
        }
    }

    private func navigateTo(_ text: String) {
        isEditing = false
        isFocused = false

        guard let url = text.toNavigableURL(searchEngine: settingsService.searchEngine) else { return }

        if let tab = activeTab {
            tab.load(url)
        } else {
            tabManager.createNewTab(url: url)
        }
    }
}
