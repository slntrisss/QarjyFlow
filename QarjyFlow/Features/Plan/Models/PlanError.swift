import Foundation

enum PlanError: LocalizedError {
    case invalidPlan
    case duplicateMonth
    case categoryUnavailable

    var errorDescription: String? {
        switch self {
        case .invalidPlan: "This plan contains invalid or inconsistent data."
        case .duplicateMonth: "A plan for this month already exists."
        case .categoryUnavailable: "One of the selected categories is unavailable or is not an expense category."
        }
    }
}
