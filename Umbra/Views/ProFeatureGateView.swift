// ProFeatureGateView.swift
// Umbra — Privacy-First Browser

import SwiftUI
import StoreKit

/// Inline upsell shown when a free user taps a Pro-only feature.
/// Usage: ProFeatureGateView(feature: "Custom DNS", icon: "globe.badge.chevron.backward")
struct ProFeatureGateView: View {
    let feature: String
    let icon: String
    let description: String
    @EnvironmentObject var storeManager: StoreManager
    @State private var showPaywall = false

    init(feature: String, icon: String, description: String = "") {
        self.feature = feature
        self.icon = icon
        self.description = description
    }

    var body: some View {
        VStack(spacing: 16) {
            // Lock icon
            ZStack {
                Circle()
                    .fill(UmbraTheme.accent.opacity(0.08))
                    .frame(width: 56, height: 56)

                Image(systemName: "lock.fill")
                    .font(.system(size: 22))
                    .foregroundColor(UmbraTheme.accent)
            }

            // Feature name
            Text(feature)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(UmbraTheme.textPrimary)

            // Description
            Text(description.isEmpty ? "This feature is available with Eclipse Pro." : description)
                .font(.system(size: 14))
                .foregroundColor(UmbraTheme.textMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)

            // Unlock button
            Button {
                showPaywall = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 12))

                    Text("Unlock with Eclipse")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
                .background(UmbraTheme.accent)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            // Price hint
            if let monthly = storeManager.eclipseMonthly {
                Text("Starting at \(monthly.displayPrice)/month")
                    .font(.system(size: 12))
                    .foregroundColor(UmbraTheme.textMuted)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(UmbraTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(UmbraTheme.accent.opacity(0.15), lineWidth: 0.5)
        )
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
    }
}

/// Modifier that wraps a settings row with a Pro gate.
/// If the user is Pro, shows the content normally.
/// If free, shows the content dimmed with a PRO badge, and tapping opens the gate.
struct ProGatedModifier: ViewModifier {
    let feature: String
    let icon: String
    let description: String
    @EnvironmentObject var storeManager: StoreManager
    @State private var showGate = false

    func body(content: Content) -> some View {
        if storeManager.isPro {
            content
        } else {
            Button {
                showGate = true
            } label: {
                HStack {
                    content
                        .opacity(0.5)

                    Spacer()

                    Text("PRO")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(UmbraTheme.accent)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(UmbraTheme.accent.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
            }
            .sheet(isPresented: $showGate) {
                NavigationStack {
                    ZStack {
                        UmbraTheme.background.ignoresSafeArea()

                        ProFeatureGateView(
                            feature: feature,
                            icon: icon,
                            description: description
                        )
                        .padding(24)
                    }
                    .navigationTitle("Eclipse Pro")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") { showGate = false }
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(UmbraTheme.accent)
                        }
                    }
                    .toolbarBackground(UmbraTheme.surface, for: .navigationBar)
                    .toolbarBackground(.visible, for: .navigationBar)
                }
            }
        }
    }
}

extension View {
    /// Gates this view behind Pro. Free users see it dimmed with a PRO badge; tapping opens the upsell.
    func proGated(
        feature: String,
        icon: String = "crown.fill",
        description: String = ""
    ) -> some View {
        modifier(ProGatedModifier(feature: feature, icon: icon, description: description))
    }
}
