import Foundation

enum NewsSource: String, CaseIterable {
    case bbc = "BBC News"
    case hackerNews = "Hacker News"
}

struct NewsItem {
    let title: String
    let url: URL
    let source: NewsSource
    let imageURL: URL?
    let summary: String?
}

enum Constants {
    static let bbcFeedURL = URL(string: "https://feeds.bbci.co.uk/news/rss.xml")!
    static let hnTopStoriesURL = URL(string: "https://hacker-news.firebaseio.com/v0/topstories.json")!
    static let hnItemBaseURL = "https://hacker-news.firebaseio.com/v0/item/"

    static let headlinesPerSource = 5
    static let refreshInterval: TimeInterval = 900 // 15 minutes
    static let menuBarIconName = "newspaper.fill"

    static let bubbleDisplayDuration: TimeInterval = 9.0
    static let bubbleAnimationDuration: TimeInterval = 0.35
    static let startupBubbleDelay: TimeInterval = 3.0
}
