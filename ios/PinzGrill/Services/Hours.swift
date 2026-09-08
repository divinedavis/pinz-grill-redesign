import Foundation

/// Open/closed right now, computed from the weekly schedule ChowNow publishes
/// for a fulfillment mode. Done locally (not from `is_available_now`) so the
/// bundled snapshot gives the right answer offline and the tests are
/// deterministic.
enum OpenStatus: Equatable {
    case open(closesAt: Date)
    case closed(opensAt: Date?)

    static let timeZone = TimeZone(identifier: "America/New_York")!

    static func compute(_ days: [Restaurant.DisplayDay], now: Date = Date()) -> OpenStatus {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = timeZone
        var nextOpen: Date?
        for offset in 0...7 {
            guard let day = cal.date(byAdding: .day, value: offset, to: now) else { continue }
            let weekday = cal.component(.weekday, from: day)
            guard let schedule = days.first(where: { $0.day_id == weekday }) else { continue }
            for r in schedule.ranges {
                guard let start = cal.date(bySettingTime: r.from, of: day), var end = cal.date(bySettingTime: r.to, of: day) else { continue }
                if end <= start { end = cal.date(byAdding: .day, value: 1, to: end) ?? end }   // past-midnight range
                if start <= now && now < end { return .open(closesAt: end) }
                if start > now && (nextOpen == nil || start < nextOpen!) { nextOpen = start }
            }
            if let n = nextOpen, offset > 0 { return .closed(opensAt: n) }
        }
        return .closed(opensAt: nextOpen)
    }

    var isOpen: Bool { if case .open = self { return true } else { return false } }

    /// "Open · closes 9 PM" / "Closed · opens Mon 11 AM"
    func label(now: Date = Date()) -> String {
        switch self {
        case .open(let closes): return "Open · closes \(Self.clock(closes))"
        case .closed(let opens?): return "Closed · opens \(Self.dayWord(opens, now: now)) \(Self.clock(opens))"
        case .closed(nil): return "Closed"
        }
    }

    static func clock(_ d: Date) -> String {
        let f = DateFormatter(); f.timeZone = timeZone; f.locale = Locale(identifier: "en_US")
        var cal = Calendar(identifier: .gregorian); cal.timeZone = timeZone
        f.dateFormat = cal.component(.minute, from: d) == 0 ? "h a" : "h:mm a"
        return f.string(from: d)
    }

    static func dayWord(_ d: Date, now: Date) -> String {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = timeZone
        if cal.isDate(d, inSameDayAs: now) { return "today" }
        if let t = cal.date(byAdding: .day, value: 1, to: now), cal.isDate(d, inSameDayAs: t) { return "tomorrow" }
        let f = DateFormatter(); f.timeZone = timeZone; f.locale = Locale(identifier: "en_US"); f.dateFormat = "EEE"
        return f.string(from: d)
    }

    /// "11 AM – 9 PM" or "Closed" for a schedule row.
    static func rangeLabel(_ ranges: [Restaurant.TimeRange]) -> String {
        guard !ranges.isEmpty else { return "Closed" }
        return ranges.map { "\(clockString($0.from)) – \(clockString($0.to))" }.joined(separator: ", ")
    }

    static func clockString(_ hhmm: String) -> String {
        let parts = hhmm.split(separator: ":").compactMap { Int($0) }
        guard parts.count >= 2 else { return hhmm }
        let h = parts[0] % 24, m = parts[1]
        let h12 = h % 12 == 0 ? 12 : h % 12
        let suffix = h < 12 ? "AM" : "PM"
        return m == 0 ? "\(h12) \(suffix)" : String(format: "%d:%02d %@", h12, m, suffix)
    }
}

private extension Calendar {
    func date(bySettingTime hhmm: String, of day: Date) -> Date? {
        let parts = hhmm.split(separator: ":").compactMap { Int($0) }
        guard parts.count >= 2 else { return nil }
        return date(bySettingHour: parts[0], minute: parts[1], second: 0, of: day)
    }
}
