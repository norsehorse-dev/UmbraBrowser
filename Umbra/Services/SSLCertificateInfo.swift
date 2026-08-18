// SSLCertificateInfo.swift
// Umbra — Privacy-First Browser

import Foundation
import Security

struct SSLCertificateInfo: Equatable {
    let subject: String
    let issuer: String
    let validFrom: Date
    let validTo: Date
    let isEV: Bool
    let organizationName: String?
    let commonName: String?

    var isValid: Bool {
        let now = Date()
        return now >= validFrom && now <= validTo
    }

    var daysUntilExpiry: Int {
        Calendar.current.dateComponents([.day], from: Date(), to: validTo).day ?? 0
    }

    var isExpiringSoon: Bool {
        daysUntilExpiry <= 30 && daysUntilExpiry > 0
    }

    var displayIssuer: String { issuer }
    var displaySubject: String { commonName ?? subject }

    /// Build from a URLProtectionSpace auth challenge
    static func from(protectionSpace: URLProtectionSpace) -> SSLCertificateInfo? {
        guard let serverTrust = protectionSpace.serverTrust else { return nil }
        return from(serverTrust: serverTrust, host: protectionSpace.host)
    }

    /// Build from SecTrust using only iOS-safe APIs
    static func from(serverTrust: SecTrust, host: String = "") -> SSLCertificateInfo? {
        let certCount = SecTrustGetCertificateCount(serverTrust)
        guard certCount > 0 else { return nil }

        // Get leaf certificate — use the iOS-safe approach
        var leaf: SecCertificate?
        if #available(iOS 15.0, *) {
            if let chain = SecTrustCopyCertificateChain(serverTrust) as? [SecCertificate] {
                leaf = chain.first
            }
        }

        // Fallback if chain copy didn't work
        if leaf == nil {
            // SecTrustGetCertificateAtIndex is deprecated but still works
            leaf = SecTrustGetCertificateAtIndex(serverTrust, 0)
        }

        guard let leafCert = leaf else { return nil }

        // Subject (common name)
        let summary = SecCertificateCopySubjectSummary(leafCert) as String? ?? host

        // Issuer from second cert in chain
        var issuerName = "Unknown CA"
        if certCount > 1 {
            var issuerCert: SecCertificate?
            if #available(iOS 15.0, *) {
                if let chain = SecTrustCopyCertificateChain(serverTrust) as? [SecCertificate],
                   chain.count > 1 {
                    issuerCert = chain[1]
                }
            }
            if issuerCert == nil {
                issuerCert = SecTrustGetCertificateAtIndex(serverTrust, 1)
            }
            if let ic = issuerCert {
                issuerName = SecCertificateCopySubjectSummary(ic) as String? ?? "Unknown CA"
            }
        }

        // Parse validity dates from DER-encoded certificate data
        let derData = SecCertificateCopyData(leafCert) as Data
        let dates = extractValidityDates(from: derData)

        return SSLCertificateInfo(
            subject: summary,
            issuer: issuerName,
            validFrom: dates.notBefore ?? Date(),
            validTo: dates.notAfter ?? Date().addingTimeInterval(365 * 24 * 3600),
            isEV: false,
            organizationName: nil,
            commonName: summary
        )
    }

    // MARK: - DER date extraction

    private static func extractValidityDates(from data: Data) -> (notBefore: Date?, notAfter: Date?) {
        let bytes = [UInt8](data)
        var notBefore: Date?
        var notAfter: Date?
        var dateCount = 0

        var i = 0
        while i < bytes.count - 2 {
            // UTCTime = 0x17, GeneralizedTime = 0x18
            if bytes[i] == 0x17 || bytes[i] == 0x18 {
                let isUTC = bytes[i] == 0x17
                let length = Int(bytes[i + 1])
                if length > 0, i + 2 + length <= bytes.count {
                    let slice = Array(bytes[(i + 2)..<(i + 2 + length)])
                    if let str = String(bytes: slice, encoding: .ascii),
                       let date = parseASN1Date(str, isUTC: isUTC) {
                        if dateCount == 0 {
                            notBefore = date
                        } else if dateCount == 1 {
                            notAfter = date
                            break
                        }
                        dateCount += 1
                    }
                    i += 2 + length
                    continue
                }
            }
            i += 1
        }
        return (notBefore, notAfter)
    }

    private static func parseASN1Date(_ string: String, isUTC: Bool) -> Date? {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.timeZone = TimeZone(identifier: "UTC")
        fmt.dateFormat = isUTC ? "yyMMddHHmmss'Z'" : "yyyyMMddHHmmss'Z'"
        return fmt.date(from: string)
    }
}
