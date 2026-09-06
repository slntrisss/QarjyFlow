import Foundation
import os

/// Central place for diagnostics. Every `catch` that maps a real error to a
/// generic user string should first log the underlying error here, so field
/// failures (store open, save, load) are actually investigable.
///
/// Financial values must never be logged at `.public`; log identifiers and
/// error descriptions only.
enum AppLog {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "QarjyFlow"

    static let app = Logger(subsystem: subsystem, category: "app")
    static let persistence = Logger(subsystem: subsystem, category: "persistence")
    static let categories = Logger(subsystem: subsystem, category: "categories")
    static let transactions = Logger(subsystem: subsystem, category: "transactions")
    static let plan = Logger(subsystem: subsystem, category: "plan")
}
