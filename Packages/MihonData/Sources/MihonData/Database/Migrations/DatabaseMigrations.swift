import Foundation
import GRDB

enum DatabaseMigrations {
    static func v1Initial(_ db: Database) throws {
        // manga table
        try db.create(table: "manga") { t in
            t.autoIncrementedPrimaryKey("id")
            t.column("source", .integer).notNull()
            t.column("url", .text).notNull()
            t.column("title", .text).notNull()
            t.column("artist", .text)
            t.column("author", .text)
            t.column("description", .text)
            t.column("genre", .text) // JSON array
            t.column("status", .integer).notNull().defaults(to: 0)
            t.column("thumbnail_url", .text)
            t.column("favorite", .boolean).notNull().defaults(to: false)
            t.column("last_update", .integer).notNull().defaults(to: 0)
            t.column("next_update", .integer).notNull().defaults(to: 0)
            t.column("fetch_interval", .integer).notNull().defaults(to: 0)
            t.column("date_added", .integer).notNull().defaults(to: 0)
            t.column("viewer_flags", .integer).notNull().defaults(to: 0)
            t.column("chapter_flags", .integer).notNull().defaults(to: 0)
            t.column("cover_last_modified", .integer).notNull().defaults(to: 0)
            t.column("update_strategy", .integer).notNull().defaults(to: 0)
            t.column("initialized", .boolean).notNull().defaults(to: false)
            t.column("last_modified_at", .integer).notNull().defaults(to: 0)
            t.column("favorite_modified_at", .integer)
            t.column("version", .integer).notNull().defaults(to: 0)
            t.column("notes", .text).notNull().defaults(to: "")
        }
        try db.create(index: "idx_manga_favorite", on: "manga", columns: ["favorite"])
        try db.create(index: "idx_manga_url", on: "manga", columns: ["url"])
        try db.create(index: "idx_manga_source", on: "manga", columns: ["source"])

        // chapter table
        try db.create(table: "chapter") { t in
            t.autoIncrementedPrimaryKey("id")
            t.column("manga_id", .integer).notNull()
                .references("manga", onDelete: .cascade)
            t.column("url", .text).notNull()
            t.column("name", .text).notNull()
            t.column("scanlator", .text)
            t.column("read", .boolean).notNull().defaults(to: false)
            t.column("bookmark", .boolean).notNull().defaults(to: false)
            t.column("last_page_read", .integer).notNull().defaults(to: 0)
            t.column("chapter_number", .double).notNull().defaults(to: -1)
            t.column("source_order", .integer).notNull().defaults(to: 0)
            t.column("date_fetch", .integer).notNull().defaults(to: 0)
            t.column("date_upload", .integer).notNull().defaults(to: 0)
            t.column("last_modified_at", .integer).notNull().defaults(to: 0)
            t.column("version", .integer).notNull().defaults(to: 1)
        }
        try db.create(index: "idx_chapter_manga_id", on: "chapter", columns: ["manga_id"])
        try db.create(index: "idx_chapter_url", on: "chapter", columns: ["url"])

        // category table
        try db.create(table: "category") { t in
            t.autoIncrementedPrimaryKey("id")
            t.column("name", .text).notNull()
            t.column("sort", .integer).notNull().defaults(to: 0)
            t.column("flags", .integer).notNull().defaults(to: 0)
        }

        // manga_category join table
        try db.create(table: "manga_category") { t in
            t.column("manga_id", .integer).notNull()
                .references("manga", onDelete: .cascade)
            t.column("category_id", .integer).notNull()
                .references("category", onDelete: .cascade)
            t.primaryKey(["manga_id", "category_id"])
        }

        // track table
        try db.create(table: "track") { t in
            t.autoIncrementedPrimaryKey("id")
            t.column("manga_id", .integer).notNull()
                .references("manga", onDelete: .cascade)
            t.column("tracker_id", .integer).notNull()
            t.column("remote_id", .integer).notNull().defaults(to: 0)
            t.column("title", .text).notNull().defaults(to: "")
            t.column("last_chapter_read", .double).notNull().defaults(to: 0)
            t.column("total_chapters", .integer).notNull().defaults(to: 0)
            t.column("status", .integer).notNull().defaults(to: 0)
            t.column("score", .double).notNull().defaults(to: 0)
            t.column("remote_url", .text).notNull().defaults(to: "")
            t.column("start_date", .integer).notNull().defaults(to: 0)
            t.column("finish_date", .integer).notNull().defaults(to: 0)
        }

        // history table
        try db.create(table: "history") { t in
            t.autoIncrementedPrimaryKey("id")
            t.column("chapter_id", .integer).notNull().unique()
                .references("chapter", onDelete: .cascade)
            t.column("last_read", .integer).notNull().defaults(to: 0)
            t.column("time_read", .integer).notNull().defaults(to: 0)
        }

        // source table
        try db.create(table: "source") { t in
            t.primaryKey("source_id", .integer)
            t.column("lang", .text).notNull().defaults(to: "")
            t.column("name", .text).notNull().defaults(to: "")
        }

        // extension_repo table
        try db.create(table: "extension_repo") { t in
            t.primaryKey("base_url", .text)
            t.column("name", .text).notNull()
            t.column("short_name", .text)
            t.column("website", .text).notNull()
            t.column("signing_key_fingerprint", .text).notNull()
        }

        // excluded_scanlator table
        try db.create(table: "excluded_scanlator") { t in
            t.column("manga_id", .integer).notNull()
                .references("manga", onDelete: .cascade)
            t.column("scanlator", .text).notNull()
            t.primaryKey(["manga_id", "scanlator"])
        }
    }
}
