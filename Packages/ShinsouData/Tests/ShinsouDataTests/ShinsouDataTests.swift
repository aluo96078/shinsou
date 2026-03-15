import XCTest
@testable import ShinsouData
import ShinsouDomain

final class ShinsouDataTests: XCTestCase {
    func testMangaRecordRoundTrip() {
        let manga = Manga(
            id: -1, source: 1, url: "/test", title: "Test",
            genre: ["Action", "Adventure"]
        )
        let record = MangaRecord.from(domain: manga)
        let restored = record.toDomain()
        XCTAssertEqual(restored.title, "Test")
        XCTAssertEqual(restored.genre, ["Action", "Adventure"])
    }
}
