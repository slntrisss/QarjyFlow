import SwiftUI

struct AnalyticsMetricCard: View {
    let title: String
    let value: String
    let subtitle: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.title3.bold()).foregroundStyle(color)
                .lineLimit(1).minimumScaleFactor(0.7)
            Text(subtitle).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
        .cardStyle()
    }
}

#Preview("Analytics metric", traits: .sizeThatFitsLayout) {
    AnalyticsMetricCard(title: "Savings rate", value: "25%", subtitle: "of recorded income", color: .green)
        .padding()
}
