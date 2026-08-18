// PaywallView.swift
// Umbra — Privacy-First Browser

import SwiftUI
import StoreKit

struct PaywallView: View {
    @EnvironmentObject var storeManager: StoreManager
    @Environment(\.dismiss) private var dismiss
    @State private var selectedProduct: Product?
    @State private var isPurchasing = false
    @State private var showError = false
    @State private var errorText = ""

    var body: some View {
        NavigationStack {
            ZStack {
                UmbraTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 28) {
                        // Header
                        VStack(spacing: 12) {
                            Image("UmbraLogo")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 64, height: 64)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .umbraGlow(radius: 12)

                            Text("Upgrade to Pro")
                                .font(.system(size: 26, weight: .bold))
                                .foregroundColor(UmbraTheme.textPrimary)

                            Text("Unlock the full power of Umbra")
                                .font(.system(size: 15))
                                .foregroundColor(UmbraTheme.textSecondary)
                        }
                        .padding(.top, 20)

                        // Pro features
                        VStack(alignment: .leading, spacing: 14) {
                            proFeatureRow(
                                icon: "globe.badge.chevron.backward",
                                color: UmbraTheme.accent,
                                title: "Custom DNS providers",
                                subtitle: "Use any DNS-over-HTTPS provider"
                            )
                            proFeatureRow(
                                icon: "shield.checkerboard",
                                color: UmbraTheme.success,
                                title: "Advanced blocklists",
                                subtitle: "Extra filter lists for maximum protection"
                            )
                            proFeatureRow(
                                icon: "bolt.fill",
                                color: UmbraTheme.warning,
                                title: "Priority support",
                                subtitle: "Fast response from the developer"
                            )
                        }
                        .padding(.horizontal, 24)

                        // Product cards
                        if storeManager.isLoading && storeManager.products.isEmpty {
                            ProgressView()
                                .tint(UmbraTheme.accent)
                                .padding(40)
                        } else {
                            VStack(spacing: 10) {
                                // Eclipse Monthly
                                if let monthly = storeManager.eclipseMonthly {
                                    productCard(
                                        product: monthly,
                                        label: "ECLIPSE",
                                        name: "Monthly",
                                        badge: nil
                                    )
                                }

                                // Eclipse Yearly
                                if let yearly = storeManager.eclipseYearly {
                                    let savings = monthlySavings(yearly: yearly)
                                    productCard(
                                        product: yearly,
                                        label: "ECLIPSE",
                                        name: "Yearly",
                                        badge: savings
                                    )
                                }

                                // Eclipse Lifetime
                                if let lifetime = storeManager.voidLifetime {
                                    productCard(
                                        product: lifetime,
                                        label: "ECLIPSE",
                                        name: "Lifetime",
                                        badge: "Best value"
                                    )
                                }
                            }
                            .padding(.horizontal, 20)
                        }

                        // Purchase button
                        if let product = selectedProduct {
                            Button {
                                Task { await purchaseSelected() }
                            } label: {
                                HStack {
                                    if isPurchasing {
                                        ProgressView()
                                            .tint(.white)
                                            .scaleEffect(0.8)
                                    } else {
                                        Text("Subscribe — \(product.displayPrice)")
                                            .font(.system(size: 16, weight: .semibold))
                                    }
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(UmbraTheme.accent)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .umbraGlow()
                            }
                            .disabled(isPurchasing)
                            .padding(.horizontal, 20)
                        }

                        // Restore + terms
                        VStack(spacing: 12) {
                            Button {
                                Task { await storeManager.restorePurchases() }
                            } label: {
                                Text("Restore Purchases")
                                    .font(.system(size: 14))
                                    .foregroundColor(UmbraTheme.accent)
                            }

                            Button {
                                dismiss()
                            } label: {
                                Text("Maybe Later")
                                    .font(.system(size: 14))
                                    .foregroundColor(UmbraTheme.textMuted)
                            }

                            Text("Payment is charged to your Apple ID. Subscriptions auto-renew unless cancelled at least 24 hours before the end of the current period.")
                                .font(.system(size: 11))
                                .foregroundColor(UmbraTheme.textMuted)
                                .multilineTextAlignment(.center)

                            HStack(spacing: 16) {
                                Link("Privacy Policy", destination: URL(string: "https://umbra.norsehor.se/privacy")!)
                                Link("Terms of Use", destination: URL(string: "https://umbra.norsehor.se/terms")!)
                            }
                            .font(.system(size: 11))
                            .foregroundColor(UmbraTheme.textMuted)
                        }
                        .padding(.horizontal, 32)
                        .padding(.bottom, 24)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(UmbraTheme.textMuted, UmbraTheme.surfaceElevated)
                    }
                }
            }
            .toolbarBackground(UmbraTheme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .alert("Purchase Error", isPresented: $showError) {
                Button("OK") {}
            } message: {
                Text(errorText)
            }
            .onAppear {
                selectDefault()
            }
        }
    }

    // MARK: - Product Card

    @ViewBuilder
    private func productCard(product: Product, label: String, name: String, badge: String?) -> some View {
        let isSelected = selectedProduct?.id == product.id
        let isPurchased = storeManager.purchasedProductIDs.contains(product.id)

        Button {
            if !isPurchased {
                withAnimation(.easeInOut(duration: 0.15)) {
                    selectedProduct = product
                }
            }
        } label: {
            HStack(spacing: 14) {
                // Selection indicator
                ZStack {
                    Circle()
                        .stroke(isSelected ? UmbraTheme.accent : UmbraTheme.border, lineWidth: 2)
                        .frame(width: 22, height: 22)

                    if isSelected || isPurchased {
                        Circle()
                            .fill(isPurchased ? UmbraTheme.success : UmbraTheme.accent)
                            .frame(width: 14, height: 14)
                    }
                }

                // Info
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(label)
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(UmbraTheme.accent)
                            .tracking(1)

                        if let badge = badge {
                            Text(badge)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(UmbraTheme.success)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(UmbraTheme.success.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                    }

                    Text(name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(UmbraTheme.textPrimary)
                }

                Spacer()

                // Price
                if isPurchased {
                    Text("Active")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(UmbraTheme.success)
                } else {
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(product.displayPrice)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(UmbraTheme.textPrimary)

                        if product.type == .autoRenewable {
                            Text(product.id == StoreManager.eclipseMonthlyID ? "/month" : "/year")
                                .font(.system(size: 11))
                                .foregroundColor(UmbraTheme.textMuted)
                        } else {
                            Text("one-time")
                                .font(.system(size: 11))
                                .foregroundColor(UmbraTheme.textMuted)
                        }
                    }
                }
            }
            .padding(16)
            .background(UmbraTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isSelected ? UmbraTheme.accent : (isPurchased ? UmbraTheme.success.opacity(0.3) : UmbraTheme.border),
                        lineWidth: isSelected ? 1.5 : 0.5
                    )
            )
        }
        .disabled(isPurchased)
    }

    // MARK: - Feature Row

    @ViewBuilder
    private func proFeatureRow(icon: String, color: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundColor(color)
                .frame(width: 36, height: 36)
                .background(color.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(UmbraTheme.textPrimary)

                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundColor(UmbraTheme.textMuted)
            }
        }
    }

    // MARK: - Helpers

    private func selectDefault() {
        if storeManager.isPro { return }
        // Default to yearly
        selectedProduct = storeManager.eclipseYearly ?? storeManager.eclipseMonthly ?? storeManager.voidLifetime
    }

    private func purchaseSelected() async {
        guard let product = selectedProduct else { return }
        isPurchasing = true

        do {
            _ = try await storeManager.purchase(product)
        } catch {
            errorText = error.localizedDescription
            showError = true
        }

        isPurchasing = false
    }

    private func monthlySavings(yearly: Product) -> String? {
        guard let monthly = storeManager.eclipseMonthly else { return nil }
        let yearlyMonthly = yearly.price / 12
        let savings = ((monthly.price - yearlyMonthly) / monthly.price) * 100
        let rounded = NSDecimalNumber(decimal: savings).intValue
        return rounded > 0 ? "Save \(rounded)%" : nil
    }
}
