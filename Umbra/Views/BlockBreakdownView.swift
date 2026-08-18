// BlockBreakdownView.swift
// Umbra — Privacy-First Browser

import SwiftUI

struct BlockBreakdownView: View {
    @ObservedObject var tab: BrowserTab
    @EnvironmentObject var whitelistService: WhitelistService
    @EnvironmentObject var storeManager: StoreManager
    @Environment(\.dismiss) private var dismiss
    @State private var showPaywall = false

    private var isWhitelisted: Bool {
        guard let url = tab.url else { return false }
        return whitelistService.isWhitelisted(url: url)
    }

    private var currentDomain: String {
        tab.url?.displayHost ?? "this site"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                UmbraTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Shield summary
                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(shieldColor.opacity(0.1))
                                    .frame(width: 80, height: 80)

                                Image(systemName: isWhitelisted ? "shield.slash.fill" : "shield.fill")
                                    .font(.system(size: 36))
                                    .foregroundColor(shieldColor)
                            }
                            .umbraGlow(color: shieldColor, radius: 15)

                            Text(isWhitelisted ? "Blocking Disabled" : "\(tab.blockedCount) Blocked")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(UmbraTheme.textPrimary)

                            Text(currentDomain)
                                .font(.system(size: 14))
                                .foregroundColor(UmbraTheme.textSecondary)
                        }
                        .padding(.top, 16)

                        // Category breakdown
                        if tab.blockedCount > 0 && !isWhitelisted {
                            VStack(spacing: 2) {
                                ForEach(sortedCategories, id: \.0) { category, count in
                                    categoryRow(category: category, count: count)
                                }
                            }
                            .umbraCard()
                            .padding(.horizontal, 20)
                        }

                        // Whitelist toggle
                        VStack(spacing: 2) {
                            Button {
                                toggleWhitelist()
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: isWhitelisted ? "shield.fill" : "shield.slash")
                                        .font(.system(size: 16))
                                        .foregroundColor(isWhitelisted ? UmbraTheme.success : UmbraTheme.danger)
                                        .frame(width: 28)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(isWhitelisted ? "Enable Blocking" : "Disable Blocking")
                                            .font(.system(size: 15, weight: .medium))
                                            .foregroundColor(UmbraTheme.textPrimary)

                                        Text("for \(currentDomain)")
                                            .font(.system(size: 12))
                                            .foregroundColor(UmbraTheme.textMuted)
                                    }

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12))
                                        .foregroundColor(UmbraTheme.textMuted)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                            }
                        }
                        .umbraCard()
                        .padding(.horizontal, 20)

                        // Info text
                        if !isWhitelisted {
                            Text("Umbra blocks ads, trackers, and fingerprinting scripts to protect your privacy. Blocked resources never load — your data stays on your device.")
                                .font(.system(size: 13))
                                .foregroundColor(UmbraTheme.textMuted)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                        } else {
                            Text("Blocking is disabled for \(currentDomain). Ads and trackers on this site will load normally. Tap above to re-enable protection.")
                                .font(.system(size: 13))
                                .foregroundColor(UmbraTheme.textMuted)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                        }

                        // Strategy 4: Pro upsell in shield breakdown
                        if !storeManager.isPro {
                            proUpsellCard
                                .padding(.horizontal, 20)
                        }

                        Spacer()
                    }
                }
            }
            .navigationTitle("Privacy Shield")
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
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
        }
    }

    // MARK: - Pro Upsell Card (Strategy 4)

    private var proUpsellCard: some View {
        Button {
            showPaywall = true
        } label: {
            VStack(spacing: 14) {
                HStack(spacing: 10) {
                    Image(systemName: "shield.checkerboard")
                        .font(.system(size: 16))
                        .foregroundColor(UmbraTheme.accent)
                        .frame(width: 32, height: 32)
                        .background(UmbraTheme.accent.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Block even more with Eclipse")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(UmbraTheme.textPrimary)

                        Text("Advanced filter lists catch more trackers and ads")
                            .font(.system(size: 12))
                            .foregroundColor(UmbraTheme.textMuted)
                    }

                    Spacer()
                }

                // Mini feature row
                HStack(spacing: 16) {
                    miniFeature(icon: "globe.badge.chevron.backward", text: "Custom DNS")
                    miniFeature(icon: "shield.fill", text: "More filters")
                    miniFeature(icon: "bolt.fill", text: "Priority support")
                }

                // CTA
                HStack {
                    Text("See Plans")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(UmbraTheme.accent)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(UmbraTheme.accent)
                }
            }
            .padding(16)
            .background(UmbraTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(UmbraTheme.accent.opacity(0.2), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func miniFeature(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(UmbraTheme.accent)

            Text(text)
                .font(.system(size: 11))
                .foregroundColor(UmbraTheme.textMuted)
        }
    }

    // MARK: - Helpers

    private var shieldColor: Color {
        if isWhitelisted {
            return UmbraTheme.textMuted
        }
        return tab.blockedCount > 0 ? UmbraTheme.success : UmbraTheme.accent
    }

    private var sortedCategories: [(BlockCategory, Int)] {
        var result: [(BlockCategory, Int)] = []
        let breakdown = tab.blockBreakdown
        for category in BlockCategory.allCases {
            let count = breakdown[category.rawValue] ?? 0
            if count > 0 {
                result.append((category, count))
            }
        }
        return result.sorted { $0.1 > $1.1 }
    }

    @ViewBuilder
    private func categoryRow(category: BlockCategory, count: Int) -> some View {
        HStack(spacing: 12) {
            Image(systemName: category.iconName)
                .font(.system(size: 14))
                .foregroundColor(Color(hex: category.color))
                .frame(width: 28)

            Text(category.displayName)
                .font(.system(size: 15))
                .foregroundColor(UmbraTheme.textPrimary)

            Spacer()

            Text("\(count)")
                .font(.system(size: 15, weight: .semibold, design: .monospaced))
                .foregroundColor(UmbraTheme.textSecondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func toggleWhitelist() {
        guard let url = tab.url else { return }
        whitelistService.toggleWhitelist(for: url)
        dismiss()
    }
}
