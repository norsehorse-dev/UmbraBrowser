// HTTPWarningView.swift
// Umbra — Privacy-First Browser

import SwiftUI
import WebKit

struct HTTPWarningView: View {
    @ObservedObject var tab: BrowserTab

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 20) {
                // Warning icon
                ZStack {
                    Circle()
                        .fill(UmbraTheme.danger.opacity(0.1))
                        .frame(width: 72, height: 72)

                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(UmbraTheme.danger)
                }

                // Title
                Text("Insecure Connection")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(UmbraTheme.textPrimary)

                // Explanation
                VStack(spacing: 8) {
                    Text("HTTPS is not available for")
                        .font(.system(size: 15))
                        .foregroundColor(UmbraTheme.textSecondary)

                    Text(tab.url?.displayHost ?? "this site")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(UmbraTheme.textPrimary)

                    Text("Your connection is not encrypted. Information you send or receive on this site could be seen by others on your network.")
                        .font(.system(size: 14))
                        .foregroundColor(UmbraTheme.textMuted)
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                }
                .padding(.horizontal, 16)

                // Buttons
                VStack(spacing: 10) {
                    // Go back (safe option)
                    Button {
                        if tab.canGoBack {
                            tab.goBack()
                        } else {
                            // Navigate to new tab
                            tab.webView.load(URLRequest(url: URL(string: "about:blank")!))
                        }
                        tab.isInsecureFallback = false
                        tab.httpWarningDismissed = false
                    } label: {
                        Text("Go Back")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(UmbraTheme.accent)
                            .clipShape(RoundedRectangle(cornerRadius: UmbraTheme.cornerRadius))
                    }

                    // Continue anyway (risky option)
                    Button {
                        tab.httpWarningDismissed = true
                    } label: {
                        Text("Continue Anyway")
                            .font(.system(size: 14))
                            .foregroundColor(UmbraTheme.textMuted)
                    }
                }
                .padding(.horizontal, 8)
            }
            .padding(28)
            .background(UmbraTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(UmbraTheme.danger.opacity(0.3), lineWidth: 1)
            )
            .padding(.horizontal, 24)

            Spacer()
        }
        .background(UmbraTheme.background.opacity(0.95))
    }
}
