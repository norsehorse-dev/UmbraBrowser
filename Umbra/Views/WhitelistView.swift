// WhitelistView.swift
// Umbra — Privacy-First Browser

import SwiftUI

struct WhitelistView: View {
    @EnvironmentObject var whitelistService: WhitelistService
    @Environment(\.dismiss) private var dismiss
    @State private var showAddDomain = false
    @State private var newDomain = ""

    private var sortedDomains: [String] {
        whitelistService.domains.sorted()
    }

    var body: some View {
        NavigationStack {
            ZStack {
                UmbraTheme.background.ignoresSafeArea()

                if whitelistService.domains.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "shield.fill")
                            .font(.system(size: 40))
                            .foregroundColor(UmbraTheme.textMuted)
                        Text("No Whitelisted Sites")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(UmbraTheme.textSecondary)
                        Text("All sites are protected. Tap the shield icon\non any page to disable blocking for that site.")
                            .font(.system(size: 14))
                            .foregroundColor(UmbraTheme.textMuted)
                            .multilineTextAlignment(.center)
                    }
                } else {
                    List {
                        Section {
                            ForEach(sortedDomains, id: \.self) { domain in
                                HStack(spacing: 10) {
                                    Image(systemName: "shield.slash")
                                        .font(.system(size: 14))
                                        .foregroundColor(UmbraTheme.warning)
                                        .frame(width: 24)

                                    Text(domain)
                                        .font(.system(size: 15))
                                        .foregroundColor(UmbraTheme.textPrimary)

                                    Spacer()
                                }
                                .listRowBackground(UmbraTheme.surface)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        whitelistService.removeDomain(domain)
                                    } label: {
                                        Label("Remove", systemImage: "shield.fill")
                                    }
                                }
                            }
                        } header: {
                            Text("Blocking disabled for these sites")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(UmbraTheme.textMuted)
                                .textCase(.uppercase)
                        } footer: {
                            Text("Swipe left to remove a site and re-enable blocking.")
                                .font(.system(size: 12))
                                .foregroundColor(UmbraTheme.textMuted)
                        }
                    }
                    .scrollContentBackground(.hidden)
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Whitelisted Sites")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !whitelistService.domains.isEmpty {
                        Button("Clear All") {
                            whitelistService.clearAll()
                        }
                        .font(.system(size: 14))
                        .foregroundColor(UmbraTheme.danger)
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddDomain = true
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
            .alert("Add Domain", isPresented: $showAddDomain) {
                TextField("example.com", text: $newDomain)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button("Cancel", role: .cancel) {
                    newDomain = ""
                }
                Button("Add") {
                    if !newDomain.isEmpty {
                        whitelistService.addDomain(newDomain)
                        newDomain = ""
                    }
                }
            } message: {
                Text("Enter a domain to disable blocking for.")
            }
        }
    }
}
