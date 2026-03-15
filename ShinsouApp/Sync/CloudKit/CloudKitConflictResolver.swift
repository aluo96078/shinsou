import CloudKit
import ShinsouDomain

/// CloudKit 衝突解決策略。
/// 當雲端與本機資料不一致時，依據 Record Type 採用不同策略。
enum CloudKitConflictResolver {

    // MARK: - Chapter Conflicts

    /// 合併章節：read 取 OR（任一端已讀 → 已讀），lastPageRead 取 max。
    static func resolveChapter(
        local: CloudKitRecordMapper.ChapterSyncFields,
        remote: CloudKitRecordMapper.ChapterSyncFields
    ) -> CloudKitRecordMapper.ChapterSyncFields {
        CloudKitRecordMapper.ChapterSyncFields(
            mangaSource: local.mangaSource,
            mangaUrl: local.mangaUrl,
            chapterUrl: local.chapterUrl,
            read: local.read || remote.read,
            bookmark: local.bookmark || remote.bookmark,
            lastPageRead: max(local.lastPageRead, remote.lastPageRead),
            lastModifiedAt: max(local.lastModifiedAt, remote.lastModifiedAt)
        )
    }

    // MARK: - Track Conflicts

    /// 合併追蹤：lastChapterRead 取 max，status/score 取 last-write-wins。
    static func resolveTrack(
        local: CloudKitRecordMapper.TrackSyncFields,
        remote: CloudKitRecordMapper.TrackSyncFields
    ) -> CloudKitRecordMapper.TrackSyncFields {
        let useRemoteForLWW = remote.lastChapterRead > local.lastChapterRead

        return CloudKitRecordMapper.TrackSyncFields(
            mangaSource: local.mangaSource,
            mangaUrl: local.mangaUrl,
            trackerId: local.trackerId,
            remoteId: local.remoteId != 0 ? local.remoteId : remote.remoteId,
            title: useRemoteForLWW ? remote.title : local.title,
            lastChapterRead: max(local.lastChapterRead, remote.lastChapterRead),
            totalChapters: max(local.totalChapters, remote.totalChapters),
            status: useRemoteForLWW ? remote.status : local.status,
            score: useRemoteForLWW ? remote.score : local.score,
            remoteUrl: local.remoteUrl.isEmpty ? remote.remoteUrl : local.remoteUrl,
            startDate: min(
                local.startDate > 0 ? local.startDate : Int64.max,
                remote.startDate > 0 ? remote.startDate : Int64.max
            ) == Int64.max ? 0 : min(
                local.startDate > 0 ? local.startDate : Int64.max,
                remote.startDate > 0 ? remote.startDate : Int64.max
            ),
            finishDate: max(local.finishDate, remote.finishDate)
        )
    }

    // MARK: - History Conflicts

    /// 合併歷史：lastRead 取 max。
    static func resolveHistory(localLastRead: Int64, remoteLastRead: Int64) -> Int64 {
        max(localLastRead, remoteLastRead)
    }

    // MARK: - Manga Conflicts

    /// 合併漫畫：favorite 取 OR，其餘 last-write-wins。
    static func resolveManga(
        local: CloudKitRecordMapper.MangaSyncFields,
        remote: CloudKitRecordMapper.MangaSyncFields
    ) -> CloudKitRecordMapper.MangaSyncFields {
        let useRemote = remote.lastModifiedAt > local.lastModifiedAt

        return CloudKitRecordMapper.MangaSyncFields(
            source: local.source,
            url: local.url,
            title: useRemote ? remote.title : local.title,
            favorite: local.favorite || remote.favorite,
            viewerFlags: useRemote ? remote.viewerFlags : local.viewerFlags,
            chapterFlags: useRemote ? remote.chapterFlags : local.chapterFlags,
            notes: useRemote ? remote.notes : local.notes,
            lastModifiedAt: max(local.lastModifiedAt, remote.lastModifiedAt),
            dateAdded: min(local.dateAdded, remote.dateAdded)
        )
    }

    // MARK: - Category Conflicts

    /// 合併分類：last-write-wins（以 CKRecord 的 modificationDate 為準）。
    static func resolveCategory(
        local: CloudKitRecordMapper.CategorySyncFields,
        remote: CloudKitRecordMapper.CategorySyncFields
    ) -> CloudKitRecordMapper.CategorySyncFields {
        // 分類結構簡單，直接取遠端
        remote
    }
}
