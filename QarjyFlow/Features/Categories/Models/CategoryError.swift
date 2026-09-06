import Foundation

enum CategoryError: LocalizedError {
    case emptyName, nameTooLong, invalidName, invalidSymbol, duplicateName, notFound, inUse

    var errorDescription: String? {
        switch self {
        case .emptyName: "Enter a category name."
        case .nameTooLong: "Use 60 characters or fewer for the category name."
        case .invalidName: "Use a single line without control characters for the name."
        case .invalidSymbol: "Choose an icon from the available options."
        case .duplicateName: "A category with this name and type already exists."
        case .inUse: "This category is used by a transaction or monthly plan, so it cannot be deleted or changed between income and expense."
        case .notFound: "This category no longer exists. Reload the category list."
        }
    }
}
