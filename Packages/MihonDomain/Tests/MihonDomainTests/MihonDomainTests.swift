import XCTest
@testable import MihonDomain

final class MihonDomainTests: XCTestCase {
    func testMangaChapterFlags() {
        let manga = Manga(chapterFlags: Manga.chapterSortAsc | Manga.chapterShowUnread | Manga.chapterSortingNumber)
        XCTAssertFalse(manga.sortDescending)
        XCTAssertEqual(manga.unreadFilter, .enabledIs)
        XCTAssertEqual(manga.bookmarkedFilter, .disabled)
        XCTAssertEqual(manga.sorting, Manga.chapterSortingNumber)
    }

    func testCategoryIsSystem() {
        let system = Category(id: 0, name: "Default")
        let user = Category(id: 1, name: "Reading")
        XCTAssertTrue(system.isSystemCategory)
        XCTAssertFalse(user.isSystemCategory)
    }

    func testLibraryMangaUnreadCount() {
        let lib = LibraryManga(manga: Manga(), totalChapters: 10, readCount: 3)
        XCTAssertEqual(lib.unreadCount, 7)
    }
}
