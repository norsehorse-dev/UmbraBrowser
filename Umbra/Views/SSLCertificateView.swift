// SSLCertificateView.swift
// Umbra — Privacy-First Browser

import SwiftUI

struct SSLCertificateView: View {
    @ObservedObject var tab: BrowserTab
    @Environment(\.dismiss) private var dismiss

    private var cert: SSLCertificateInfo? { tab.sslCertificate }
    private var isHTTPS: Bool { tab.url?.scheme == "https" }

    var body: some View {
        NavigationStack {
            ZStack {
                UmbraTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Connection status header
                        connectionHeader

                        if let cert = cert {
                            // Certificate details
                            certificateSection(cert)

                            // Validity section
                            validitySection(cert)

                            // Technical details
                            technicalSection(cert)
                        } else if isHTTPS {
                            infoCard {
                                Label("Certificate details are being loaded.", systemImage: "info.circle")
                                    .font(.system(size: 14))
                                    .foregroundColor(UmbraTheme.textSecondary)
                            }
                        }

                        Spacer()
                    }
                    .padding(.horizontal, 20)
                }
            }
            .navigationTitle("Connection Security")
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
        }
    }

    // MARK: - Connection Header

    @ViewBuilder
    private var connectionHeader: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(connectionColor.opacity(0.1))
                    .frame(width: 72, height: 72)

                Image(systemName: connectionIcon)
                    .font(.system(size: 32))
                    .foregroundColor(connectionColor)
            }
            .umbraGlow(color: connectionColor, radius: 12)

            Text(connectionTitle)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(UmbraTheme.textPrimary)

            Text(connectionSubtitle)
                .font(.system(size: 14))
                .foregroundColor(UmbraTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
        }
        .padding(.top, 16)
    }

    private var connectionColor: Color {
        if tab.isInsecureFallback || !isHTTPS {
            return UmbraTheme.danger
        }
        if let cert = cert, !cert.isValid {
            return UmbraTheme.danger
        }
        if let cert = cert, cert.isExpiringSoon {
            return UmbraTheme.warning
        }
        return UmbraTheme.success
    }

    private var connectionIcon: String {
        if tab.isInsecureFallback || !isHTTPS {
            return "lock.open.fill"
        }
        if let cert = cert, !cert.isValid {
            return "lock.trianglebadge.exclamationmark.fill"
        }
        return "lock.fill"
    }

    private var connectionTitle: String {
        if tab.isInsecureFallback {
            return "Insecure Connection"
        }
        if !isHTTPS {
            return "Not Secure"
        }
        if let cert = cert, !cert.isValid {
            return "Certificate Invalid"
        }
        if let cert = cert, cert.isEV {
            return "Verified Organization"
        }
        return "Connection Secure"
    }

    private var connectionSubtitle: String {
        if tab.isInsecureFallback {
            return "HTTPS was unavailable. Your connection to \(tab.url?.displayHost ?? "this site") is not encrypted."
        }
        if !isHTTPS {
            return "Your connection to this site is not encrypted. Information you send could be read by others."
        }
        if let cert = cert, !cert.isValid {
            return "The certificate for this site has expired or is not yet valid."
        }
        return "Your connection to \(tab.url?.displayHost ?? "this site") is encrypted using TLS."
    }

    // MARK: - Certificate Section

    @ViewBuilder
    private func certificateSection(_ cert: SSLCertificateInfo) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            sectionLabel("Certificate")

            detailRow("Issued to", cert.displaySubject)

            if let org = cert.organizationName {
                detailRow("Organization", org)
            }

            detailRow("Issued by", cert.displayIssuer)

            if cert.isEV {
                HStack(spacing: 8) {
                    Text("Extended Validation")
                        .font(.system(size: 14))
                        .foregroundColor(UmbraTheme.textSecondary)
                    Spacer()
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 12))
                        Text("EV")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(UmbraTheme.success)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
        }
        .umbraCard()
    }

    // MARK: - Validity Section

    @ViewBuilder
    private func validitySection(_ cert: SSLCertificateInfo) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            sectionLabel("Validity")

            detailRow("Valid from", formatDate(cert.validFrom))
            detailRow("Valid until", formatDate(cert.validTo))

            HStack(spacing: 8) {
                Text("Status")
                    .font(.system(size: 14))
                    .foregroundColor(UmbraTheme.textSecondary)
                Spacer()
                HStack(spacing: 4) {
                    Circle()
                        .fill(cert.isValid ? UmbraTheme.success : UmbraTheme.danger)
                        .frame(width: 8, height: 8)
                    Text(statusText(cert))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(cert.isValid ? UmbraTheme.success : UmbraTheme.danger)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .umbraCard()
    }

    // MARK: - Technical Section

    @ViewBuilder
    private func technicalSection(_ cert: SSLCertificateInfo) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            sectionLabel("Technical Details")

            detailRow("Protocol", "TLS")
            detailRow("Certificate Chain", "\(cert.issuer)")
            if cert.isEV {
                detailRow("Validation", "Extended (EV)")
            } else {
                detailRow("Validation", "Domain Validated (DV)")
            }
        }
        .umbraCard()
    }

    // MARK: - Helpers

    @ViewBuilder
    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(UmbraTheme.textMuted)
            .textCase(.uppercase)
            .tracking(0.6)
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 4)
    }

    @ViewBuilder
    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 14))
                .foregroundColor(UmbraTheme.textSecondary)
                .frame(minWidth: 80, alignment: .leading)
            Spacer()
            Text(value)
                .font(.system(size: 14))
                .foregroundColor(UmbraTheme.textPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private func infoCard(@ViewBuilder content: () -> some View) -> some View {
        VStack {
            content()
        }
        .padding(16)
        .umbraCard()
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    private func statusText(_ cert: SSLCertificateInfo) -> String {
        if !cert.isValid {
            return "Expired"
        }
        if cert.isExpiringSoon {
            return "Expires in \(cert.daysUntilExpiry) days"
        }
        return "Valid"
    }
}
