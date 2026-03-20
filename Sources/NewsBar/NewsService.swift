import Foundation

final class NewsService {
    private let bbcParser = BBCFeedParser()
    private let hnClient = HackerNewsClient()

    func fetchAll() async -> [NewsItem] {
        async let bbcResult = fetchBBC()
        async let hnResult = fetchHN()

        let bbc = await bbcResult
        let hn = await hnResult

        let allItems = bbc + hn
        return await backfillOGImages(for: allItems)
    }

    private func backfillOGImages(for items: [NewsItem]) async -> [NewsItem] {
        return await withTaskGroup(of: (Int, URL?).self, returning: [NewsItem].self) { group in
            for (index, item) in items.enumerated() {
                guard item.imageURL == nil else { continue }
                group.addTask {
                    let ogURL = await OGImageFetcher.fetchImageURL(for: item.url)
                    return (index, ogURL)
                }
            }

            var updated = items
            for await (index, ogURL) in group {
                guard let ogURL else { continue }
                let original = updated[index]
                updated[index] = NewsItem(
                    title: original.title,
                    url: original.url,
                    source: original.source,
                    imageURL: ogURL,
                    summary: original.summary
                )
            }
            return updated
        }
    }

    private func fetchBBC() async -> [NewsItem] {
        do {
            return try await bbcParser.fetch()
        } catch {
            print("[NewsBar] BBC fetch failed: \(error.localizedDescription)")
            return []
        }
    }

    private func fetchHN() async -> [NewsItem] {
        do {
            return try await hnClient.fetch()
        } catch {
            print("[NewsBar] HN fetch failed: \(error.localizedDescription)")
            return []
        }
    }
}
