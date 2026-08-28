import SwiftUI

struct MonthProgressSection: View {
    let fraction: Double
    let caption: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your progress").font(.headline)
            ProgressView(value: fraction).tint(.green)
            Text(caption)
                .font(.caption).foregroundStyle(.secondary)
        }.cardStyle()
    }
}

#Preview("Month progress · halfway", traits: .sizeThatFitsLayout) {
    MonthProgressSection(
        fraction: 0.55,
        caption: "55% of the month gone · sample date: August 17"
    )
    .padding(20)
    .background(Color(uiColor: .systemGroupedBackground))
}
