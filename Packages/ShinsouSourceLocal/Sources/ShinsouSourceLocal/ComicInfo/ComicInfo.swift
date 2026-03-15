import Foundation

/// Represents a parsed ComicInfo.xml file.
public struct ComicInfo: Sendable {
    public let title: String?
    public let series: String?
    public let summary: String?
    public let writer: String?
    public let penciller: String?
    public let genre: String?
    public let pageCount: Int?

    public static func parse(from data: Data) -> ComicInfo? {
        let parser = ComicInfoXMLParser(data: data)
        return parser.parse()
    }
}

private final class ComicInfoXMLParser: NSObject, XMLParserDelegate {
    private let parser: XMLParser
    private var currentElement = ""
    private var currentValue = ""

    private var title: String?
    private var series: String?
    private var summary: String?
    private var writer: String?
    private var penciller: String?
    private var genre: String?
    private var pageCount: Int?

    init(data: Data) {
        self.parser = XMLParser(data: data)
        super.init()
        self.parser.delegate = self
    }

    func parse() -> ComicInfo? {
        guard parser.parse() else { return nil }
        return ComicInfo(
            title: title, series: series, summary: summary,
            writer: writer, penciller: penciller, genre: genre,
            pageCount: pageCount
        )
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName: String?,
                attributes: [String: String] = [:]) {
        currentElement = elementName
        currentValue = ""
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentValue += string
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String,
                namespaceURI: String?, qualifiedName: String?) {
        let value = currentValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }

        switch elementName {
        case "Title": title = value
        case "Series": series = value
        case "Summary": summary = value
        case "Writer": writer = value
        case "Penciller": penciller = value
        case "Genre": genre = value
        case "PageCount": pageCount = Int(value)
        default: break
        }
    }
}
