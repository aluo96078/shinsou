import XCTest
@testable import MihonSourceAPI

final class MihonSourceAPITests: XCTestCase {
    func testSMangaInit() {
        let manga = SManga(url: "/manga/1", title: "Test Manga")
        XCTAssertEqual(manga.url, "/manga/1")
        XCTAssertEqual(manga.title, "Test Manga")
        XCTAssertEqual(manga.status, .unknown)
    }

    func testFilterList() {
        let filters: FilterList = [
            .header(name: "Genre"),
            .checkBox(name: "Action", state: true),
            .triState(name: "Romance", state: .include),
            .sort(name: "Order", values: ["Name", "Date"], selection: .init(index: 0, ascending: true)),
        ]
        XCTAssertEqual(filters.count, 4)
    }

    func testPluginManifestDecoding() throws {
        let json = """
        {
            "id": "com.test",
            "name": "Test",
            "version": "1.0",
            "lang": "en",
            "nsfw": false,
            "script": "test.js",
            "signature": "abc123"
        }
        """
        let manifest = try JSONDecoder().decode(PluginManifest.self, from: json.data(using: .utf8)!)
        XCTAssertEqual(manifest.id, "com.test")
        XCTAssertEqual(manifest.lang, "en")
    }
}
