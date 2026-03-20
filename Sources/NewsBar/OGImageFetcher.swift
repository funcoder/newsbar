import Foundation

enum OGImageFetcher {
    private static let maxBytes = 65_536
    private static let timeoutInterval: TimeInterval = 5.0

    static func fetchImageURL(for articleURL: URL) async -> URL? {
        guard let scheme = articleURL.scheme,
              scheme == "http" || scheme == "https" else {
            return nil
        }

        var request = URLRequest(url: articleURL)
        request.timeoutInterval = timeoutInterval
        request.setValue("NewsBar/1.0", forHTTPHeaderField: "User-Agent")

        guard let (data, _) = try? await URLSession.shared.data(for: request) else {
            return nil
        }

        let limitedData = data.prefix(maxBytes)
        guard let html = String(data: limitedData, encoding: .utf8)
                ?? String(data: limitedData, encoding: .ascii) else {
            return nil
        }

        return extractOGImage(from: html)
    }

    private static func extractOGImage(from html: String) -> URL? {
        let lower = html.lowercased()

        // Only search within <head> to avoid false matches in body
        let headEnd = lower.range(of: "</head>")?.lowerBound ?? lower.endIndex
        let headHTML = String(html[html.startIndex..<headEnd])
        let headLower = String(lower[lower.startIndex..<headEnd])

        var searchStart = headLower.startIndex
        while let range = headLower.range(of: "og:image", range: searchStart..<headLower.endIndex) {
            // Find the enclosing <meta ... > tag
            guard let tagStart = headLower[headLower.startIndex..<range.lowerBound].lastIndex(of: "<"),
                  let tagEnd = headLower[range.upperBound...].firstIndex(of: ">") else {
                break
            }

            let tag = String(headHTML[tagStart...tagEnd])

            if let content = extractAttribute(from: tag, named: "content") {
                let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
                if let url = URL(string: trimmed),
                   let scheme = url.scheme,
                   scheme == "http" || scheme == "https" {
                    return url
                }
            }

            searchStart = headLower.index(after: range.lowerBound)
        }

        return nil
    }

    private static func extractAttribute(from tag: String, named name: String) -> String? {
        let lower = tag.lowercased()
        guard let attrRange = lower.range(of: name) else { return nil }

        let afterName = tag[attrRange.upperBound...].drop(while: { $0.isWhitespace })
        guard afterName.first == "=" else { return nil }

        let afterEquals = afterName.dropFirst().drop(while: { $0.isWhitespace })
        guard let quote = afterEquals.first, quote == "\"" || quote == "'" else { return nil }

        let valueStart = afterEquals.index(after: afterEquals.startIndex)
        guard let valueEnd = afterEquals[valueStart...].firstIndex(of: quote) else { return nil }

        return String(afterEquals[valueStart..<valueEnd])
    }
}
