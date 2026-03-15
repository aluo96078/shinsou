import CloudKit
import ShinsouDomain

/// CloudKit Record Type 名稱常數。
enum CKRecordType {
    static let syncManga    = "SyncManga"
    static let syncChapter  = "SyncChapter"
    static let syncCategory = "SyncCategory"
    static let syncTrack    = "SyncTrack"
    static let syncHistory  = "SyncHistory"
}

/// 負責 Domain Model ↔ CKRecord 的雙向轉換。
/// 只同步使用者操作的欄位，不同步來源提供的元資料。
enum CloudKitRecordMapper {

    // MARK: - Record ID 產生

    /// 為 Manga 產生穩定的 Record ID（基於 source + url 的 hash）。
    static func recordID(for manga: Manga) -> CKRecord.ID {
        let key = "manga-\(manga.source)-\(manga.url)".stableHash
        return CKRecord.ID(recordName: key, zoneID: CloudKitZoneManager.shared.zoneID)
    }

    /// 為 Chapter 產生穩定的 Record ID（基於 mangaKey + chapter url）。
    static func recordID(forChapter chapter: Chapter, mangaSource: Int64, mangaUrl: String) -> CKRecord.ID {
        let key = "chapter-\(mangaSource)-\(mangaUrl)-\(chapter.url)".stableHash
        return CKRecord.ID(recordName: key, zoneID: CloudKitZoneManager.shared.zoneID)
    }

    /// 為 Category 產生穩定的 Record ID。
    static func recordID(for category: ShinsouDomain.Category) -> CKRecord.ID {
        let key = "category-\(category.name)".stableHash
        return CKRecord.ID(recordName: key, zoneID: CloudKitZoneManager.shared.zoneID)
    }

    /// 為 Track 產生穩定的 Record ID。
    static func recordID(forTrack track: Track, mangaSource: Int64, mangaUrl: String) -> CKRecord.ID {
        let key = "track-\(mangaSource)-\(mangaUrl)-\(track.trackerId)".stableHash
        return CKRecord.ID(recordName: key, zoneID: CloudKitZoneManager.shared.zoneID)
    }

    /// 為 History 產生穩定的 Record ID。
    static func recordID(forHistory chapterId: Int64, mangaSource: Int64, mangaUrl: String, chapterUrl: String) -> CKRecord.ID {
        let key = "history-\(mangaSource)-\(mangaUrl)-\(chapterUrl)".stableHash
        return CKRecord.ID(recordName: key, zoneID: CloudKitZoneManager.shared.zoneID)
    }

    // MARK: - Manga → CKRecord

    static func record(from manga: Manga) -> CKRecord {
        let record = CKRecord(recordType: CKRecordType.syncManga, recordID: recordID(for: manga))
        record["source"] = manga.source as CKRecordValue
        record["url"] = manga.url as CKRecordValue
        record["title"] = manga.title as CKRecordValue
        record["favorite"] = (manga.favorite ? 1 : 0) as CKRecordValue
        record["viewerFlags"] = manga.viewerFlags as CKRecordValue
        record["chapterFlags"] = manga.chapterFlags as CKRecordValue
        record["notes"] = manga.notes as CKRecordValue
        record["lastModifiedAt"] = manga.lastModifiedAt as CKRecordValue
        record["dateAdded"] = manga.dateAdded as CKRecordValue
        return record
    }

    // MARK: - CKRecord → Manga Partial Update

    struct MangaSyncFields {
        let source: Int64
        let url: String
        let title: String
        let favorite: Bool
        let viewerFlags: Int64
        let chapterFlags: Int64
        let notes: String
        let lastModifiedAt: Int64
        let dateAdded: Int64
    }

    static func mangaSyncFields(from record: CKRecord) -> MangaSyncFields? {
        guard let source = record["source"] as? Int64,
              let url = record["url"] as? String,
              let title = record["title"] as? String else { return nil }

        return MangaSyncFields(
            source: source,
            url: url,
            title: title,
            favorite: (record["favorite"] as? Int64 ?? 0) != 0,
            viewerFlags: record["viewerFlags"] as? Int64 ?? 0,
            chapterFlags: record["chapterFlags"] as? Int64 ?? 0,
            notes: record["notes"] as? String ?? "",
            lastModifiedAt: record["lastModifiedAt"] as? Int64 ?? 0,
            dateAdded: record["dateAdded"] as? Int64 ?? 0
        )
    }

    // MARK: - Chapter → CKRecord

    static func record(from chapter: Chapter, mangaSource: Int64, mangaUrl: String) -> CKRecord {
        let recordID = recordID(forChapter: chapter, mangaSource: mangaSource, mangaUrl: mangaUrl)
        let record = CKRecord(recordType: CKRecordType.syncChapter, recordID: recordID)
        record["mangaSource"] = mangaSource as CKRecordValue
        record["mangaUrl"] = mangaUrl as CKRecordValue
        record["chapterUrl"] = chapter.url as CKRecordValue
        record["read"] = (chapter.read ? 1 : 0) as CKRecordValue
        record["bookmark"] = (chapter.bookmark ? 1 : 0) as CKRecordValue
        record["lastPageRead"] = chapter.lastPageRead as CKRecordValue
        record["lastModifiedAt"] = chapter.lastModifiedAt as CKRecordValue
        return record
    }

    struct ChapterSyncFields {
        let mangaSource: Int64
        let mangaUrl: String
        let chapterUrl: String
        let read: Bool
        let bookmark: Bool
        let lastPageRead: Int
        let lastModifiedAt: Int64
    }

    static func chapterSyncFields(from record: CKRecord) -> ChapterSyncFields? {
        guard let mangaSource = record["mangaSource"] as? Int64,
              let mangaUrl = record["mangaUrl"] as? String,
              let chapterUrl = record["chapterUrl"] as? String else { return nil }

        return ChapterSyncFields(
            mangaSource: mangaSource,
            mangaUrl: mangaUrl,
            chapterUrl: chapterUrl,
            read: (record["read"] as? Int64 ?? 0) != 0,
            bookmark: (record["bookmark"] as? Int64 ?? 0) != 0,
            lastPageRead: record["lastPageRead"] as? Int ?? 0,
            lastModifiedAt: record["lastModifiedAt"] as? Int64 ?? 0
        )
    }

    // MARK: - Category → CKRecord

    static func record(from category: ShinsouDomain.Category) -> CKRecord {
        let record = CKRecord(recordType: CKRecordType.syncCategory, recordID: recordID(for: category))
        record["name"] = category.name as CKRecordValue
        record["sort"] = category.sort as CKRecordValue
        record["flags"] = category.flags as CKRecordValue
        return record
    }

    struct CategorySyncFields {
        let name: String
        let sort: Int
        let flags: Int64
    }

    static func categorySyncFields(from record: CKRecord) -> CategorySyncFields? {
        guard let name = record["name"] as? String else { return nil }
        return CategorySyncFields(
            name: name,
            sort: record["sort"] as? Int ?? 0,
            flags: record["flags"] as? Int64 ?? 0
        )
    }

    // MARK: - Track → CKRecord

    static func record(from track: Track, mangaSource: Int64, mangaUrl: String) -> CKRecord {
        let recordID = recordID(forTrack: track, mangaSource: mangaSource, mangaUrl: mangaUrl)
        let record = CKRecord(recordType: CKRecordType.syncTrack, recordID: recordID)
        record["mangaSource"] = mangaSource as CKRecordValue
        record["mangaUrl"] = mangaUrl as CKRecordValue
        record["trackerId"] = track.trackerId as CKRecordValue
        record["remoteId"] = track.remoteId as CKRecordValue
        record["title"] = track.title as CKRecordValue
        record["lastChapterRead"] = track.lastChapterRead as CKRecordValue
        record["totalChapters"] = track.totalChapters as CKRecordValue
        record["status"] = track.status as CKRecordValue
        record["score"] = track.score as CKRecordValue
        record["remoteUrl"] = track.remoteUrl as CKRecordValue
        record["startDate"] = track.startDate as CKRecordValue
        record["finishDate"] = track.finishDate as CKRecordValue
        return record
    }

    struct TrackSyncFields {
        let mangaSource: Int64
        let mangaUrl: String
        let trackerId: Int
        let remoteId: Int64
        let title: String
        let lastChapterRead: Double
        let totalChapters: Int
        let status: Int
        let score: Double
        let remoteUrl: String
        let startDate: Int64
        let finishDate: Int64
    }

    static func trackSyncFields(from record: CKRecord) -> TrackSyncFields? {
        guard let mangaSource = record["mangaSource"] as? Int64,
              let mangaUrl = record["mangaUrl"] as? String,
              let trackerId = record["trackerId"] as? Int else { return nil }

        return TrackSyncFields(
            mangaSource: mangaSource,
            mangaUrl: mangaUrl,
            trackerId: trackerId,
            remoteId: record["remoteId"] as? Int64 ?? 0,
            title: record["title"] as? String ?? "",
            lastChapterRead: record["lastChapterRead"] as? Double ?? 0,
            totalChapters: record["totalChapters"] as? Int ?? 0,
            status: record["status"] as? Int ?? 0,
            score: record["score"] as? Double ?? 0,
            remoteUrl: record["remoteUrl"] as? String ?? "",
            startDate: record["startDate"] as? Int64 ?? 0,
            finishDate: record["finishDate"] as? Int64 ?? 0
        )
    }

    // MARK: - History → CKRecord

    static func historyRecord(chapterId: Int64, lastRead: Int64, mangaSource: Int64, mangaUrl: String, chapterUrl: String) -> CKRecord {
        let recordID = recordID(forHistory: chapterId, mangaSource: mangaSource, mangaUrl: mangaUrl, chapterUrl: chapterUrl)
        let record = CKRecord(recordType: CKRecordType.syncHistory, recordID: recordID)
        record["mangaSource"] = mangaSource as CKRecordValue
        record["mangaUrl"] = mangaUrl as CKRecordValue
        record["chapterUrl"] = chapterUrl as CKRecordValue
        record["lastRead"] = lastRead as CKRecordValue
        return record
    }

    struct HistorySyncFields {
        let mangaSource: Int64
        let mangaUrl: String
        let chapterUrl: String
        let lastRead: Int64
    }

    static func historySyncFields(from record: CKRecord) -> HistorySyncFields? {
        guard let mangaSource = record["mangaSource"] as? Int64,
              let mangaUrl = record["mangaUrl"] as? String,
              let chapterUrl = record["chapterUrl"] as? String else { return nil }

        return HistorySyncFields(
            mangaSource: mangaSource,
            mangaUrl: mangaUrl,
            chapterUrl: chapterUrl,
            lastRead: record["lastRead"] as? Int64 ?? 0
        )
    }
}

// MARK: - String Hash Helper

extension String {
    /// 產生穩定的 hash 字串（djb2 的 64-bit hex）。
    var stableHash: String {
        var hash: UInt64 = 5381
        for byte in self.utf8 {
            hash = ((hash &<< 5) &+ hash) &+ UInt64(byte)
        }
        return String(format: "%016llx", hash)
    }
}
