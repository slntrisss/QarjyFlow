import SwiftUI

extension CategoryColor {
    var tint: Color {
        switch self {
        case .green: .green
        case .blue: .blue
        case .orange: .orange
        case .pink: .pink
        case .purple: .purple
        case .teal: .teal
        }
    }
}
