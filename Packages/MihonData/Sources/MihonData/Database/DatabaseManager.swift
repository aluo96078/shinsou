import Foundation
import GRDB
import MihonCore

public final class DatabaseManager: Sendable {
    public let dbPool: DatabasePool

    public init(path: String? = nil) throws {
        let dbPath = path ?? DiskUtil.documentsDirectory
            .appendingPathComponent(AppConstants.databaseFileName).path

        var config = Configuration()
        config.foreignKeysEnabled = true
        config.prepareDatabase { db in
            // These PRAGMAs run outside any transaction, on each new connection
            try db.execute(sql: "PRAGMA synchronous = NORMAL")
            #if DEBUG
            db.trace { print("SQL: \($0)") }
            #endif
        }

        dbPool = try DatabasePool(path: dbPath, configuration: config)

        try migrator.migrate(dbPool)
    }

    private var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()

        #if DEBUG
        migrator.eraseDatabaseOnSchemaChange = true
        #endif

        migrator.registerMigration("v1_initial") { db in
            try DatabaseMigrations.v1Initial(db)
        }

        return migrator
    }
}
