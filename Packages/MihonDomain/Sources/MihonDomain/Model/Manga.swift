import Foundation
import MihonCore

public struct Manga: Identifiable, Sendable, Equatable, Hashable {
    public let id: Int64
    public let source: Int64
    public let favorite: Bool
    public let lastUpdate: Int64
    public let nextUpdate: Int64
    public let fetchInterval: Int
    public let dateAdded: Int64
    public let viewerFlags: Int64
    public let chapterFlags: Int64
    public let coverLastModified: Int64
    public let url: String
    public let title: String
    public let artist: String?
    public let author: String?
    public let description: String?
    public let genre: [String]?
    public let status: Int64
    public let thumbnailUrl: String?
    public let updateStrategy: Int
    public let initialized: Bool
    public let lastModifiedAt: Int64
    public let favoriteModifiedAt: Int64?
    public let version: Int64
    public let notes: String

    public init(
        id: Int64 = -1,
        source: Int64 = -1,
        favorite: Bool = false,
        lastUpdate: Int64 = 0,
        nextUpdate: Int64 = 0,
        fetchInterval: Int = 0,
        dateAdded: Int64 = 0,
        viewerFlags: Int64 = 0,
        chapterFlags: Int64 = 0,
        coverLastModified: Int64 = 0,
        url: String = "",
        title: String = "",
        artist: String? = nil,
        author: String? = nil,
        description: String? = nil,
        genre: [String]? = nil,
        status: Int64 = 0,
        thumbnailUrl: String? = nil,
        updateStrategy: Int = 0,
        initialized: Bool = false,
        lastModifiedAt: Int64 = 0,
        favoriteModifiedAt: Int64? = nil,
        version: Int64 = 0,
        notes: String = ""
    ) {
        self.id = id; self.source = source; self.favorite = favorite
        self.lastUpdate = lastUpdate; self.nextUpdate = nextUpdate
        self.fetchInterval = fetchInterval; self.dateAdded = dateAdded
        self.viewerFlags = viewerFlags; self.chapterFlags = chapterFlags
        self.coverLastModified = coverLastModified; self.url = url
        self.title = title; self.artist = artist; self.author = author
        self.description = description; self.genre = genre; self.status = status
        self.thumbnailUrl = thumbnailUrl; self.updateStrategy = updateStrategy
        self.initialized = initialized; self.lastModifiedAt = lastModifiedAt
        self.favoriteModifiedAt = favoriteModifiedAt; self.version = version
        self.notes = notes
    }

    // MARK: - Chapter Flags Bitmask (matches Android Manga.kt)

    public static let showAll: Int64 = 0x00000000

    public static let chapterSortDesc: Int64 = 0x00000000
    public static let chapterSortAsc: Int64 = 0x00000001
    public static let chapterSortDirMask: Int64 = 0x00000001

    public static let chapterShowUnread: Int64 = 0x00000002
    public static let chapterShowRead: Int64 = 0x00000004
    public static let chapterUnreadMask: Int64 = 0x00000006

    public static let chapterShowDownloaded: Int64 = 0x00000008
    public static let chapterShowNotDownloaded: Int64 = 0x00000010
    public static let chapterDownloadedMask: Int64 = 0x00000018

    public static let chapterShowBookmarked: Int64 = 0x00000020
    public static let chapterShowNotBookmarked: Int64 = 0x00000040
    public static let chapterBookmarkedMask: Int64 = 0x00000060

    public static let chapterSortingSource: Int64 = 0x00000000
    public static let chapterSortingNumber: Int64 = 0x00000100
    public static let chapterSortingUploadDate: Int64 = 0x00000200
    public static let chapterSortingAlphabet: Int64 = 0x00000300
    public static let chapterSortingMask: Int64 = 0x00000300

    public static let chapterDisplayName: Int64 = 0x00000000
    public static let chapterDisplayNumber: Int64 = 0x00100000
    public static let chapterDisplayMask: Int64 = 0x00100000

    // MARK: - Computed Properties

    public var sorting: Int64 { chapterFlags & Self.chapterSortingMask }
    public var displayMode: Int64 { chapterFlags & Self.chapterDisplayMask }
    public var unreadFilterRaw: Int64 { chapterFlags & Self.chapterUnreadMask }
    public var downloadedFilterRaw: Int64 { chapterFlags & Self.chapterDownloadedMask }
    public var bookmarkedFilterRaw: Int64 { chapterFlags & Self.chapterBookmarkedMask }

    public var sortDescending: Bool {
        chapterFlags & Self.chapterSortDirMask == Self.chapterSortDesc
    }

    public var unreadFilter: TriState {
        switch unreadFilterRaw {
        case Self.chapterShowUnread: return .enabledIs
        case Self.chapterShowRead: return .enabledNot
        default: return .disabled
        }
    }

    public var bookmarkedFilter: TriState {
        switch bookmarkedFilterRaw {
        case Self.chapterShowBookmarked: return .enabledIs
        case Self.chapterShowNotBookmarked: return .enabledNot
        default: return .disabled
        }
    }
}

public enum TriState: Int, Sendable {
    case disabled = 0
    case enabledIs = 1
    case enabledNot = 2
}
