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

enum LedgerSchemaV2: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(2, 0, 0) }
    static var models: [any PersistentModel.Type] {
        LedgerSchemaV1.models + [FinancialGoalRecord.self, GoalContributionRecord.self,
                                 PlanGoalLinkRecord.self]
    }
}

/// Explicit plan so the first non-additive schema change has a home instead of
/// silently relying on lightweight inference (which only covers additive edits).
enum LedgerMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [LedgerSchemaV1.self, LedgerSchemaV2.self] }
    static var stages: [MigrationStage] { [.lightweight(fromVersion: LedgerSchemaV1.self,
                                                        toVersion: LedgerSchemaV2.self)] }
}

enum AppDatabase {
    static var schema: Schema { Schema(versionedSchema: LedgerSchemaV2.self) }

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
        do {
            return try ModelContainer(
                for: schema, migrationPlan: LedgerMigrationPlan.self, configurations: [configuration]
            )
        } catch {
            // Early prototype builds wrote an unversioned category-only store. A staged
            // plan cannot identify it, but this additive model can still migrate it.
            // If that also fails, propagate the real storage failure to the caller.
            return try ModelContainer(for: schema, configurations: [configuration])
        }
    }
}
