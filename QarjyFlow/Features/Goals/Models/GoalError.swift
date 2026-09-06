import Foundation

enum GoalError: LocalizedError {
    case invalidGoal, duplicateName, invalidContribution, notFound, inUse
    var errorDescription: String? {
        switch self {
        case .invalidGoal: "Enter a valid name and a positive target amount when required."
        case .duplicateName: "A goal with this name already exists."
        case .invalidContribution: "Enter a positive contribution with up to two decimal places."
        case .notFound: "This goal no longer exists."
        case .inUse: "This goal is used by a monthly Plan and cannot be deleted."
        }
    }
}
