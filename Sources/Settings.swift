import Foundation

struct ProbeWindow: Codable, Equatable {
    var start: String  // "HH:mm"
    var end: String    // "HH:mm"
}

/// 全部持久化设置（UserDefaults）
enum Settings {
    private static let d = UserDefaults.standard
    private static let urlKey = "webview_url"
    private static let secretKey = "authSecret"
    private static let intervalKey = "probe_interval_seconds"
    private static let windowsKey = "probe_windows"
    private static let secondsKey = "clock_show_seconds"
    private static let h24Key = "clock_24h"
    private static let dateKey = "clock_show_date"

    // MARK: 相框

    static var serverURL: String? {
        let t = (d.string(forKey: urlKey) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }

    static var authSecret: String? {
        let t = (d.string(forKey: secretKey) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }

    static func save(url: String, secret: String) {
        var trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = trimmed.lowercased()
        if !trimmed.isEmpty && !lower.hasPrefix("http://") && !lower.hasPrefix("https://") {
            trimmed = "http://" + trimmed
        }
        d.set(trimmed, forKey: urlKey)
        d.set(secret.trimmingCharacters(in: .whitespacesAndNewlines), forKey: secretKey)
    }

    /// 安卓版行为：地址后追加 ?authsecret=xxx
    static func authenticatedURL() -> URL? {
        guard var urlString = serverURL else { return nil }
        if let secret = authSecret, var components = URLComponents(string: urlString) {
            var items = components.queryItems ?? []
            items.append(URLQueryItem(name: "authsecret", value: secret))
            components.queryItems = items
            if let withAuth = components.url?.absoluteString {
                urlString = withAuth
            }
        }
        return URL(string: urlString)
    }

    // MARK: 自动切换

    /// 探测间隔（秒），默认 60
    static var probeInterval: Int {
        d.object(forKey: intervalKey) == nil ? 60 : max(15, d.integer(forKey: intervalKey))
    }

    static var probeWindows: [ProbeWindow] {
        guard let data = d.data(forKey: windowsKey) else { return [] }
        return (try? JSONDecoder().decode([ProbeWindow].self, from: data)) ?? []
    }

    static func save(interval seconds: Int) {
        d.set(max(15, seconds), forKey: intervalKey)
    }

    static func save(windows: [ProbeWindow]) {
        if let data = try? JSONEncoder().encode(windows) {
            d.set(data, forKey: windowsKey)
        }
    }

    /// 首次启动给一个默认时段：07:00–23:00
    static func ensureDefaults() {
        if d.object(forKey: windowsKey) == nil {
            save(windows: [ProbeWindow(start: "07:00", end: "23:00")])
        }
    }

    /// "HH:mm" -> 分钟数，非法返回 nil
    static func minutes(_ s: String) -> Int? {
        let parts = s.split(separator: ":")
        guard parts.count == 2,
              let h = Int(parts[0]), let m = Int(parts[1]),
              (0...23).contains(h), (0...59).contains(m) else { return nil }
        return h * 60 + m
    }

    /// 是否处于探测时段；空列表 = 全天探测。支持跨午夜（start > end）。
    static func isWithinProbeWindow(now: Date = Date()) -> Bool {
        let wins = probeWindows
        if wins.isEmpty { return true }
        let comp = Calendar.current.dateComponents([.hour, .minute], from: now)
        let cur = (comp.hour ?? 0) * 60 + (comp.minute ?? 0)
        for w in wins {
            guard let s = minutes(w.start), let e = minutes(w.end) else { continue }
            if s < e {
                if cur >= s && cur < e { return true }
            } else if s > e {
                if cur >= s || cur < e { return true }
            } else {
                return true  // start == end 视为全天
            }
        }
        return false
    }

    // MARK: 时钟外观

    static var showSeconds: Bool { d.bool(forKey: secondsKey) }
    static var use24Hour: Bool { d.object(forKey: h24Key) == nil ? true : d.bool(forKey: h24Key) }
    static var showDate: Bool { d.object(forKey: dateKey) == nil ? true : d.bool(forKey: dateKey) }

    static func save(showSeconds: Bool) { d.set(showSeconds, forKey: secondsKey) }
    static func save(use24Hour: Bool) { d.set(use24Hour, forKey: h24Key) }
    static func save(showDate: Bool) { d.set(showDate, forKey: dateKey) }
}
