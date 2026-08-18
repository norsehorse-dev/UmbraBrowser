// BookmarksView.swift
// Umbra — Privacy-First Browser

import SwiftUI

struct BookmarksView: View {
    @EnvironmentObject var bookmarkService: BookmarkService
    @EnvironmentObject var tabManager: TabManager
    @Environment(\.dismiss) private var dismiss
    @State private var showAddFolder = false
    @State private var newFolderName = ""
    @State private var selectedFolder: String? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                UmbraTheme.background.ignoresSafeArea()

                if bookmarkService.bookmarks.isEmpty && bookmarkService.folders.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "bookmark")
                            .font(.system(size: 40))
                            .foregroundColor(UmbraTheme.textMuted)
                        Text("No Bookmarks")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(UmbraTheme.textSecondary)
                        Text("Tap the bookmark icon to save pages.")
                            .font(.system(size: 14))
                            .foregroundColor(UmbraTheme.textMuted)
                    }
                } else {
                    List {
                        // Folders
                        if !bookmarkService.folders.isEmpty {
                            Section {
                                ForEach(bookmarkService.folders) { folder in
                                    Button {
                                        selectedFolder = folder.name
                                    } label: {
                                        HStack(spacing: 10) {
                                            Image(systemName: "folder.fill")
                                                .foregroundColor(UmbraTheme.accent)
                                            Text(folder.name)
                                                .foregroundColor(UmbraTheme.textPrimary)
                                            Spacer()
                                            let count = bookmarkService.bookmarks(in: folder.name).count
                                            Text("\(count)")
                                                .font(.system(size: 13))
                                                .foregroundColor(UmbraTheme.textMuted)
                                            Image(systemName: "chevron.right")
                                                .font(.system(size: 12))
                                                .foregroundColor(UmbraTheme.textMuted)
                                        }
                                    }
                                    .listRowBackground(UmbraTheme.surface)
                                    .swipeActions(edge: .trailing) {
                                        Button(role: .destructive) {
                                            bookmarkService.removeFolder(folder)
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                                }
                            } header: {
                                Text("Folders")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(UmbraTheme.textMuted)
                                    .textCase(.uppercase)
                            }
                        }

                        // Unfiled bookmarks
                        let unfiled = bookmarkService.bookmarks(in: selectedFolder)
                        if !unfiled.isEmpty {
                            Section {
                                ForEach(unfiled) { bookmark in
                                    Button {
                                        tabManager.activeTab?.load(bookmark.url)
                                        dismiss()
                                    } label: {
                                        HStack(spacing: 10) {
                                            if let faviconData = bookmark.favicon,
                                               let image = UIImage(data: faviconData) {
                                                Image(uiImage: image)
                                                    .resizable()
                                                    .frame(width: 20, height: 20)
                                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                                            } else {
                                                Image(systemName: "globe")
                                                    .font(.system(size: 14))
                                                    .foregroundColor(UmbraTheme.textMuted)
                                                    .frame(width: 20, height: 20)
                                            }

                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(bookmark.title)
                                                    .font(.system(size: 15))
                                                    .foregroundColor(UmbraTheme.textPrimary)
                                                    .lineLimit(1)
                                                Text(bookmark.url.displayHost)
                                                    .font(.system(size: 12))
                                                    .foregroundColor(UmbraTheme.textMuted)
                                                    .lineLimit(1)
                                            }
                                        }
                                    }
                                    .listRowBackground(UmbraTheme.surface)
                                    .swipeActions(edge: .trailing) {
                                        Button(role: .destructive) {
                                            bookmarkService.removeBookmark(bookmark)
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                                }
                            } header: {
                                Text(selectedFolder ?? "Bookmarks")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(UmbraTheme.textMuted)
                                    .textCase(.uppercase)
                            }
                        }
                    }
                    .scrollContentBackground(.hidden)
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle(selectedFolder ?? "Bookmarks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if selectedFolder != nil {
                        Button {
                            selectedFolder = nil
                        } label: {
                            Image(systemName: "chevron.left")
                                .foregroundColor(UmbraTheme.accent)
                        }
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            showAddFolder = true
                        } label: {
                            Label("New Folder", systemImage: "folder.badge.plus")
                        }
                    } label: {
                        Image(systemName: "plus")
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
            .alert("New Folder", isPresented: $showAddFolder) {
                TextField("Folder name", text: $newFolderName)
                Button("Cancel", role: .cancel) {
                    newFolderName = ""
                }
                Button("Add") {
                    if !newFolderName.isEmpty {
                        bookmarkService.addFolder(name: newFolderName)
                        newFolderName = ""
                    }
                }
            }
        }
    }
}
