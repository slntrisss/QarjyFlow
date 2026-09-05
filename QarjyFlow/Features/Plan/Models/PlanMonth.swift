import Foundation

struct PlanMonth: Hashable, Codable, Sendable {
    let year: Int
    let month: Int

    init(year: Int, month: Int) {
        precondition((1...12).contains(month))
        self.year = year
        self.month = month
    }

    init(date: Date = Date(), calendar: Calendar = .current) {
        year = calendar.component(.year, from: date)
        month = calendar.component(.month, from: date)
    }

    var key: String { String(format: "%04d-%02d", year, month) }

    var title: String {
        var components = DateComponents(); components.year = year; components.month = month; components.day = 1
        guard let date = Calendar(identifier: .gregorian).date(from: components) else { return key }
        return date.formatted(.dateTime.month(.wide).year())
    }
}
