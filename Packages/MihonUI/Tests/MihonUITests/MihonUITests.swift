import XCTest
@testable import MihonUI

final class MihonUITests: XCTestCase {
    func testColorTokensExist() {
        // Smoke test: ensure color tokens can be instantiated
        _ = MihonColors.primary
        _ = MihonColors.background
    }
}
