import Foundation
import SwiftData

/// The first released schema. Add `LedgerSchemaV2`, etc. as models change, and a
/// `MigrationStage` per hop in `LedgerMigrationPlan`. Never mutate a shipped version.
enum LedgerSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [
            CategoryRecord.self, TransactionRecord.self, MonthlyPlanRecord.self,
            PlannedIncomeRecord.self, PlanGroupRecord.self, PlanAllocationRecord.self
        ]
    }
}

/// Explicit plan so the first non-additive schema change has a home instead of
/// silently relying on lightweight inference (which only covers additive edits).
enum LedgerMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [LedgerSchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}

enum AppDatabase {
    static var schema: Schema { Schema(versionedSchema: LedgerSchemaV1.self) }

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
        return try ModelContainer(
            for: schema, migrationPlan: LedgerMigrationPlan.self, configurations: [configuration]
        )
    }
}
