import XCTest
@testable import ShinsouSourceLocal

final class ShinsouSourceLocalTests: XCTestCase {
    func testComicInfoParsing() {
        let xml = """
        <?xml version="1.0"?>
        <ComicInfo>
            <Title>Test Manga</Title>
            <Writer>Author Name</Writer>
            <Penciller>Artist Name</Penciller>
            <Summary>A test manga description</Summary>
            <Genre>Action,Adventure</Genre>
        </ComicInfo>
        """
        let info = ComicInfo.parse(from: xml.data(using: .utf8)!)
        XCTAssertEqual(info?.title, "Test Manga")
        XCTAssertEqual(info?.writer, "Author Name")
        XCTAssertEqual(info?.genre, "Action,Adventure")
    }

    func testLocalSourceId() {
        XCTAssertEqual(LocalSource.sourceId, 0)
    }
}
