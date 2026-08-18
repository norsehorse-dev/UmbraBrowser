// OnboardingView.swift
// Umbra — Privacy-First Browser

import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var settingsService: SettingsService
    @EnvironmentObject var storeManager: StoreManager
    @State private var currentPage = 0
    @State private var showDefaultBrowserPrompt = false
    @State private var showPaywall = false

    private let totalPages = 4

    private let pages: [(icon: String, title: String, subtitle: String, color: Color)] = [
        (
            "shield.lefthalf.filled",
            "Total Privacy",
            "Every tab is isolated. Cookies, cache, and history are destroyed when you close a tab. Nothing is ever written to disk.",
            UmbraTheme.accent
        ),
        (
            "eye.slash.fill",
            "Block Everything",
            "Ads, trackers, fingerprinting scripts — all blocked before they load. UTM tracking parameters are stripped automatically.",
            Color(hex: "3FB950")
        ),
        (
            "lock.shield.fill",
            "Encrypted by Default",
            "HTTPS-first browsing. Encrypted DNS. Encrypted bookmarks. Your data stays yours.",
            Color(hex: "D29922")
        )
    ]

    var body: some View {
        ZStack {
            UmbraTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Page content
                TabView(selection: $currentPage) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        onboardingPage(pages[index])
                            .tag(index)
                    }

                    // Page 4: Pro upsell
                    proUpsellPage
                        .tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                // Page dots
                HStack(spacing: 8) {
                    ForEach(0..<totalPages, id: \.self) { index in
                        Circle()
                            .fill(index == currentPage ? UmbraTheme.accent : UmbraTheme.textMuted)
                            .frame(width: 8, height: 8)
                            .animation(UmbraTheme.animationDefault, value: currentPage)
                    }
                }
                .padding(.top, 24)

                Spacer().frame(height: 40)

                // CTA button
                Button {
                    if currentPage < totalPages - 1 {
                        withAnimation(UmbraTheme.animationDefault) {
                            currentPage += 1
                        }
                    } else {
                        showDefaultBrowserPrompt = true
                    }
                } label: {
                    Text(ctaText)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(UmbraTheme.accent)
                        .clipShape(RoundedRectangle(cornerRadius: UmbraTheme.cornerRadius))
                        .umbraGlow()
                }
                .padding(.horizontal, 32)

                // Secondary button
                if currentPage == 3 {
                    // Pro page: "See Plans" opens paywall, main button skips
                    Button {
                        showPaywall = true
                    } label: {
                        Text("See Plans")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(UmbraTheme.accent)
                    }
                    .padding(.top, 12)
                } else if currentPage < totalPages - 1 {
                    Button {
                        showDefaultBrowserPrompt = true
                    } label: {
                        Text("Skip")
                            .font(.system(size: 14))
                            .foregroundColor(UmbraTheme.textMuted)
                    }
                    .padding(.top, 12)
                }

                Spacer().frame(height: 40)
            }
        }
        .sheet(isPresented: $showDefaultBrowserPrompt, onDismiss: {
            settingsService.hasCompletedOnboarding = true
        }) {
            DefaultBrowserPromptView()
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
    }

    private var ctaText: String {
        switch currentPage {
        case 3: return "Start Browsing Free"
        case 2: return "Next"
        default: return "Next"
        }
    }

    // MARK: - Standard Onboarding Page

    @ViewBuilder
    private func onboardingPage(_ page: (icon: String, title: String, subtitle: String, color: Color)) -> some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(page.color.opacity(0.1))
                    .frame(width: 120, height: 120)

                Image(systemName: page.icon)
                    .font(.system(size: 48))
                    .foregroundColor(page.color)
            }
            .umbraGlow(color: page.color, radius: 20)

            Text(page.title)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(UmbraTheme.textPrimary)

            Text(page.subtitle)
                .font(.system(size: 16))
                .foregroundColor(UmbraTheme.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 40)
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Pro Upsell Page (Page 4)

    private var proUpsellPage: some View {
        VStack(spacing: 24) {
            // Crown icon
            ZStack {
                Circle()
                    .fill(UmbraTheme.accent.opacity(0.1))
                    .frame(width: 120, height: 120)

                Image(systemName: "crown.fill")
                    .font(.system(size: 48))
                    .foregroundColor(UmbraTheme.accent)
            }
            .umbraGlow(color: UmbraTheme.accent, radius: 20)

            Text("Go further with Eclipse")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(UmbraTheme.textPrimary)

            Text("Unlock advanced privacy features")
                .font(.system(size: 16))
                .foregroundColor(UmbraTheme.textSecondary)

            // Feature list
            VStack(alignment: .leading, spacing: 14) {
                proFeature(icon: "globe.badge.chevron.backward", text: "Custom DNS-over-HTTPS providers")
                proFeature(icon: "shield.checkerboard", text: "Advanced filter lists for maximum blocking")
                proFeature(icon: "bolt.fill", text: "Priority support from the developer")
            }
            .padding(.horizontal, 40)
            .padding(.top, 8)
        }
        .padding(.horizontal, 24)
    }

    @ViewBuilder
    private func proFeature(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(UmbraTheme.accent)
                .frame(width: 28)

            Text(text)
                .font(.system(size: 15))
                .foregroundColor(UmbraTheme.textSecondary)
        }
    }
}
