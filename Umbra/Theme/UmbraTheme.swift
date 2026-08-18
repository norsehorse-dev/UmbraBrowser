// UmbraTheme.swift
// Umbra — Privacy-First Browser

import SwiftUI

enum UmbraTheme {
    // MARK: - Colors
    static let background = Color(hex: "0D1117")
    static let surface = Color(hex: "161B22")
    static let surfaceElevated = Color(hex: "1C2128")
    static let accent = Color(hex: "7C6BF0")
    static let accentGlow = Color(hex: "7C6BF0").opacity(0.3)
    static let textPrimary = Color(hex: "E6EDF3")
    static let textSecondary = Color(hex: "8B949E")
    static let textMuted = Color(hex: "484F58")
    static let border = Color(hex: "30363D")
    static let danger = Color(hex: "F85149")
    static let success = Color(hex: "3FB950")
    static let warning = Color(hex: "D29922")

    // MARK: - Tab Bar
    static let tabBarHeight: CGFloat = 44
    static let addressBarHeight: CGFloat = 44

    // MARK: - Corner Radius
    static let cornerRadius: CGFloat = 12
    static let cornerRadiusSmall: CGFloat = 8
    static let cornerRadiusPill: CGFloat = 22

    // MARK: - Animation
    static let animationDefault: Animation = .easeInOut(duration: 0.25)
    static let animationSpring: Animation = .spring(response: 0.35, dampingFraction: 0.8)

    // MARK: - Shadows
    static func glowShadow(radius: CGFloat = 10) -> some View {
        EmptyView()
    }
}
