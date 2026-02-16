import Foundation

final class BBCFeedParser: NSObject, XMLParserDelegate {
    private var items: [NewsItem] = []
    private var currentElement = ""
    private var currentTitle = ""
    private var currentLink = ""
    private var isInsideItem = false
    private var continuation: CheckedContinuation<[NewsItem], Error>?

    func fetch() async throws -> [NewsItem] {
        let (data, _) = try await URLSession.shared.data(from: Constants.bbcFeedURL)

        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            self.items = []
            let parser = XMLParser(data: data)
            parser.delegate = self
            parser.parse()
        }
    }

    // MARK: - XMLParserDelegate

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName: String?,
        attributes: [String: String]
    ) {
        currentElement = elementName
        if elementName == "item" {
            isInsideItem = true
            currentTitle = ""
            currentLink = ""
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard isInsideItem else { return }
        switch currentElement {
        case "title":
            currentTitle += string
        case "link":
            currentLink += string
        default:
            break
        }
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName: String?
    ) {
        guard elementName == "item", isInsideItem else { return }
        isInsideItem = false

        let trimmedTitle = currentTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLink = currentLink.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedTitle.isEmpty, let url = URL(string: trimmedLink) else { return }
        items.append(NewsItem(title: trimmedTitle, url: url, source: .bbc))
    }

    func parserDidEndDocument(_ parser: XMLParser) {
        let result = Array(items.prefix(Constants.headlinesPerSource))
        continuation?.resume(returning: result)
        continuation = nil
    }

    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        continuation?.resume(throwing: parseError)
        continuation = nil
    }
}
