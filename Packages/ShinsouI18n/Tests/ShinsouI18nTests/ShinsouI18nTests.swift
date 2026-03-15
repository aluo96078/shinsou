import XCTest
@testable import ShinsouI18n

final class ShinsouI18nTests: XCTestCase {
    func testStringsExist() {
        XCTAssertFalse(MR.strings.tabLibrary.isEmpty)
    }
}
