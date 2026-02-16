import Foundation

final class NewsService {
    private let bbcParser = BBCFeedParser()
    private let hnClient = HackerNewsClient()

    func fetchAll() async -> [NewsItem] {
        async let bbcResult = fetchBBC()
        async let hnResult = fetchHN()

        let bbc = await bbcResult
        let hn = await hnResult

        return bbc + hn
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
