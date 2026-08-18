// NewTabView.swift
// Umbra — Privacy-First Browser

import SwiftUI

struct NewTabView: View {
    @EnvironmentObject var tabManager: TabManager
    @EnvironmentObject var settingsService: SettingsService
    @EnvironmentObject var storeManager: StoreManager
    @AppStorage("hasDissmissedProBanner") private var hasDismissedProBanner = false
    @State private var searchText: String = ""
    @State private var showPaywall = false
    @FocusState private var isSearchFocused: Bool

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                Spacer().frame(height: 40)

                // Logo / Brand
                VStack(spacing: 8) {
                    Image("UmbraLogo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 80, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .umbraGlow(radius: 15)

                    Text("Umbra")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(UmbraTheme.textPrimary)

                    Text("Browse in the umbra.")
                        .font(.system(size: 14))
                        .foregroundColor(UmbraTheme.textMuted)
                }

                // Search bar
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 15))
                        .foregroundColor(UmbraTheme.textMuted)

                    TextField("Search with \(settingsService.searchEngine.rawValue)", text: $searchText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.webSearch)
                        .font(.system(size: 15))
                        .foregroundColor(UmbraTheme.textPrimary)
                        .focused($isSearchFocused)
                        .onSubmit {
                            performSearch()
                        }

                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
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
                .clipShape(RoundedRectangle(cornerRadius: UmbraTheme.cornerRadiusPill))
                .overlay(
                    RoundedRectangle(cornerRadius: UmbraTheme.cornerRadiusPill)
                        .stroke(
                            isSearchFocused ? UmbraTheme.accent : UmbraTheme.border,
                            lineWidth: isSearchFocused ? 1.5 : 0.5
                        )
                )
                .padding(.horizontal, 24)

                // Quick access tiles
                VStack(alignment: .leading, spacing: 12) {
                    Text("Quick Access")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(UmbraTheme.textMuted)
                        .textCase(.uppercase)
                        .tracking(0.8)
                        .padding(.horizontal, 24)

                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(QuickAccessTile.defaults) { tile in
                            QuickAccessButton(tile: tile) {
                                tabManager.activeTab?.load(tile.url)
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                }

                // Pro banner (Strategy 2) — dismissible, only for free users
                if !storeManager.isPro && !hasDismissedProBanner {
                    proBanner
                        .padding(.horizontal, 24)
                        .transition(.asymmetric(
                            insertion: .opacity,
                            removal: .opacity.combined(with: .move(edge: .top))
                        ))
                }

                Spacer()
            }
        }
        .background(UmbraTheme.background)
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
    }

    // MARK: - Pro Banner

    private var proBanner: some View {
        Button {
            showPaywall = true
        } label: {
            HStack(spacing: 14) {
                // Icon
                Image(systemName: "crown.fill")
                    .font(.system(size: 18))
                    .foregroundColor(UmbraTheme.accent)
                    .frame(width: 40, height: 40)
                    .background(UmbraTheme.accent.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                // Text
                VStack(alignment: .leading, spacing: 2) {
                    Text("Upgrade to Eclipse")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(UmbraTheme.textPrimary)

                    Text("Custom DNS, advanced blocklists, and more")
                        .font(.system(size: 12))
                        .foregroundColor(UmbraTheme.textMuted)
                }

                Spacer()

                // Dismiss button
                Button {
                    withAnimation(UmbraTheme.animationDefault) {
                        hasDismissedProBanner = true
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(UmbraTheme.textMuted)
                        .frame(width: 24, height: 24)
                        .background(UmbraTheme.surfaceElevated)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(14)
            .background(UmbraTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(UmbraTheme.accent.opacity(0.2), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    private func performSearch() {
        guard let url = searchText.toNavigableURL(searchEngine: settingsService.searchEngine) else { return }
        tabManager.activeTab?.load(url)
    }
}

// MARK: - Quick Access Button

struct QuickAccessButton: View {
    let tile: QuickAccessTile
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: UmbraTheme.cornerRadiusSmall)
                        .fill(UmbraTheme.surfaceElevated)
                        .frame(width: 52, height: 52)

                    Text(String(tile.title.prefix(1)))
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(UmbraTheme.accent)
                }

                Text(tile.title)
                    .font(.system(size: 11))
                    .foregroundColor(UmbraTheme.textSecondary)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
    }
}
