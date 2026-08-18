// HistoryView.swift
// Umbra — Privacy-First Browser

import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var historyService: HistoryService
    @EnvironmentObject var tabManager: TabManager
    @Environment(\.dismiss) private var dismiss
    @State private var searchText: String = ""
    @State private var showClearOptions = false

    private var filteredGroups: [HistoryGroup] {
        if searchText.isEmpty {
            return historyService.groupedByDate
        }
        let results = historyService.search(query: searchText)
        guard !results.isEmpty else { return [] }
        // Return as single group for search results
        return [HistoryGroup(id: "search", date: Date(), entries: results)]
    }

    var body: some View {
        NavigationStack {
            ZStack {
                UmbraTheme.background.ignoresSafeArea()

                if historyService.entries.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "clock")
                            .font(.system(size: 40))
                            .foregroundColor(UmbraTheme.textMuted)
                        Text("No History")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(UmbraTheme.textSecondary)
                        Text("Pages you visit will appear here.\nHistory is encrypted on your device.")
                            .font(.system(size: 14))
                            .foregroundColor(UmbraTheme.textMuted)
                            .multilineTextAlignment(.center)
                    }
                } else {
                    List {
                        ForEach(filteredGroups) { group in
                            Section {
                                ForEach(group.entries) { entry in
                                    Button {
                                        tabManager.activeTab?.load(entry.url)
                                        dismiss()
                                    } label: {
                                        HStack(spacing: 12) {
                                            Image(systemName: "globe")
                                                .font(.system(size: 14))
                                                .foregroundColor(UmbraTheme.textMuted)
                                                .frame(width: 24, height: 24)

                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(entry.title)
                                                    .font(.system(size: 15))
                                                    .foregroundColor(UmbraTheme.textPrimary)
                                                    .lineLimit(1)

                                                Text(entry.domain)
                                                    .font(.system(size: 12))
                                                    .foregroundColor(UmbraTheme.textMuted)
                                                    .lineLimit(1)
                                            }

                                            Spacer()

                                            Text(timeString(entry.visitedAt))
                                                .font(.system(size: 12))
                                                .foregroundColor(UmbraTheme.textMuted)
                                        }
                                    }
                                    .listRowBackground(UmbraTheme.surface)
                                    .swipeActions(edge: .trailing) {
                                        Button(role: .destructive) {
                                            historyService.removeEntry(entry)
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                                }
                            } header: {
                                Text(searchText.isEmpty ? group.displayDate : "Search Results")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(UmbraTheme.textMuted)
                                    .textCase(.uppercase)
                            }
                        }
                    }
                    .scrollContentBackground(.hidden)
                    .listStyle(.insetGrouped)
                    .searchable(text: $searchText, prompt: "Search history")
                }
            }
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !historyService.entries.isEmpty {
                        Button("Clear") {
                            showClearOptions = true
                        }
                        .font(.system(size: 14))
                        .foregroundColor(UmbraTheme.danger)
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
            .confirmationDialog("Clear History", isPresented: $showClearOptions) {
                Button("Last Hour") { historyService.clearLastHour() }
                Button("Today") { historyService.clearToday() }
                Button("All History", role: .destructive) { historyService.clearAll() }
                Button("Cancel", role: .cancel) {}
            }
        }
    }

    private func timeString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
