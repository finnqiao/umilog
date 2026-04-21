import Foundation
import GRDB

public final class SiteFacetRepository {
    private let database: AppDatabase

    public init(database: AppDatabase) {
        self.database = database
    }

    public func fetchEntryModes(siteId: String) throws -> [String] {
        try database.read { db in
            guard let raw: String = try String.fetchOne(
                db,
                sql: "SELECT entry_modes FROM site_facets WHERE site_id = ?",
                arguments: [siteId]
            ) else {
                return []
            }
            guard let data = raw.data(using: .utf8),
                  let decoded = try? JSONDecoder().decode([String].self, from: data) else {
                return []
            }
            return decoded
        }
    }
}
