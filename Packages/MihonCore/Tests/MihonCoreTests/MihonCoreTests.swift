import XCTest
@testable import MihonCore

final class MihonCoreTests: XCTestCase {
    func testMD5Hash() {
        let hash = "hello".md5Hash
        XCTAssertEqual(hash, "5d41402abc4b2a76b9719d911017c592")
    }

    func testSHA256Hash() {
        let hash = "hello".sha256Hash
        XCTAssertEqual(hash, "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824")
    }

    func testChapterNumber() {
        XCTAssertEqual("Chapter 12".chapterNumber(), 12.0)
        XCTAssertEqual("Ch. 5.5".chapterNumber(), 5.5)
        XCTAssertEqual("No number".chapterNumber(), -1.0)
    }

    func testDateEpochMillis() {
        let date = Date(epochMillis: 1700000000000)
        XCTAssertEqual(date.epochMillis, 1700000000000)
    }

    func testSafeSubscript() {
        let array = [1, 2, 3]
        XCTAssertEqual(array[safe: 0], 1)
        XCTAssertNil(array[safe: 5])
    }
}
