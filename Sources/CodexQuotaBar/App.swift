import AppKit
import Combine
import CryptoKit
import ServiceManagement
import SwiftUI

private let usageEndpoint = URL(string: "https://chatgpt.com/backend-api/wham/usage")!

private func usesChinese() -> Bool {
    Locale.preferredLanguages.first?.lowercased().hasPrefix("zh") == true
}

private func localized(_ key: String) -> String {
    let en: [String: String] = [
        "app.title": "Codex Quota",
        "app.subtitle": "Shared local session, quota only",
        "status.sync": "SYNC",
        "status.check": "CHECK",
        "status.proxy": "PROXY",
        "status.live": "LIVE",
        "button.refresh": "Refresh",
        "button.quit": "Quit",
        "settings.startup": "Open at login",
        "settings.startup_on": "Codex Quota Bar will start after you sign in.",
        "settings.startup_off": "Keep it manual unless you enable this.",
        "settings.startup_approval": "Approve it in System Settings > Login Items.",
        "settings.startup_missing": "Move the app into Applications before enabling.",
        "settings.startup_failed": "Unable to update login item: %@",
        "settings.startup_attention": "Open at login needs approval",
        "tab.overview": "Overview",
        "tab.chart": "7d chart",
        "account.default": "Codex account",
        "account.auth_refreshed": "Auth refreshed %@",
        "window.fast": "Fast window",
        "window.weekly": "Weekly window",
        "reset.unavailable": "Reset time unavailable",
        "reset.in.at": "Reset in %@ at %@",
        "quota.used": "%ld%% used",
        "quota.no_data": "No data",
        "chart.title": "7-day usage in this cycle",
        "chart.empty": "Refresh a few times to build the chart.",
        "chart.used": "%ld%% used",
        "chart.axis.used_percent": "Used %",
        "chart.points": "%ld samples",
        "panel.planning": "Planning outlook",
        "footer.updated": "Updated %@%@",
        "footer.via_proxy": " via proxy",
        "footer.reading": "Reading Codex quota",
        "footer.waiting": "Waiting for data",
        "prediction.collecting": "Collecting planning data",
        "prediction.collecting_detail": "A few refreshes will make the forecast steadier.",
        "prediction.pace_empty": "Pace --",
        "prediction.low": "Low confidence",
        "prediction.medium": "Medium confidence",
        "prediction.high": "High confidence",
        "prediction.no_trend": "No burn trend yet",
        "prediction.no_trend_detail": "7d usage has not increased enough to project depletion.",
        "prediction.pace_zero": "Pace 0%/h",
        "prediction.early_empty": "Early estimate: empty in %@",
        "prediction.early_reset": "Early estimate: lasts through reset",
        "prediction.early_before_detail": "Based on the current cycle only; empty around %@ if this pace holds.",
        "prediction.early_after_detail": "Based on the current cycle only; empty in %@ after reset.",
        "prediction.runout": "7d runout in %@",
        "prediction.lasts_reset": "7d likely lasts through reset",
        "prediction.before_detail": "Projected empty around %@, before the current reset.",
        "prediction.after_detail": "At this pace, empty in %@, after the current reset.",
        "prediction.pace": "Pace %.2f%%/h",
        "burst.unknown": "5h burst unknown",
        "burst.high": "5h burst high",
        "burst.moderate": "5h burst moderate",
        "burst.calm": "5h burst calm",
        "auth.missing_token": "auth.json is missing tokens.access_token",
        "auth.expired": "Codex auth is expired or not accepted (HTTP %ld)",
        "usage.http_failed": "Usage request failed with HTTP %ld",
        "usage.not_json": "Usage response was not JSON",
        "error.unable_auth": "Unable to read Codex auth.json",
    ]
    let zh: [String: String] = [
        "app.title": "Codex 额度",
        "app.subtitle": "共享本地会话，仅显示额度",
        "status.sync": "同步",
        "status.check": "检查",
        "status.proxy": "代理",
        "status.live": "在线",
        "button.refresh": "刷新",
        "button.quit": "退出",
        "settings.startup": "开机自启动",
        "settings.startup_on": "登录后会自动启动 Codex 额度。",
        "settings.startup_off": "默认手动启动，需要时可打开。",
        "settings.startup_approval": "请在系统设置 > 登录项中批准。",
        "settings.startup_missing": "请先把 app 放进“应用程序”再开启。",
        "settings.startup_failed": "无法更新登录项：%@",
        "settings.startup_attention": "开机自启动需要批准",
        "tab.overview": "概览",
        "tab.chart": "7天图表",
        "account.default": "Codex 账号",
        "account.auth_refreshed": "凭证刷新 %@",
        "window.fast": "5小时窗口",
        "window.weekly": "7天窗口",
        "reset.unavailable": "重置时间不可用",
        "reset.in.at": "%@后重置 %@",
        "quota.used": "已用 %ld%%",
        "quota.no_data": "无数据",
        "chart.title": "本周期7天额度消耗",
        "chart.empty": "多刷新几次后会形成图表。",
        "chart.used": "已用 %ld%%",
        "chart.axis.used_percent": "已用 %",
        "chart.points": "%ld 个采样",
        "panel.planning": "用量规划",
        "footer.updated": "已更新 %@%@",
        "footer.via_proxy": "，代理",
        "footer.reading": "正在读取 Codex 额度",
        "footer.waiting": "等待数据",
        "prediction.collecting": "正在积累规划数据",
        "prediction.collecting_detail": "多刷新几次后，预测会更稳定。",
        "prediction.pace_empty": "速度 --",
        "prediction.low": "低置信度",
        "prediction.medium": "中置信度",
        "prediction.high": "高置信度",
        "prediction.no_trend": "暂时没有消耗趋势",
        "prediction.no_trend_detail": "7天额度增长还不够，暂时无法预测耗尽时间。",
        "prediction.pace_zero": "速度 0%/小时",
        "prediction.early_empty": "早期估算：%@后耗尽",
        "prediction.early_reset": "早期估算：可撑到重置",
        "prediction.early_before_detail": "仅基于当前周期；若保持此速度，约 %@ 耗尽。",
        "prediction.early_after_detail": "仅基于当前周期；约 %@后耗尽，晚于本次重置。",
        "prediction.runout": "7天额度 %@后耗尽",
        "prediction.lasts_reset": "7天额度大概率可撑到重置",
        "prediction.before_detail": "预计约 %@ 耗尽，早于当前重置时间。",
        "prediction.after_detail": "按当前速度约 %@ 后耗尽，晚于本次重置。",
        "prediction.pace": "速度 %.2f%%/小时",
        "burst.unknown": "5小时压力未知",
        "burst.high": "5小时压力高",
        "burst.moderate": "5小时压力中",
        "burst.calm": "5小时压力低",
        "auth.missing_token": "auth.json 缺少 tokens.access_token",
        "auth.expired": "Codex 授权已过期或不可用 (HTTP %ld)",
        "usage.http_failed": "额度请求失败 (HTTP %ld)",
        "usage.not_json": "额度接口返回不是 JSON",
        "error.unable_auth": "无法读取 Codex auth.json",
    ]
    return (usesChinese() ? zh : en)[key] ?? en[key] ?? key
}

private func cleanString(_ value: Any?) -> String? {
    guard let text = value as? String else { return nil }
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
}

private func cleanNumber(_ value: Any?) -> Double? {
    if let number = value as? NSNumber { return number.doubleValue }
    if let text = value as? String { return Double(text) }
    return nil
}

private func clampPercent(_ value: Double) -> Double {
    guard value.isFinite else { return 0 }
    return min(100, max(0, value))
}

private func durationText(_ seconds: TimeInterval) -> String {
    let minutes = max(1, Int((max(0, seconds) / 60).rounded()))
    if minutes < 60 { return usesChinese() ? "\(minutes)分钟" : "\(minutes)m" }
    let hours = minutes / 60
    let remMinutes = minutes % 60
    if hours < 24 {
        if usesChinese() { return remMinutes == 0 ? "\(hours)小时" : "\(hours)小时\(remMinutes)分钟" }
        return remMinutes == 0 ? "\(hours)h" : "\(hours)h \(remMinutes)m"
    }
    let days = hours / 24
    let remHours = hours % 24
    if usesChinese() { return remHours == 0 ? "\(days)天" : "\(days)天\(remHours)小时" }
    return remHours == 0 ? "\(days)d" : "\(days)d \(remHours)h"
}

private func clockText(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm"
    return formatter.string(from: date)
}

private func shortDateTime(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = usesChinese() ? "M月d日 HH:mm" : "MMM d HH:mm"
    return formatter.string(from: date)
}

private func nowClockText() -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm:ss"
    return formatter.string(from: Date())
}

private func resetText(_ date: Date?) -> String {
    guard let date else { return localized("reset.unavailable") }
    return String(format: localized("reset.in.at"), durationText(date.timeIntervalSinceNow), clockText(date))
}

private func sha256String(_ input: String) -> String {
    let digest = SHA256.hash(data: Data(input.utf8))
    return digest.map { String(format: "%02x", $0) }.joined()
}

private func base64URLDecode(_ text: String) -> Data? {
    var base64 = text.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
    let padding = (4 - base64.count % 4) % 4
    if padding > 0 { base64 += String(repeating: "=", count: padding) }
    return Data(base64Encoded: base64)
}

private func parseISODate(_ text: String?) -> Date? {
    guard let text else { return nil }
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = formatter.date(from: text) { return date }
    formatter.formatOptions = [.withInternetDateTime]
    return formatter.date(from: text)
}

private struct QuotaWindow {
    var label: String
    var usedPercent: Double
    var remainingPercent: Double
    var resetAt: Date?
    var windowSeconds: Double
}

private struct Prediction {
    var headline = localized("prediction.collecting")
    var detail = localized("prediction.collecting_detail")
    var pace = localized("prediction.pace_empty")
    var burst = localized("burst.unknown")
    var confidence = localized("prediction.low")
    var sampleCount = 0
}

private struct UsageHistoryPoint: Identifiable {
    let id = UUID()
    var date: Date
    var usedPercent: Double
    var remainingPercent: Double
}

private struct AuthInfo {
    var path: URL
    var authMode: String?
    var accessToken: String
    var accountId: String?
    var email: String?
    var lastRefresh: Date?
}

private struct UsageResult {
    var primary: QuotaWindow?
    var secondary: QuotaWindow?
    var plan: String?
    var usedProxy = false
}

private func fetchResetCreditsSnapshot(client: ResetCreditsClient, auth: AuthInfo) async -> ResetCreditsSnapshot {
    do {
        return try await client.fetch(accessToken: auth.accessToken, accountId: auth.accountId)
    } catch {
        return ResetCreditsSnapshot(errorMessage: error.localizedDescription)
    }
}

private struct QuotaSnapshot {
    var primary: QuotaWindow?
    var secondary: QuotaWindow?
    var resetCredits = ResetCreditsSnapshot()
    var prediction = Prediction()
    var weeklyHistory: [UsageHistoryPoint] = []
    var plan: String?
    var authPath = NSHomeDirectory() + "/.codex/auth.json"
    var authMode: String?
    var accountId: String?
    var email: String?
    var authLastRefresh: Date?
    var lastUpdated: Date?
    var errorMessage: String?
    var loading = false
    var usedProxy = false
}

@MainActor
private final class LaunchAtLoginController: ObservableObject {
    @Published var isEnabled = false
    @Published var detailText = localized("settings.startup_off")
    @Published private(set) var status = SMAppService.mainApp.status

    init() {
        refresh()
    }

    func refresh() {
        let nextStatus = SMAppService.mainApp.status
        status = nextStatus
        isEnabled = nextStatus == .enabled
        detailText = detail(for: nextStatus)
    }

    @discardableResult
    func setEnabled(_ enabled: Bool) -> Bool {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            refresh()
            return true
        } catch {
            refresh()
            detailText = String(format: localized("settings.startup_failed"), error.localizedDescription)
            return false
        }
    }

    private func detail(for status: SMAppService.Status) -> String {
        switch status {
        case .enabled:
            return localized("settings.startup_on")
        case .requiresApproval:
            return localized("settings.startup_approval")
        case .notFound:
            return localized("settings.startup_missing")
        case .notRegistered:
            return localized("settings.startup_off")
        @unknown default:
            return localized("settings.startup_off")
        }
    }
}

private enum AppError: LocalizedError {
    case message(String)
    var errorDescription: String? {
        switch self { case .message(let text): text }
    }
}

private final class AuthStore {
    func readAuth() throws -> AuthInfo {
        let path = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".codex/auth.json")
        let data = try Data(contentsOf: path)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tokens = json["tokens"] as? [String: Any],
              let access = cleanString(tokens["access_token"]) else {
            throw AppError.message(localized("auth.missing_token"))
        }
        let identity = identityFromAccessToken(access)
        return AuthInfo(
            path: path,
            authMode: cleanString(json["auth_mode"]),
            accessToken: access,
            accountId: cleanString(tokens["account_id"]) ?? identity.accountId,
            email: identity.email,
            lastRefresh: parseISODate(cleanString(json["last_refresh"]))
        )
    }

    private func identityFromAccessToken(_ token: String) -> (accountId: String?, email: String?) {
        let parts = token.split(separator: ".").map(String.init)
        guard parts.count == 3,
              let data = base64URLDecode(parts[1]),
              let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return (nil, nil)
        }
        let auth = payload["https://api.openai.com/auth"] as? [String: Any]
        let profile = payload["https://api.openai.com/profile"] as? [String: Any]
        return (
            cleanString(auth?["chatgpt_account_id"]),
            cleanString(profile?["email"])
        )
    }
}

private final class UsageClient {
    func fetch(auth: AuthInfo) async throws -> UsageResult {
        do {
            return try await fetch(auth: auth, useProxy: false)
        } catch {
            if shouldRetryWithProxy(error) {
                return try await fetch(auth: auth, useProxy: true)
            }
            throw error
        }
    }

    private func fetch(auth: AuthInfo, useProxy: Bool) async throws -> UsageResult {
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

        var request = URLRequest(url: usageEndpoint)
        request.httpMethod = "GET"
        request.timeoutInterval = 8
        request.setValue("Bearer \(auth.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("codex-quota-bar", forHTTPHeaderField: "User-Agent")
        if let accountId = auth.accountId { request.setValue(accountId, forHTTPHeaderField: "ChatGPT-Account-Id") }

        let (data, response) = try await URLSession(configuration: config).data(for: request)
        guard let http = response as? HTTPURLResponse else { throw AppError.message(localized("usage.not_json")) }
        guard (200..<300).contains(http.statusCode) else {
            let key = (http.statusCode == 401 || http.statusCode == 403) ? "auth.expired" : "usage.http_failed"
            throw AppError.message(String(format: localized(key), http.statusCode))
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let rateLimit = json["rate_limit"] as? [String: Any] else {
            throw AppError.message(localized("usage.not_json"))
        }

        var result = UsageResult()
        result.primary = buildWindow(rateLimit["primary_window"] as? [String: Any], fallbackSeconds: 18_000, fallbackLabel: "5h")
        result.secondary = buildWindow(rateLimit["secondary_window"] as? [String: Any], fallbackSeconds: 604_800, fallbackLabel: "7d")
        result.plan = cleanString(json["plan_type"])
        if let credits = json["credits"] as? [String: Any], let balance = cleanNumber(credits["balance"]) {
            let balanceText = String(format: "$%.2f", balance)
            result.plan = result.plan.map { "\($0) (\(balanceText))" } ?? balanceText
        }
        result.usedProxy = useProxy
        return result
    }

    private func buildWindow(_ raw: [String: Any]?, fallbackSeconds: Double, fallbackLabel: String) -> QuotaWindow? {
        guard let raw else { return nil }
        let seconds = cleanNumber(raw["limit_window_seconds"]) ?? fallbackSeconds
        let used = clampPercent(cleanNumber(raw["used_percent"]) ?? 0)
        let resetRaw = cleanNumber(raw["reset_at"])
        let reset = resetRaw.map { Date(timeIntervalSince1970: $0 > 10_000_000_000 ? $0 / 1000 : $0) }
        return QuotaWindow(
            label: windowLabel(seconds: seconds, fallback: fallbackLabel),
            usedPercent: used,
            remainingPercent: clampPercent(100 - used),
            resetAt: reset,
            windowSeconds: seconds
        )
    }

    private func windowLabel(seconds: Double, fallback: String) -> String {
        let hours = Int((seconds / 3600).rounded())
        if hours >= 168 { return "7d" }
        if hours >= 24 && hours % 24 == 0 { return "\(hours / 24)d" }
        if hours > 0 { return "\(hours)h" }
        return fallback
    }

    private func shouldRetryWithProxy(_ error: Error) -> Bool {
        let code = (error as NSError).code
        let domain = (error as NSError).domain
        guard domain == NSURLErrorDomain else { return false }
        return [
            NSURLErrorTimedOut,
            NSURLErrorCannotFindHost,
            NSURLErrorCannotConnectToHost,
            NSURLErrorNetworkConnectionLost,
            NSURLErrorNotConnectedToInternet,
            NSURLErrorDNSLookupFailed,
            NSURLErrorSecureConnectionFailed,
        ].contains(code)
    }
}

private final class HistoryStore {
    let fileURL: URL

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("CodexQuotaBar", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("usage-history.json")
    }

    func records() -> [[String: Any]] {
        guard let data = try? Data(contentsOf: fileURL),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let records = root["records"] as? [[String: Any]] else { return [] }
        return records
    }

    func append(_ snapshot: QuotaSnapshot, accountKey: String) {
        guard snapshot.primary != nil || snapshot.secondary != nil else { return }
        var records = records()
        var record: [String: Any] = ["timestamp": Date().timeIntervalSince1970, "accountKey": accountKey]
        if let primary = snapshot.primary {
            record["primaryUsed"] = primary.usedPercent
            record["primaryRemaining"] = primary.remainingPercent
            record["primaryResetAt"] = primary.resetAt?.timeIntervalSince1970
        }
        if let secondary = snapshot.secondary {
            record["secondaryUsed"] = secondary.usedPercent
            record["secondaryRemaining"] = secondary.remainingPercent
            record["secondaryResetAt"] = secondary.resetAt?.timeIntervalSince1970
        }
        records.append(record)
        let cutoff = Date().timeIntervalSince1970 - 14 * 24 * 3600
        records = records.filter { (cleanNumber($0["timestamp"]) ?? 0) >= cutoff }
        if records.count > 3000 { records = Array(records.suffix(3000)) }
        let root: [String: Any] = ["version": 1, "records": records]
        if let data = try? JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted]) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    func weeklyHistory(snapshot: QuotaSnapshot, accountKey: String) -> [UsageHistoryPoint] {
        guard let secondary = snapshot.secondary else { return [] }
        let now = Date().timeIntervalSince1970
        let cycleEnd = secondary.resetAt?.timeIntervalSince1970 ?? now
        let cycleStart = cycleEnd - max(secondary.windowSeconds, 7 * 24 * 3600)
        let cutoff = max(cycleStart, now - 7 * 24 * 3600)

        return records()
            .filter { record in
                let key = cleanString(record["accountKey"]) ?? "default"
                guard key == accountKey, cleanNumber(record["secondaryUsed"]) != nil else { return false }
                let timestamp = cleanNumber(record["timestamp"]) ?? 0
                guard timestamp >= cutoff && timestamp <= now + 60 else { return false }
                if let resetAt = secondary.resetAt, let reset = cleanNumber(record["secondaryResetAt"]) {
                    return abs(reset - resetAt.timeIntervalSince1970) < 2 * 3600
                }
                return true
            }
            .sorted { (cleanNumber($0["timestamp"]) ?? 0) < (cleanNumber($1["timestamp"]) ?? 0) }
            .map {
                UsageHistoryPoint(
                    date: Date(timeIntervalSince1970: cleanNumber($0["timestamp"]) ?? now),
                    usedPercent: clampPercent(cleanNumber($0["secondaryUsed"]) ?? 0),
                    remainingPercent: clampPercent(cleanNumber($0["secondaryRemaining"]) ?? 0)
                )
            }
    }

    func prediction(snapshot: QuotaSnapshot, accountKey: String) -> Prediction {
        var prediction = Prediction()
        prediction.burst = burstText(snapshot)
        guard let secondary = snapshot.secondary else { return prediction }

        let records = self.records()
            .filter { record in
                let key = cleanString(record["accountKey"]) ?? "default"
                guard key == accountKey, cleanNumber(record["secondaryUsed"]) != nil else { return false }
                if let resetAt = secondary.resetAt, let reset = cleanNumber(record["secondaryResetAt"]) {
                    return abs(reset - resetAt.timeIntervalSince1970) < 2 * 3600
                }
                return true
            }
            .sorted { (cleanNumber($0["timestamp"]) ?? 0) < (cleanNumber($1["timestamp"]) ?? 0) }
        prediction.sampleCount = records.count

        var rates: [(rate: Double, timestamp: Double)] = []
        for index in 1..<records.count {
            let previous = records[index - 1]
            let next = records[index]
            let dtHours = ((cleanNumber(next["timestamp"]) ?? 0) - (cleanNumber(previous["timestamp"]) ?? 0)) / 3600
            let delta = (cleanNumber(next["secondaryUsed"]) ?? 0) - (cleanNumber(previous["secondaryUsed"]) ?? 0)
            guard dtHours >= 0.08, delta >= 0.03 else { continue }
            let rate = delta / dtHours
            guard rate > 0, rate <= 15 else { continue }
            rates.append((rate, cleanNumber(next["timestamp"]) ?? Date().timeIntervalSince1970))
        }

        var rate = robustRate(rates)
        var usedFallback = false
        if rate <= 0 {
            rate = fallbackWeeklyRate(snapshot)
            usedFallback = rate > 0
        }
        guard rate > 0 else {
            prediction.headline = localized("prediction.no_trend")
            prediction.detail = localized("prediction.no_trend_detail")
            prediction.pace = localized("prediction.pace_zero")
            prediction.confidence = localized("prediction.low")
            return prediction
        }

        let hoursToEmpty = (100 - secondary.usedPercent) / rate
        let projected = Date(timeIntervalSinceNow: hoursToEmpty * 3600)
        let duration = durationText(hoursToEmpty * 3600)
        let beforeReset = secondary.resetAt.map { projected < $0 } ?? false
        if usedFallback {
            prediction.headline = beforeReset ? String(format: localized("prediction.early_empty"), duration) : localized("prediction.early_reset")
            prediction.detail = beforeReset ? String(format: localized("prediction.early_before_detail"), shortDateTime(projected)) : String(format: localized("prediction.early_after_detail"), duration)
        } else {
            prediction.headline = beforeReset ? String(format: localized("prediction.runout"), duration) : localized("prediction.lasts_reset")
            prediction.detail = beforeReset ? String(format: localized("prediction.before_detail"), shortDateTime(projected)) : String(format: localized("prediction.after_detail"), duration)
        }
        prediction.pace = String(format: localized("prediction.pace"), rate)
        prediction.confidence = (!usedFallback && rates.count >= 8) ? localized("prediction.high") : ((!usedFallback && rates.count >= 3) ? localized("prediction.medium") : localized("prediction.low"))
        return prediction
    }

    private func robustRate(_ rates: [(rate: Double, timestamp: Double)]) -> Double {
        guard rates.count >= 2 else { return 0 }
        let values = rates.map(\.rate).sorted()
        let median = values[values.count / 2]
        let maxAllowed = max(median * 4, median + 1)
        var weighted = 0.0
        var weights = 0.0
        let now = Date().timeIntervalSince1970
        for entry in rates where entry.rate <= maxAllowed {
            let ageHours = max(0, (now - entry.timestamp) / 3600)
            let weight = exp(-ageHours / 48)
            weighted += entry.rate * weight
            weights += weight
        }
        return weights > 0 ? weighted / weights : 0
    }

    private func fallbackWeeklyRate(_ snapshot: QuotaSnapshot) -> Double {
        guard let secondary = snapshot.secondary, let resetAt = secondary.resetAt, secondary.usedPercent > 0.3 else { return 0 }
        let cycleStart = resetAt.addingTimeInterval(-7 * 24 * 3600)
        let elapsedHours = Date().timeIntervalSince(cycleStart) / 3600
        return elapsedHours < 1 ? 0 : secondary.usedPercent / elapsedHours
    }

    private func burstText(_ snapshot: QuotaSnapshot) -> String {
        guard let primary = snapshot.primary else { return localized("burst.unknown") }
        if primary.remainingPercent < 15 { return localized("burst.high") }
        if primary.remainingPercent < 40 { return localized("burst.moderate") }
        return localized("burst.calm")
    }
}

@MainActor
private final class QuotaViewModel: ObservableObject {
    @Published var snapshot = QuotaSnapshot()
    private let authStore = AuthStore()
    private let usageClient = UsageClient()
    private let resetCreditsClient = ResetCreditsClient()
    private let historyStore = HistoryStore()
    private var refreshing = false
    private var timer: Timer?

    init() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    deinit { timer?.invalidate() }

    func refresh() {
        guard !refreshing else { return }
        refreshing = true
        snapshot.loading = true
        snapshot.errorMessage = nil

        Task {
            do {
                let auth = try authStore.readAuth()
                let result = try await usageClient.fetch(auth: auth)
                let resetCredits = await fetchResetCreditsSnapshot(client: resetCreditsClient, auth: auth)
                var next = QuotaSnapshot()
                next.primary = result.primary
                next.secondary = result.secondary
                next.resetCredits = resetCredits
                next.plan = result.plan
                next.authPath = auth.path.path
                next.authMode = auth.authMode
                next.accountId = auth.accountId
                next.email = auth.email
                next.authLastRefresh = auth.lastRefresh
                next.lastUpdated = Date()
                next.usedProxy = result.usedProxy
                let accountKey = sha256String(auth.accountId ?? auth.email ?? "default")
                historyStore.append(next, accountKey: accountKey)
                next.prediction = historyStore.prediction(snapshot: next, accountKey: accountKey)
                next.weeklyHistory = historyStore.weeklyHistory(snapshot: next, accountKey: accountKey)
                snapshot = next
            } catch {
                snapshot.loading = false
                snapshot.errorMessage = error.localizedDescription
            }
            refreshing = false
        }
    }

    var menuBarTitle: String {
        if let primary = snapshot.primary, let secondary = snapshot.secondary {
            return "\(primary.label) \(Int(primary.remainingPercent.rounded()))% | \(secondary.label) \(Int(secondary.remainingPercent.rounded()))%"
        }
        if snapshot.loading { return "Codex ..." }
        if snapshot.errorMessage != nil { return "Codex !" }
        return "Codex --"
    }

    var menuBarMeterTitle: String {
        guard let primary = snapshot.primary, let secondary = snapshot.secondary else {
            return menuBarTitle
        }
        return "\(primary.label) \(Int(primary.remainingPercent.rounded()))% · \(secondary.label) \(Int(secondary.remainingPercent.rounded()))%"
    }
}

private struct QuotaMenuView: View {
    @EnvironmentObject private var model: QuotaViewModel
    @State private var selectedTab = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            Divider()
            accountPanel
            Picker("", selection: $selectedTab) {
                Text(localized("tab.overview")).tag(0)
                Text(localized("tab.chart")).tag(1)
            }
            .pickerStyle(.segmented)

            if selectedTab == 0 {
                overview
            } else {
                UsageChartPanel(points: model.snapshot.weeklyHistory, currentUsed: model.snapshot.secondary?.usedPercent ?? 0)
            }

            footer
        }
        .padding(14)
        .frame(width: 400)
    }

    private var header: some View {
        HStack(spacing: 12) {
            CodexGlyph(size: 22)
                .frame(width: 42, height: 42)
                .background(.secondary.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 2) {
                Text(localized("app.title"))
                    .font(.title2.weight(.semibold))
                Text((model.snapshot.plan ?? localized("app.subtitle")).uppercased())
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button { model.refresh() } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 13, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .frame(width: 28, height: 28)
                    .background(.secondary.opacity(0.10), in: RoundedRectangle(cornerRadius: 7))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.primary)
            .disabled(model.snapshot.loading)
            .opacity(model.snapshot.loading ? 0.42 : 1)
            .help(localized("button.refresh"))
            StatusBadge(snapshot: model.snapshot)
        }
    }

    private var accountPanel: some View {
        HStack(spacing: 10) {
            Image(systemName: "person.crop.circle")
                .font(.title3)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(model.snapshot.email ?? localized("account.default"))
                    .font(.headline)
                    .lineLimit(1)
                Text(accountSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Text((model.snapshot.authMode ?? "chatgpt").uppercased())
                .font(.caption.weight(.bold))
                .foregroundStyle(.green)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.green.opacity(0.12), in: RoundedRectangle(cornerRadius: 7))
        }
        .padding(10)
        .background(.secondary.opacity(0.10), in: RoundedRectangle(cornerRadius: 9))
    }

    private var accountSubtitle: String {
        if let date = model.snapshot.authLastRefresh {
            return String(format: localized("account.auth_refreshed"), shortDateTime(date))
        }
        return localized("app.subtitle")
    }

    private var overview: some View {
        VStack(spacing: 8) {
            UsageWindowPanel(title: localized("window.fast"), window: model.snapshot.primary)
            UsageWindowPanel(title: localized("window.weekly"), window: model.snapshot.secondary)
            ResetCreditsPanel(snapshot: model.snapshot.resetCredits)
            PredictionPanel(prediction: model.snapshot.prediction)
        }
    }

    private var footer: some View {
        HStack {
            Text(footerText)
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    private var footerText: String {
        if model.snapshot.lastUpdated != nil {
            return String(format: localized("footer.updated"), nowClockText(), model.snapshot.usedProxy ? localized("footer.via_proxy") : "")
        }
        return model.snapshot.loading ? localized("footer.reading") : localized("footer.waiting")
    }
}

private struct CodexGlyph: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                .fill(.primary)
            RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                .stroke(.white.opacity(0.20), lineWidth: max(0.6, size * 0.045))
            Text(">_")
                .font(.system(size: size * 0.43, weight: .heavy, design: .monospaced))
                .baselineOffset(size * 0.03)
                .foregroundStyle(.background)
        }
        .frame(width: size, height: size)
        .accessibilityLabel("Codex")
    }
}

private struct StatusBadge: View {
    let snapshot: QuotaSnapshot
    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(snapshot.errorMessage == nil ? .white : .red)
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .background(background, in: RoundedRectangle(cornerRadius: 8))
    }
    private var text: String {
        if snapshot.loading { return localized("status.sync") }
        if snapshot.errorMessage != nil { return localized("status.check") }
        if snapshot.usedProxy { return localized("status.proxy") }
        return localized("status.live")
    }
    private var background: Color {
        snapshot.errorMessage == nil ? .blue : .red.opacity(0.12)
    }
}

private struct UsageWindowPanel: View {
    let title: String
    let window: QuotaWindow?

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                Text(window.map { "\(Int($0.remainingPercent.rounded()))%" } ?? "--%")
                    .font(.title3.monospacedDigit().weight(.semibold))
            }
            UsagePill(title: window?.label ?? "--", remaining: window?.remainingPercent, resetAt: window?.resetAt)
        }
        .padding(10)
        .background(.secondary.opacity(0.10), in: RoundedRectangle(cornerRadius: 9))
    }
}

private struct UsagePill: View {
    let title: String
    let remaining: Double?
    let resetAt: Date?

    var body: some View {
        ZStack(alignment: .leading) {
            Capsule().fill(.secondary.opacity(0.10))
            GeometryReader { proxy in
                ZStack(alignment: .topLeading) {
                    Capsule()
                        .fill(LinearGradient(colors: [.green, .green.opacity(0.76)], startPoint: .top, endPoint: .bottom))
                    Capsule()
                        .fill(.white.opacity(0.28))
                        .frame(height: max(proxy.size.height * 0.22, 1))
                        .padding(.horizontal, 1)
                        .padding(.top, 1)
                }
                .frame(width: proxy.size.width * progress)
            }
            .clipShape(Capsule())
            HStack(spacing: 4) {
                Text(title).foregroundStyle(.secondary)
                Text(remainingText).fontWeight(.semibold)
                Text(resetAt.map { resetText($0) } ?? "").foregroundStyle(.secondary.opacity(0.75)).lineLimit(1)
            }
            .font(.subheadline)
            .padding(.horizontal, 8)
        }
        .frame(height: 22)
    }

    private var progress: CGFloat {
        CGFloat(min(max((remaining ?? 0) / 100, 0), 1))
    }

    private var remainingText: String {
        guard let remaining else { return localized("quota.no_data") }
        return "\(Int(remaining.rounded()))%"
    }
}

private struct PredictionPanel: View {
    let prediction: Prediction
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(localized("panel.planning"))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(prediction.headline)
                .font(.headline)
            Text(prediction.detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            HStack {
                Text(prediction.pace)
                Spacer()
                Text(prediction.burst)
                Spacer()
                Text(prediction.confidence)
            }
            .font(.footnote.weight(.semibold))
        }
        .padding(10)
        .background(.secondary.opacity(0.10), in: RoundedRectangle(cornerRadius: 9))
    }
}

private struct UsageChartPanel: View {
    let points: [UsageHistoryPoint]
    let currentUsed: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(localized("chart.title")).font(.headline)
                Spacer()
                Text("\(String(format: localized("chart.used"), Int(currentUsed.rounded()))) · \(String(format: localized("chart.points"), points.count))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            if points.count < 2 {
                VStack(spacing: 10) {
                    Image(systemName: "chart.xyaxis.line")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text(localized("chart.empty"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                    .frame(height: 220)
            } else {
                ChartCanvas(points: points, currentUsed: currentUsed)
                    .frame(height: 230)
            }
        }
        .padding(10)
        .background(.secondary.opacity(0.10), in: RoundedRectangle(cornerRadius: 9))
    }
}

private struct ChartCanvas: View {
    let points: [UsageHistoryPoint]
    let currentUsed: Double

    var body: some View {
        GeometryReader { proxy in
            let yAxisWidth: CGFloat = 42
            let rect = CGRect(
                x: yAxisWidth,
                y: 22,
                width: proxy.size.width - yAxisWidth - 8,
                height: proxy.size.height - 54
            )
            let first = points.first?.date.timeIntervalSince1970 ?? 0
            let last = points.last?.date.timeIntervalSince1970 ?? first + 60
            let span = max(60, last - first)
            let trendPoints = smoothedTrend(points: points, sampleCount: 56)
            let chartPoints = trendPoints.map { point in
                CGPoint(
                    x: rect.minX + rect.width * CGFloat((point.date.timeIntervalSince1970 - first) / span),
                    y: rect.maxY - rect.height * CGFloat(point.usedPercent / 100)
                )
            }
            Canvas { context, _ in
                context.draw(
                    Text(localized("chart.axis.used_percent"))
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(.secondary),
                    at: CGPoint(x: rect.minX, y: 2),
                    anchor: .topLeading
                )

                for index in 0...4 {
                    let y = rect.maxY - rect.height * CGFloat(index) / 4
                    let value = index * 25
                    var grid = Path()
                    grid.move(to: CGPoint(x: rect.minX, y: y))
                    grid.addLine(to: CGPoint(x: rect.maxX, y: y))
                    context.stroke(grid, with: .color(.secondary.opacity(0.28)), lineWidth: 1)
                    context.draw(
                        Text("\(value)%")
                            .font(.caption2.monospacedDigit())
                            .foregroundColor(.secondary),
                        at: CGPoint(x: rect.minX - 8, y: y),
                        anchor: .trailing
                    )
                }

                let line = smoothPath(points: chartPoints)
                context.stroke(line, with: .color(accentColor), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                if let latestPoint = points.last {
                    let latest = CGPoint(
                        x: rect.minX + rect.width * CGFloat((latestPoint.date.timeIntervalSince1970 - first) / span),
                        y: rect.maxY - rect.height * CGFloat(latestPoint.usedPercent / 100)
                    )
                    context.fill(Path(ellipseIn: CGRect(x: latest.x - 3, y: latest.y - 3, width: 6, height: 6)), with: .color(accentColor))
                    context.stroke(Path(ellipseIn: CGRect(x: latest.x - 5, y: latest.y - 5, width: 10, height: 10)), with: .color(accentColor.opacity(0.25)), lineWidth: 2)
                }
            }
            VStack {
                Spacer()
                HStack {
                    Text(shortDateTime(points.first!.date))
                        .padding(.leading, yAxisWidth)
                    Spacer()
                    Text(shortDateTime(points.last!.date))
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
        }
    }

    private func smoothedTrend(points: [UsageHistoryPoint], sampleCount: Int) -> [UsageHistoryPoint] {
        guard points.count > 2,
              let first = points.first,
              let last = points.last else { return points }

        let start = first.date.timeIntervalSince1970
        let end = last.date.timeIntervalSince1970
        let span = max(60, end - start)
        let sorted = points.sorted { $0.date < $1.date }
        let samples = max(12, sampleCount)

        return (0..<samples).map { index in
            let t = start + span * Double(index) / Double(samples - 1)
            let interpolated = interpolatedUsed(at: t, in: sorted)
            let softened = softenedUsed(around: t, base: interpolated, in: sorted, window: span / 8)
            return UsageHistoryPoint(
                date: Date(timeIntervalSince1970: t),
                usedPercent: softened,
                remainingPercent: clampPercent(100 - softened)
            )
        }
    }

    private func interpolatedUsed(at time: TimeInterval, in points: [UsageHistoryPoint]) -> Double {
        guard let first = points.first, let last = points.last else { return 0 }
        if time <= first.date.timeIntervalSince1970 { return first.usedPercent }
        if time >= last.date.timeIntervalSince1970 { return last.usedPercent }

        for index in 1..<points.count {
            let previous = points[index - 1]
            let next = points[index]
            let left = previous.date.timeIntervalSince1970
            let right = next.date.timeIntervalSince1970
            if time <= right {
                let span = max(1, right - left)
                let progress = (time - left) / span
                let eased = progress * progress * (3 - 2 * progress)
                return previous.usedPercent + (next.usedPercent - previous.usedPercent) * eased
            }
        }
        return last.usedPercent
    }

    private func softenedUsed(around time: TimeInterval, base: Double, in points: [UsageHistoryPoint], window: TimeInterval) -> Double {
        var weighted = base
        var weights = 1.0
        for point in points {
            let distance = abs(point.date.timeIntervalSince1970 - time)
            guard distance <= window else { continue }
            let weight = pow(1 - distance / max(window, 1), 2)
            weighted += point.usedPercent * weight
            weights += weight
        }
        return clampPercent(weighted / weights)
    }

    private func smoothPath(points: [CGPoint]) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)
        guard points.count > 1 else { return path }

        for index in 0..<(points.count - 1) {
            let previous = points[max(index - 1, 0)]
            let current = points[index]
            let next = points[index + 1]
            let following = points[min(index + 2, points.count - 1)]
            let smoothing: CGFloat = 0.18
            let cp1 = CGPoint(
                x: current.x + (next.x - previous.x) * smoothing,
                y: current.y + (next.y - previous.y) * smoothing
            )
            let cp2 = CGPoint(
                x: next.x - (following.x - current.x) * smoothing,
                y: next.y - (following.y - current.y) * smoothing
            )
            path.addCurve(to: next, control1: cp1, control2: cp2)
        }
        return path
    }

    private var accentColor: Color {
        if 100 - currentUsed > 55 { return .green }
        if 100 - currentUsed > 20 { return .orange }
        return .red
    }
}

private func runOnce() -> Int32 {
    let authStore = AuthStore()
    let usageClient = UsageClient()
    let resetCreditsClient = ResetCreditsClient()
    let historyStore = HistoryStore()
    let semaphore = DispatchSemaphore(value: 0)
    var exitCode: Int32 = 1
    Task {
        do {
            let auth = try authStore.readAuth()
            let result = try await usageClient.fetch(auth: auth)
            let resetCredits = await fetchResetCreditsSnapshot(client: resetCreditsClient, auth: auth)
            var snapshot = QuotaSnapshot()
            snapshot.primary = result.primary
            snapshot.secondary = result.secondary
            snapshot.resetCredits = resetCredits
            snapshot.plan = result.plan
            snapshot.authPath = auth.path.path
            snapshot.authMode = auth.authMode
            snapshot.accountId = auth.accountId
            snapshot.email = auth.email
            snapshot.authLastRefresh = auth.lastRefresh
            snapshot.lastUpdated = Date()
            snapshot.usedProxy = result.usedProxy
            let key = sha256String(auth.accountId ?? auth.email ?? "default")
            historyStore.append(snapshot, accountKey: key)
            snapshot.prediction = historyStore.prediction(snapshot: snapshot, accountKey: key)
            print("ok")
            print("plan: \(snapshot.plan ?? "-")")
            print("account: \(localized("account.default"))")
            print("primary: \(snapshot.primary?.label ?? "-") remaining \(Int((snapshot.primary?.remainingPercent ?? 0).rounded()))%")
            print("secondary: \(snapshot.secondary?.label ?? "-") remaining \(Int((snapshot.secondary?.remainingPercent ?? 0).rounded()))%")
            if let resetCreditsError = snapshot.resetCredits.errorMessage {
                print("reset_credits_error: \(resetCreditsError)")
            } else {
                print("reset_credits: available_count \(snapshot.resetCredits.availableCount)")
                for credit in snapshot.resetCredits.credits {
                    print("reset_credit: status \(credit.status) | title \(credit.title) | granted \(resetCreditLocalDateTime(credit.grantedAt)) | expires \(resetCreditLocalDateTime(credit.expiresAt))")
                }
            }
            print("forecast: \(snapshot.prediction.headline) | \(snapshot.prediction.pace) | \(snapshot.prediction.confidence) | samples \(snapshot.prediction.sampleCount)")
            print("history: \(historyStore.fileURL.path)")
            exitCode = 0
        } catch {
            fputs("error: \(error.localizedDescription)\n", stderr)
            exitCode = 1
        }
        semaphore.signal()
    }
    if semaphore.wait(timeout: .now() + 20) == .timedOut {
        fputs("error: usage check timed out\n", stderr)
        return 1
    }
    return exitCode
}

@MainActor
private final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        statusBarController = StatusBarController()
    }
}

@MainActor
private final class StatusBarController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()
    private let model = QuotaViewModel()
    private let launchAtLogin = LaunchAtLoginController()
    private var cancellables: Set<AnyCancellable> = []
    private var localMouseMonitor: Any?
    private var globalMouseMonitor: Any?

    override init() {
        super.init()
        configureStatusButton()
        configurePopover()
        bindStatusTitle()
    }

    private func configureStatusButton() {
        guard let button = statusItem.button else { return }
        button.target = self
        button.action = #selector(statusButtonClicked(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.image = NSImage(systemSymbolName: "terminal.fill", accessibilityDescription: localized("app.title"))
        button.image?.isTemplate = true
        button.imagePosition = .imageLeading
        button.font = NSFont.monospacedSystemFont(ofSize: 11.5, weight: .medium)
        updateStatusButton()
    }

    private func configurePopover() {
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = NSHostingController(
            rootView: QuotaMenuView()
                .environmentObject(model)
        )
    }

    private func bindStatusTitle() {
        model.$snapshot
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateStatusButton() }
            .store(in: &cancellables)
    }

    private func updateStatusButton() {
        statusItem.button?.title = " \(model.menuBarMeterTitle)"
    }

    @objc private func statusButtonClicked(_ sender: NSStatusBarButton) {
        switch NSApp.currentEvent?.type {
        case .rightMouseUp:
            showManagementMenu(anchor: sender)
        default:
            togglePopover(anchor: sender)
        }
    }

    private func togglePopover(anchor: NSStatusBarButton) {
        if popover.isShown {
            closePopover()
        } else {
            model.refresh()
            popover.show(relativeTo: anchor.bounds, of: anchor, preferredEdge: .minY)
            startPopoverDismissMonitors()
        }
    }

    private func showManagementMenu(anchor: NSStatusBarButton) {
        closePopover()
        launchAtLogin.refresh()

        let menu = NSMenu()
        let startupItem = NSMenuItem(
            title: startupMenuTitle,
            action: #selector(toggleLaunchAtLogin(_:)),
            keyEquivalent: ""
        )
        startupItem.target = self
        startupItem.state = launchAtLogin.isEnabled ? .on : .off
        menu.addItem(startupItem)
        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: localized("button.quit"),
            action: #selector(quit(_:)),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        menu.popUp(positioning: startupItem, at: NSPoint(x: 0, y: anchor.bounds.height + 4), in: anchor)
    }

    private var startupMenuTitle: String {
        switch launchAtLogin.status {
        case .requiresApproval:
            return localized("settings.startup_attention")
        default:
            return localized("settings.startup")
        }
    }

    @objc private func toggleLaunchAtLogin(_ sender: NSMenuItem) {
        let targetValue = !launchAtLogin.isEnabled
        _ = launchAtLogin.setEnabled(targetValue)
        showLaunchAtLoginMessageIfNeeded()
    }

    private func showLaunchAtLoginMessageIfNeeded() {
        switch launchAtLogin.status {
        case .requiresApproval, .notFound:
            let alert = NSAlert()
            alert.messageText = localized("settings.startup")
            alert.informativeText = launchAtLogin.detailText
            alert.alertStyle = .informational
            alert.runModal()
        default:
            break
        }
    }

    @objc private func quit(_ sender: NSMenuItem) {
        NSApplication.shared.terminate(nil)
    }

    private func closePopover() {
        popover.performClose(nil)
        stopPopoverDismissMonitors()
    }

    private func startPopoverDismissMonitors() {
        stopPopoverDismissMonitors()
        localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            self?.closePopoverIfClickIsOutside(event: event)
            return event
        }
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            Task { @MainActor in
                self?.closePopoverIfClickIsOutside(event: event)
            }
        }
    }

    private func stopPopoverDismissMonitors() {
        if let localMouseMonitor {
            NSEvent.removeMonitor(localMouseMonitor)
            self.localMouseMonitor = nil
        }
        if let globalMouseMonitor {
            NSEvent.removeMonitor(globalMouseMonitor)
            self.globalMouseMonitor = nil
        }
    }

    private func closePopoverIfClickIsOutside(event: NSEvent) {
        guard popover.isShown else {
            stopPopoverDismissMonitors()
            return
        }
        if eventHitsStatusButton(event) || eventHitsPopover(event) {
            return
        }
        closePopover()
    }

    private func eventHitsStatusButton(_ event: NSEvent) -> Bool {
        guard let button = statusItem.button, let window = button.window else { return false }
        if event.window === window {
            let point = button.convert(event.locationInWindow, from: nil)
            return button.bounds.contains(point)
        }
        let screenPoint = NSEvent.mouseLocation
        return window.frame.contains(screenPoint)
    }

    private func eventHitsPopover(_ event: NSEvent) -> Bool {
        guard let window = popover.contentViewController?.view.window else { return false }
        if event.window === window { return true }
        let screenPoint = NSEvent.mouseLocation
        return window.frame.contains(screenPoint)
    }
}

@main
@MainActor
private struct CodexQuotaBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        if CommandLine.arguments.contains("--once") {
            exit(runOnce())
        }
    }

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
