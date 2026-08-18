// TabSwitcherView.swift
// Umbra — Privacy-First Browser

import SwiftUI

struct TabSwitcherView: View {
    @EnvironmentObject var tabManager: TabManager
    @Environment(\.dismiss) private var dismiss

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                UmbraTheme.background.ignoresSafeArea()

                ScrollView {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(tabManager.tabs) { tab in
                            TabCardView(tab: tab) {
                                tabManager.activateTab(tab)
                                dismiss()
                            } onClose: {
                                withAnimation(UmbraTheme.animationSpring) {
                                    tabManager.closeTab(tab)
                                }
                            }
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Tabs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close All") {
                        tabManager.closeAllTabs()
                        dismiss()
                    }
                    .font(.system(size: 14))
                    .foregroundColor(UmbraTheme.danger)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        tabManager.createNewTab()
                        dismiss()
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(UmbraTheme.accent)
                    }
                }

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
        }
    }
}

// MARK: - Tab Card

struct TabCardView: View {
    @ObservedObject var tab: BrowserTab
    let onTap: () -> Void
    let onClose: () -> Void
    @EnvironmentObject var tabManager: TabManager

    private var isActive: Bool {
        tabManager.activeTabID == tab.id
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                // Tab preview header
                HStack(spacing: 6) {
                    // Pin indicator
                    if tab.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 9))
                            .foregroundColor(UmbraTheme.accent)
                    }

                    // Favicon
                    if let favicon = tab.favicon {
                        Image(uiImage: favicon)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 14, height: 14)
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                    } else {
                        Image(systemName: "globe")
                            .font(.system(size: 12))
                            .foregroundColor(UmbraTheme.textMuted)
                    }

                    Text(tab.title)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(UmbraTheme.textPrimary)
                        .lineLimit(1)

                    // Audio indicator
                    if tab.isPlayingAudio {
                        Image(systemName: tab.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                            .font(.system(size: 10))
                            .foregroundColor(tab.isMuted ? UmbraTheme.textMuted : UmbraTheme.accent)
                    }

                    Spacer()

                    // Close button
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(UmbraTheme.textMuted)
                            .frame(width: 20, height: 20)
                            .background(UmbraTheme.surfaceElevated)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(UmbraTheme.surfaceElevated)

                // Tab preview body
                ZStack {
                    UmbraTheme.background

                    if tab.url == nil {
                        VStack(spacing: 8) {
                            Image(systemName: "plus")
                                .font(.system(size: 24))
                                .foregroundColor(UmbraTheme.textMuted)
                            Text("New Tab")
                                .font(.system(size: 12))
                                .foregroundColor(UmbraTheme.textMuted)
                        }
                    } else if let thumbnail = tab.thumbnail {
                        Image(uiImage: thumbnail)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(maxWidth: .infinity)
                            .clipped()
                    } else {
                        VStack(spacing: 4) {
                            Image(systemName: "globe")
                                .font(.system(size: 20))
                                .foregroundColor(UmbraTheme.textMuted)

                            Text(tab.url?.displayHost ?? "")
                                .font(.system(size: 11))
                                .foregroundColor(UmbraTheme.textSecondary)
                                .lineLimit(1)
                        }
                    }
                }
                .frame(height: 140)
                .clipped()
            }
            .clipShape(RoundedRectangle(cornerRadius: UmbraTheme.cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: UmbraTheme.cornerRadius)
                    .stroke(
                        isActive ? UmbraTheme.accent : UmbraTheme.border,
                        lineWidth: isActive ? 2 : 0.5
                    )
            )
            .shadow(color: isActive ? UmbraTheme.accent.opacity(0.2) : .clear, radius: 8)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                tab.togglePin()
            } label: {
                Label(tab.isPinned ? "Unpin Tab" : "Pin Tab", systemImage: tab.isPinned ? "pin.slash" : "pin")
            }

            if tab.isPlayingAudio {
                Button {
                    tab.toggleMute()
                } label: {
                    Label(tab.isMuted ? "Unmute Tab" : "Mute Tab", systemImage: tab.isMuted ? "speaker.wave.2" : "speaker.slash")
                }
            }

            Divider()

            Button(role: .destructive, action: onClose) {
                Label("Close Tab", systemImage: "xmark")
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive, action: onClose) {
                Label("Close", systemImage: "xmark")
            }
        }
    }
}
