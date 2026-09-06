import Foundation

enum TransactionDateFilter: String, CaseIterable, Identifiable, Sendable {
    case last7Days
    case lastMonth
    case specifiedPeriod

    var id: String { rawValue }
    var title: String {
        switch self {
        case .last7Days: "Last 7 days"
        case .lastMonth: "Last month"
        case .specifiedPeriod: "Specified period"
        }
    }

    func includes(_ date: Date, from: Date, to: Date,
                  now: Date = Date(), calendar: Calendar = .current) -> Bool {
        switch self {
        case .last7Days:
            guard let start = calendar.date(byAdding: .day, value: -7,
                                             to: calendar.startOfDay(for: now)) else {
                return false
            }
            return date >= start && date <= now
        case .lastMonth:
            guard let start = calendar.date(byAdding: .month, value: -1,
                                             to: calendar.startOfDay(for: now)) else {
                return false
            }
            return date >= start && date <= now
        case .specifiedPeriod:
            let start = calendar.startOfDay(for: min(from, to))
            guard let end = calendar.date(byAdding: .day, value: 1,
                                          to: calendar.startOfDay(for: max(from, to))) else { return false }
            return date >= start && date < end
        }
    }
}
