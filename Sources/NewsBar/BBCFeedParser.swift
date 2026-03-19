import Foundation

final class BBCFeedParser: NSObject, XMLParserDelegate {
    private var items: [NewsItem] = []
    private var currentElement = ""
    private var currentTitle = ""
    private var currentLink = ""
    private var currentDescription = ""
    private var currentImageURL: URL?
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
            currentDescription = ""
            currentImageURL = nil
            return
        }

        guard isInsideItem else { return }
        if let imageURL = imageURL(from: elementName, attributes: attributes), currentImageURL == nil {
            currentImageURL = imageURL
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard isInsideItem else { return }
        switch currentElement {
        case "title":
            currentTitle += string
        case "link":
            currentLink += string
        case "description":
            currentDescription += string
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
        let cleanedSummary = sanitizeSummary(currentDescription)

        guard !trimmedTitle.isEmpty, let url = URL(string: trimmedLink) else { return }
        items.append(
            NewsItem(
                title: trimmedTitle,
                url: url,
                source: .bbc,
                imageURL: currentImageURL,
                summary: cleanedSummary
            )
        )
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

    private func imageURL(from elementName: String, attributes: [String: String]) -> URL? {
        let normalizedName = elementName.lowercased()
        let key: String?

        switch normalizedName {
        case "media:thumbnail", "media:content":
            key = attributes["url"]
        case "enclosure":
            let type = attributes["type"]?.lowercased() ?? ""
            key = type.hasPrefix("image/") ? attributes["url"] : nil
        default:
            key = nil
        }

        guard let key, let url = URL(string: key) else { return nil }
        return url
    }

    private func sanitizeSummary(_ raw: String) -> String? {
        let strippedTags = raw.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
        let decodedEntities = strippedTags
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&nbsp;", with: " ")
        let collapsedWhitespace = decodedEntities.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        let trimmed = collapsedWhitespace.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
