struct SwiftDataHomeStore: HomeStore {
    let database: LedgerDatabase
    func fetch(month: PlanMonth) async throws -> HomeDataSnapshot {
        try await database.fetchHomeData(month: month)
    }
}
