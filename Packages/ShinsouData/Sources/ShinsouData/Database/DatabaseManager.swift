import Foundation
import GRDB
import ShinsouCore

public final class DatabaseManager: Sendable {
    public let dbPool: DatabasePool

    public init(path: String? = nil) throws {
        // 資料庫檔名從 mihon.db 改為 shinsou.db，自動遷移舊檔案
        Self.migrateOldDatabaseFileIfNeeded()

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

    /// 將舊的 mihon.db 自動 rename 為 shinsou.db
    private static func migrateOldDatabaseFileIfNeeded() {
        let docs = DiskUtil.documentsDirectory
        let oldPath = docs.appendingPathComponent("mihon.db").path
        let newPath = docs.appendingPathComponent(AppConstants.databaseFileName).path
        let fm = FileManager.default
        if fm.fileExists(atPath: oldPath) && !fm.fileExists(atPath: newPath) {
            try? fm.moveItem(atPath: oldPath, toPath: newPath)
            // 同時遷移 WAL / SHM
            for suffix in ["-wal", "-shm"] {
                let old = oldPath + suffix
                let new = newPath + suffix
                if fm.fileExists(atPath: old) {
                    try? fm.moveItem(atPath: old, toPath: new)
                }
            }
        }
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
