import Foundation

final class HackerNewsClient {
    private struct HNItem: Decodable {
        let title: String
        let url: String?
        let id: Int
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

        return NewsItem(title: hnItem.title, url: itemURL, source: .hackerNews)
    }
}
