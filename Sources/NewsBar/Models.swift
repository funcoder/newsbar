import Foundation

enum NewsSource: String, CaseIterable {
    case bbc = "BBC News"
    case hackerNews = "Hacker News"
}

struct NewsItem {
    let title: String
    let url: URL
    let source: NewsSource
}

enum Constants {
    static let bbcFeedURL = URL(string: "https://feeds.bbci.co.uk/news/rss.xml")!
    static let hnTopStoriesURL = URL(string: "https://hacker-news.firebaseio.com/v0/topstories.json")!
    static let hnItemBaseURL = "https://hacker-news.firebaseio.com/v0/item/"

    static let headlinesPerSource = 5
    static let refreshInterval: TimeInterval = 900 // 15 minutes
    static let tickerLoops = 2
    static let headlineSeparator = "  ●  "
    static let menuBarIconName = "newspaper.fill"
}
