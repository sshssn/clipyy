import Foundation

enum DateGroup: Hashable, Comparable {
    case today
    case yesterday
    case thisWeek
    case older(Date)

    var title: String {
        switch self {
        case .today:      return "Today"
        case .yesterday:  return "Yesterday"
        case .thisWeek:   return "This Week"
        case .older(let date):
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return formatter.string(from: date)
        }
    }

    static func < (lhs: DateGroup, rhs: DateGroup) -> Bool {
        func rank(_ g: DateGroup) -> Int {
            switch g {
            case .today: return 0
            case .yesterday: return 1
            case .thisWeek: return 2
            case .older: return 3
            }
        }
        let lr = rank(lhs), rr = rank(rhs)
        if lr != rr { return lr < rr }
        if case .older(let ld) = lhs, case .older(let rd) = rhs {
            return ld > rd
        }
        return false
    }

    static func from(date: Date) -> DateGroup {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return .today }
        if calendar.isDateInYesterday(date) { return .yesterday }
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        if date > weekAgo { return .thisWeek }
        return .older(calendar.startOfDay(for: date))
    }
}

extension Date {
    /// Static relative time string (e.g. "just now", "3m", "2h", "5d")
    var shortRelative: String {
        let seconds = Int(Date().timeIntervalSince(self))
        if seconds < 60 { return "just now" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes)m" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours)h" }
        let days = hours / 24
        if days < 30 { return "\(days)d" }
        let months = days / 30
        return "\(months)mo"
    }
}

extension Array where Element == ClipboardItem {
    func groupedByDate() -> [(group: DateGroup, items: [ClipboardItem])] {
        let grouped = Dictionary(grouping: self) { DateGroup.from(date: $0.createdAt) }
        return grouped
            .sorted { $0.key < $1.key }
            .map { (group: $0.key, items: $0.value.sorted { $0.createdAt > $1.createdAt }) }
    }
}
