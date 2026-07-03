import Foundation
import SwiftUI

private let resetCreditsEndpoint = URL(string: "https://chatgpt.com/backend-api/wham/rate-limit-reset-credits")!

struct ResetCredit: Identifiable {
    let id = UUID()
    var status: String
    var title: String
    var grantedAt: Date?
    var expiresAt: Date?
}

struct ResetCreditsSnapshot {
    var availableCount = 0
    var credits: [ResetCredit] = []
    var errorMessage: String?
    var usedProxy = false

    var nearestExpiry: Date? {
        credits.compactMap(\.expiresAt).min()
    }
}

private struct ResetCreditsResult {
    var availableCount: Int
    var credits: [ResetCredit]
    var usedProxy = false
}

private enum ResetCreditsError: LocalizedError {
    case message(String)

    var errorDescription: String? {
        switch self { case .message(let text): text }
    }
}

final class ResetCreditsClient {
    func fetch(accessToken: String, accountId: String?) async throws -> ResetCreditsSnapshot {
        do {
            return try await fetch(accessToken: accessToken, accountId: accountId, useProxy: false)
        } catch {
            if shouldRetryWithProxy(error) {
                return try await fetch(accessToken: accessToken, accountId: accountId, useProxy: true)
            }
            throw error
        }
    }

    private func fetch(accessToken: String, accountId: String?, useProxy: Bool) async throws -> ResetCreditsSnapshot {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 8
        config.timeoutIntervalForResource = 8
        config.waitsForConnectivity = false
        if useProxy {
            config.connectionProxyDictionary = [
                "HTTPEnable": true,
                "HTTPProxy": "127.0.0.1",
                "HTTPPort": 7890,
                "HTTPSEnable": true,
                "HTTPSProxy": "127.0.0.1",
                "HTTPSPort": 7890,
            ]
        }

        var request = URLRequest(url: resetCreditsEndpoint)
        request.httpMethod = "GET"
        request.timeoutInterval = 8
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("codex-quota-bar", forHTTPHeaderField: "User-Agent")
        if let accountId { request.setValue(accountId, forHTTPHeaderField: "ChatGPT-Account-Id") }

        let (data, response) = try await URLSession(configuration: config).data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ResetCreditsError.message(resetCreditsLocalized("reset_credits.not_json"))
        }
        if http.statusCode == 401 {
            throw ResetCreditsError.message(resetCreditsLocalized("reset_credits.auth_failed"))
        }
        guard (200..<300).contains(http.statusCode) else {
            throw ResetCreditsError.message(String(format: resetCreditsLocalized("reset_credits.http_failed"), http.statusCode))
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ResetCreditsError.message(resetCreditsLocalized("reset_credits.not_json"))
        }

        var result = parseResetCredits(json)
        result.usedProxy = useProxy
        return ResetCreditsSnapshot(
            availableCount: result.availableCount,
            credits: result.credits,
            errorMessage: nil,
            usedProxy: result.usedProxy
        )
    }

    private func parseResetCredits(_ json: [String: Any]) -> ResetCreditsResult {
        let credits = creditRecords(in: json)
            .map { raw in
                ResetCredit(
                    status: resetCreditsCleanString(raw["status"]) ?? resetCreditsLocalized("reset_credits.unknown_status"),
                    title: resetCreditsCleanString(raw["title"]) ?? resetCreditsLocalized("reset_credits.untitled"),
                    grantedAt: resetCreditsDate(raw["granted_at"]),
                    expiresAt: resetCreditsDate(raw["expires_at"])
                )
            }
            .sorted { left, right in
                (left.expiresAt ?? .distantFuture) < (right.expiresAt ?? .distantFuture)
            }

        let fallbackAvailable = credits.filter { $0.status.caseInsensitiveCompare("available") == .orderedSame }.count
        let available = Int(resetCreditsNumber(json["available_count"]) ?? Double(fallbackAvailable))
        return ResetCreditsResult(availableCount: max(0, available), credits: credits)
    }

    private func creditRecords(in json: [String: Any]) -> [[String: Any]] {
        if let records = json["credits"] as? [[String: Any]] { return records }
        if let records = json["data"] as? [[String: Any]] { return records }
        if let wrapper = json["credits"] as? [String: Any] {
            if let records = wrapper["items"] as? [[String: Any]] { return records }
            if let records = wrapper["credits"] as? [[String: Any]] { return records }
            if let records = wrapper["data"] as? [[String: Any]] { return records }
        }
        if let wrapper = json["data"] as? [String: Any] {
            if let records = wrapper["items"] as? [[String: Any]] { return records }
            if let records = wrapper["credits"] as? [[String: Any]] { return records }
        }
        return []
    }

    private func shouldRetryWithProxy(_ error: Error) -> Bool {
        let nsError = error as NSError
        guard nsError.domain == NSURLErrorDomain else { return false }
        return [
            NSURLErrorTimedOut,
            NSURLErrorCannotFindHost,
            NSURLErrorCannotConnectToHost,
            NSURLErrorNetworkConnectionLost,
            NSURLErrorNotConnectedToInternet,
            NSURLErrorDNSLookupFailed,
            NSURLErrorSecureConnectionFailed,
        ].contains(nsError.code)
    }
}

struct ResetCreditsPanel: View {
    let snapshot: ResetCreditsSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text(resetCreditsLocalized("reset_credits.title"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(availableText)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.green)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(.green.opacity(0.12), in: RoundedRectangle(cornerRadius: 7))
            }

            if let errorMessage = snapshot.errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.subheadline)
                    .foregroundStyle(.red)
                    .lineLimit(2)
            } else if snapshot.credits.isEmpty {
                Label(resetCreditsLocalized("reset_credits.empty"), systemImage: "clock.badge.exclamationmark")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                HStack(spacing: 6) {
                    Text(resetCreditsLocalized("reset_credits.nearest_label"))
                        .font(.subheadline.weight(.semibold))
                    Text(nearestExpiryText)
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(snapshot.credits.enumerated()), id: \.element.id) { index, credit in
                        ResetCreditExpiryRow(credit: credit)
                        if index < snapshot.credits.count - 1 {
                            Divider()
                        }
                    }
                }
            }
        }
        .padding(10)
        .background(.secondary.opacity(0.10), in: RoundedRectangle(cornerRadius: 9))
    }

    private var nearestExpiryText: String {
        guard let nearestExpiry = snapshot.nearestExpiry else {
            return resetCreditsLocalized("reset_credits.no_expiry")
        }
        return String(format: resetCreditsLocalized("reset_credits.expiry_with_duration"), resetCreditDurationText(to: nearestExpiry), resetCreditLocalDateTime(nearestExpiry))
    }

    private var availableText: String {
        if snapshot.errorMessage != nil {
            return resetCreditsLocalized("reset_credits.available_unknown")
        }
        return String(format: resetCreditsLocalized("reset_credits.available"), snapshot.availableCount)
    }
}

private struct ResetCreditExpiryRow: View {
    let credit: ResetCredit

    var body: some View {
        HStack(spacing: 10) {
            Text(resetCreditDurationText(to: credit.expiresAt))
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundStyle(durationColor)
                .frame(width: 82, alignment: .leading)
            Text(resetCreditLocalDateTime(credit.expiresAt))
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
    }

    private var durationColor: Color {
        guard let expiresAt = credit.expiresAt else { return .secondary }
        if expiresAt.timeIntervalSinceNow < 3 * 24 * 3600 { return .orange }
        return .primary
    }
}

func resetCreditLocalDateTime(_ date: Date?) -> String {
    guard let date else { return "--" }
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd HH:mm"
    return formatter.string(from: date)
}

private func resetCreditDurationText(to date: Date?) -> String {
    guard let date else { return "--" }
    let seconds = date.timeIntervalSinceNow
    if seconds <= 0 { return resetCreditsLocalized("reset_credits.expired") }
    let minutes = max(1, Int((seconds / 60).rounded()))
    if minutes < 60 {
        return String(format: resetCreditsLocalized("reset_credits.duration_minutes"), minutes)
    }
    let hours = minutes / 60
    let remainingMinutes = minutes % 60
    if hours < 24 {
        if remainingMinutes == 0 {
            return String(format: resetCreditsLocalized("reset_credits.duration_hours"), hours)
        }
        return String(format: resetCreditsLocalized("reset_credits.duration_hours_minutes"), hours, remainingMinutes)
    }
    let days = hours / 24
    let remainingHours = hours % 24
    if remainingHours == 0 {
        return String(format: resetCreditsLocalized("reset_credits.duration_days"), days)
    }
    return String(format: resetCreditsLocalized("reset_credits.duration_days_hours"), days, remainingHours)
}

private func resetCreditsDate(_ value: Any?) -> Date? {
    if let number = resetCreditsNumber(value) {
        return Date(timeIntervalSince1970: number > 10_000_000_000 ? number / 1000 : number)
    }
    guard let text = resetCreditsCleanString(value) else { return nil }
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = formatter.date(from: text) { return date }
    formatter.formatOptions = [.withInternetDateTime]
    return formatter.date(from: text)
}

private func resetCreditsNumber(_ value: Any?) -> Double? {
    if let number = value as? NSNumber { return number.doubleValue }
    if let text = value as? String { return Double(text) }
    return nil
}

private func resetCreditsCleanString(_ value: Any?) -> String? {
    guard let text = value as? String else { return nil }
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
}

private func resetCreditsUsesChinese() -> Bool {
    Locale.preferredLanguages.first?.lowercased().hasPrefix("zh") == true
}

private func resetCreditsLocalized(_ key: String) -> String {
    let en: [String: String] = [
        "reset_credits.title": "Reset credits",
        "reset_credits.available": "%ld available",
        "reset_credits.available_unknown": "-- available",
        "reset_credits.nearest_label": "Nearest expiry",
        "reset_credits.expiry_with_duration": "%@ · %@ local",
        "reset_credits.no_expiry": "Expiry unavailable",
        "reset_credits.empty": "No reset credits",
        "reset_credits.expired": "Expired",
        "reset_credits.duration_minutes": "%ldm",
        "reset_credits.duration_hours": "%ldh",
        "reset_credits.duration_hours_minutes": "%ldh %ldm",
        "reset_credits.duration_days": "%ldd",
        "reset_credits.duration_days_hours": "%ldd %ldh",
        "reset_credits.unknown_status": "unknown",
        "reset_credits.untitled": "Untitled reset",
        "reset_credits.auth_failed": "Credential expired or Authorization header was not accepted",
        "reset_credits.http_failed": "Reset credits request failed with HTTP %ld",
        "reset_credits.not_json": "Reset credits response was not JSON",
    ]
    let zh: [String: String] = [
        "reset_credits.title": "重置机会",
        "reset_credits.available": "%ld 可用",
        "reset_credits.available_unknown": "-- 可用",
        "reset_credits.nearest_label": "最近到期",
        "reset_credits.expiry_with_duration": "%@ · %@ 本地",
        "reset_credits.no_expiry": "到期时间不可用",
        "reset_credits.empty": "暂无重置机会",
        "reset_credits.expired": "已过期",
        "reset_credits.duration_minutes": "%ld分钟后",
        "reset_credits.duration_hours": "%ld小时后",
        "reset_credits.duration_hours_minutes": "%ld小时%ld分钟后",
        "reset_credits.duration_days": "%ld天后",
        "reset_credits.duration_days_hours": "%ld天%ld小时后",
        "reset_credits.unknown_status": "unknown",
        "reset_credits.untitled": "未命名重置机会",
        "reset_credits.auth_failed": "凭证已失效或 Authorization header 未正确携带",
        "reset_credits.http_failed": "重置机会请求失败 (HTTP %ld)",
        "reset_credits.not_json": "重置机会接口返回不是 JSON",
    ]
    return (resetCreditsUsesChinese() ? zh : en)[key] ?? en[key] ?? key
}
