import Foundation
import SwiftData

enum AppDatabase {
    static var schema: Schema {
        Schema([
            CategoryRecord.self, TransactionRecord.self, MonthlyPlanRecord.self,
            PlannedIncomeRecord.self, PlanGroupRecord.self, PlanAllocationRecord.self
        ])
    }

    static func makeContainer(inMemory: Bool = false, url: URL? = nil) throws -> ModelContainer {
        let schema = schema
        let configuration: ModelConfiguration
        if let url {
            configuration = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
        } else {
            configuration = ModelConfiguration(
                schema: schema, isStoredInMemoryOnly: inMemory, cloudKitDatabase: .none
            )
        }
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
