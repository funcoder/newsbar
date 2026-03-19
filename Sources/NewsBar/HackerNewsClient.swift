import Foundation

final class HackerNewsClient {
    private struct HNItem: Decodable {
        let title: String
        let url: String?
        let id: Int
        let text: String?
    }

    func fetch() async throws -> [NewsItem] {
        let (data, _) = try await URLSession.shared.data(from: Constants.hnTopStoriesURL)
        let ids = try JSONDecoder().decode([Int].self, from: data)
        let topIds = Array(ids.prefix(Constants.headlinesPerSource))

        return try await withThrowingTaskGroup(of: NewsItem?.self, returning: [NewsItem].self) { group in
            for id in topIds {
                group.addTask {
                    try await self.fetchItem(id: id)
                }
            }

            var results: [NewsItem] = []
            for try await item in group {
                if let item {
                    results.append(item)
                }
            }
            return results
        }
    }

    private func fetchItem(id: Int) async throws -> NewsItem? {
        let url = URL(string: "\(Constants.hnItemBaseURL)\(id).json")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let hnItem = try JSONDecoder().decode(HNItem.self, from: data)

        let itemURL = hnItem.url.flatMap(URL.init(string:))
            ?? URL(string: "https://news.ycombinator.com/item?id=\(hnItem.id)")!

        return NewsItem(
            title: hnItem.title,
            url: itemURL,
            source: .hackerNews,
            imageURL: nil,
            summary: summary(for: hnItem, itemURL: itemURL)
        )
    }

    private func summary(for item: HNItem, itemURL: URL) -> String {
        if let text = item.text {
            let strippedTags = text.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
            let decodedEntities = strippedTags
                .replacingOccurrences(of: "&amp;", with: "&")
                .replacingOccurrences(of: "&quot;", with: "\"")
                .replacingOccurrences(of: "&#39;", with: "'")
                .replacingOccurrences(of: "&nbsp;", with: " ")
            let collapsedWhitespace = decodedEntities.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            let trimmed = collapsedWhitespace.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return trimmed
            }
        }

        let host = itemURL.host()?.replacingOccurrences(of: "www.", with: "") ?? "news.ycombinator.com"
        return "Top Hacker News story from \(host). Open for the full article and discussion."
    }
}
