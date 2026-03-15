import XCTest
@testable import ShinsouUI

final class ShinsouUITests: XCTestCase {
    func testColorTokensExist() {
        // Smoke test: ensure color tokens can be instantiated
        _ = ShinsouColors.primary
        _ = ShinsouColors.background
    }
}
