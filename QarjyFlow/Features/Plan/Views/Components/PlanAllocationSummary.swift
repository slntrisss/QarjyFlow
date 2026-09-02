import SwiftUI

struct PlanAllocationSummary: View {
    let income: Decimal
    let allocated: Decimal
    private var remaining: Decimal { income - allocated }
    private var progress: Double {
        guard income > 0 else { return 0 }
        return min(max(NSDecimalNumber(decimal: allocated / income).doubleValue, 0), 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top) { allocatedLabel; Spacer(minLength: 20); remainingLabel }
                VStack(alignment: .leading, spacing: 16) { allocatedLabel; remainingLabel }
            }
            ProgressView(value: progress).tint(remaining < 0 ? .red : .green)
                .accessibilityLabel("Share of expected income allocated")
            Text(remaining < 0
                 ? "Allocations exceed expected income. Adjust this sample to explore the difference."
                 : "You don’t need to allocate every tenge. Unallocated is not an account balance.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .cardStyle()
    }

    private var allocatedLabel: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Allocated").font(.caption).foregroundStyle(.secondary)
            Text(allocated.tenge).font(.headline)
        }
    }

    private var remainingLabel: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(remaining < 0 ? "Over-allocated" : "Unallocated").font(.caption).foregroundStyle(.secondary)
            Text(abs(remaining).tenge).font(.headline).foregroundStyle(remaining < 0 ? .red : .green)
        }
    }
}

#Preview("Plan summary · room to allocate", traits: .sizeThatFitsLayout) {
    PlanAllocationSummary(income: 800_000, allocated: 770_000).padding()
}

#Preview("Plan summary · over-allocated", traits: .sizeThatFitsLayout) {
    PlanAllocationSummary(income: 800_000, allocated: 850_000).padding()
}
