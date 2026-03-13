import XCTest
@testable import MihonI18n

final class MihonI18nTests: XCTestCase {
    func testStringsExist() {
        XCTAssertFalse(MR.strings.tabLibrary.isEmpty)
    }
}
