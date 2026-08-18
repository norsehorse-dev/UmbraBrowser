// View+Umbra.swift
// Umbra — Privacy-First Browser

import SwiftUI

extension View {
    func umbraCard() -> some View {
        self
            .background(UmbraTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: UmbraTheme.cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: UmbraTheme.cornerRadius)
                    .stroke(UmbraTheme.border, lineWidth: 0.5)
            )
    }

    func umbraGlow(color: Color = UmbraTheme.accent, radius: CGFloat = 10) -> some View {
        self.shadow(color: color.opacity(0.3), radius: radius, x: 0, y: 0)
    }

    func umbraButtonStyle() -> some View {
        self
            .font(.system(size: 15, weight: .medium))
            .foregroundColor(UmbraTheme.textPrimary)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(UmbraTheme.accent)
            .clipShape(RoundedRectangle(cornerRadius: UmbraTheme.cornerRadiusSmall))
    }
}
