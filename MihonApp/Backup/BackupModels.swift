import Foundation
import MihonDomain

// MARK: - Root Backup Structure

/// Mihon iOS 備份根結構。
/// 格式概念上相容於 Android Mihon 的 `.tachibk` 備份，
/// 但採用 Codable/JSON 取代 protobuf，並以 zlib 壓縮。
/// 副檔名：`.mihonbackup`
struct MihonBackup: Codable {
    /// 備份格式版本，用於未來的向後相容性檢查
    let version: Int
    /// 備份建立時間（Unix 毫秒）
    let createdAt: Int64
    /// 所有加入書庫的漫畫
    var mangas: [BackupManga]
    /// 所有使用者分類
    var categories: [BackupCategory]

    static let currentVersion = 1
}

// MARK: - Manga

struct BackupManga: Codable {
    // MARK: 基本資訊
    let source: Int64
    let url: String
    let title: String
    let artist: String?
    let author: String?
    let description: String?
    let genre: [String]?
    let status: Int
    let thumbnailUrl: String?
    let favorite: Bool
    let viewerFlags: Int64
    let chapterFlags: Int64
    let notes: String?

    // MARK: 關聯資料
    /// 此漫畫的所有章節
    var chapters: [BackupChapter]
    /// 此漫畫所屬分類的 sort index（對應 BackupCategory.sort）
    var categories: [Int]
    /// 追蹤記錄
    var tracks: [BackupTrack]
    /// 閱讀歷史
    var history: [BackupHistory]
}

extension BackupManga {
    /// 將 Domain Manga 轉換為備份模型
    init(
        manga: Manga,
        chapters: [BackupChapter],
        categories: [Int],
        tracks: [BackupTrack],
        history: [BackupHistory]
    ) {
        self.source = manga.source
        self.url = manga.url
        self.title = manga.title
        self.artist = manga.artist
        self.author = manga.author
        self.description = manga.description
        self.genre = manga.genre
        self.status = Int(manga.status)
        self.thumbnailUrl = manga.thumbnailUrl
        self.favorite = manga.favorite
        self.viewerFlags = manga.viewerFlags
        self.chapterFlags = manga.chapterFlags
        self.notes = manga.notes.isEmpty ? nil : manga.notes
        self.chapters = chapters
        self.categories = categories
        self.tracks = tracks
        self.history = history
    }

    /// 轉換回 Domain Manga（id 留給 DB 分配）
    func toDomainManga() -> Manga {
        Manga(
            source: source,
            favorite: favorite,
            viewerFlags: viewerFlags,
            chapterFlags: chapterFlags,
            url: url,
            title: title,
            artist: artist,
            author: author,
            description: description,
            genre: genre,
            status: Int64(status),
            thumbnailUrl: thumbnailUrl,
            initialized: true,
            notes: notes ?? ""
        )
    }
}

// MARK: - Chapter

struct BackupChapter: Codable {
    let url: String
    let name: String
    let scanlator: String?
    let chapterNumber: Double
    let read: Bool
    let bookmark: Bool
    let lastPageRead: Int
    let dateFetch: Int64
    let dateUpload: Int64
}

extension BackupChapter {
    init(chapter: Chapter) {
        self.url = chapter.url
        self.name = chapter.name
        self.scanlator = chapter.scanlator
        self.chapterNumber = chapter.chapterNumber
        self.read = chapter.read
        self.bookmark = chapter.bookmark
        self.lastPageRead = chapter.lastPageRead
        self.dateFetch = chapter.dateFetch
        self.dateUpload = chapter.dateUpload
    }

    func toDomainChapter(mangaId: Int64) -> Chapter {
        Chapter(
            mangaId: mangaId,
            url: url,
            name: name,
            scanlator: scanlator,
            read: read,
            bookmark: bookmark,
            lastPageRead: lastPageRead,
            chapterNumber: chapterNumber,
            dateFetch: dateFetch,
            dateUpload: dateUpload
        )
    }
}

// MARK: - Category

struct BackupCategory: Codable {
    let name: String
    /// 排序索引（同時作為 BackupManga.categories 的參照鍵）
    let sort: Int
    let flags: Int64
}

extension BackupCategory {
    init(category: MihonDomain.Category) {
        self.name = category.name
        self.sort = category.sort
        self.flags = category.flags
    }

    func toDomainCategory() -> MihonDomain.Category {
        Category(name: name, sort: sort, flags: flags)
    }
}

// MARK: - Track

struct BackupTrack: Codable {
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

extension BackupTrack {
    init(track: Track) {
        self.trackerId = track.trackerId
        self.remoteId = track.remoteId
        self.title = track.title
        self.lastChapterRead = track.lastChapterRead
        self.totalChapters = track.totalChapters
        self.status = track.status
        self.score = track.score
        self.remoteUrl = track.remoteUrl
        self.startDate = track.startDate
        self.finishDate = track.finishDate
    }

    func toDomainTrack(mangaId: Int64) -> Track {
        Track(
            mangaId: mangaId,
            trackerId: trackerId,
            remoteId: remoteId,
            title: title,
            lastChapterRead: lastChapterRead,
            totalChapters: totalChapters,
            status: status,
            score: score,
            remoteUrl: remoteUrl,
            startDate: startDate,
            finishDate: finishDate
        )
    }
}

// MARK: - History

struct BackupHistory: Codable {
    /// 以 chapter URL 作為參照鍵（避免依賴 DB id）
    let chapterUrl: String
    /// 最後閱讀時間（Unix 毫秒）
    let lastRead: Int64
    /// 本次閱讀花費時間（毫秒）
    let timeRead: Int64
}
