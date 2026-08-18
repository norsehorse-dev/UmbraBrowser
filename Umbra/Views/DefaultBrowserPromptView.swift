// DefaultBrowserPromptView.swift
// Umbra — Privacy-First Browser

import SwiftUI

struct DefaultBrowserPromptView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("hasShownDefaultBrowserPrompt") private var hasShownPrompt = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Icon
            ZStack {
                Circle()
                    .fill(UmbraTheme.accent.opacity(0.1))
                    .frame(width: 96, height: 96)

                Image(systemName: "globe.badge.chevron.backward")
                    .font(.system(size: 44))
                    .foregroundColor(UmbraTheme.accent)
            }
            .umbraGlow(radius: 20)

            // Title
            Text("Make Umbra Your Default")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(UmbraTheme.textPrimary)

            // Description
            Text("Set Umbra as your default browser so every link you tap opens with full privacy protection.")
                .font(.system(size: 15))
                .foregroundColor(UmbraTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            // Steps
            VStack(alignment: .leading, spacing: 12) {
                stepRow(number: 1, text: "Open the Settings app")
                stepRow(number: 2, text: "Scroll down and tap Umbra")
                stepRow(number: 3, text: "Tap \"Default Browser App\"")
                stepRow(number: 4, text: "Select Umbra")
            }
            .padding(20)
            .umbraCard()
            .padding(.horizontal, 24)

            Spacer()

            // Open Settings button
            Button {
                openSettings()
            } label: {
                Text("Open Settings")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(UmbraTheme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: UmbraTheme.cornerRadius))
                    .umbraGlow()
            }
            .padding(.horizontal, 32)

            Button {
                hasShownPrompt = true
                dismiss()
            } label: {
                Text("Maybe Later")
                    .font(.system(size: 14))
                    .foregroundColor(UmbraTheme.textMuted)
            }
            .padding(.bottom, 32)
        }
        .background(UmbraTheme.background)
        .onAppear {
            hasShownPrompt = true
        }
    }

    @ViewBuilder
    private func stepRow(number: Int, text: String) -> some View {
        HStack(spacing: 12) {
            Text("\(number)")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(UmbraTheme.accent)
                .frame(width: 26, height: 26)
                .background(UmbraTheme.accent.opacity(0.15))
                .clipShape(Circle())

            Text(text)
                .font(.system(size: 14))
                .foregroundColor(UmbraTheme.textPrimary)
        }
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}
