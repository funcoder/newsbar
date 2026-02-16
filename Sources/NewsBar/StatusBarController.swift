import AppKit

private let tickerWidth: CGFloat = 360

final class StatusBarController {
    private let statusItem: NSStatusItem
    private let newsService = NewsService()
    private let tickerView: TickerView
    private var refreshTimer: Timer?
    private var headlines: [NewsItem] = []
    private var previousTitles: Set<String> = []
    private var isShowingTicker = false

    init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        tickerView = TickerView(frame: NSRect(x: 0, y: 0, width: tickerWidth, height: 22))
        tickerView.onFinished = { [weak self] in
            DispatchQueue.main.async {
                self?.collapseToIcon()
            }
        }

        buildMenu()
        startRefreshTimer()
        refresh()
    }

    // MARK: - Ticker / Icon switching

    private func showTicker(with titles: [String]) {
        guard !titles.isEmpty else { return }
        isShowingTicker = true

        statusItem.length = tickerWidth
        statusItem.button?.title = ""
        statusItem.button?.image = nil

        if tickerView.superview == nil, let button = statusItem.button {
            tickerView.frame = button.bounds
            tickerView.autoresizingMask = [.width, .height]
            button.addSubview(tickerView)
        }

        tickerView.isHidden = false
        tickerView.update(headlines: titles)
    }

    private func collapseToIcon() {
        isShowingTicker = false
        tickerView.stop()
        tickerView.isHidden = true

        statusItem.length = NSStatusItem.variableLength
        statusItem.button?.title = ""
        if let image = NSImage(systemSymbolName: Constants.menuBarIconName, accessibilityDescription: "NewsBar") {
            let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
            statusItem.button?.image = image.withSymbolConfiguration(config)
            statusItem.button?.imagePosition = .imageOnly
        }
    }

    // MARK: - Menu

    private func buildMenu() {
        let menu = NSMenu()

        menu.addItem(NSMenuItem(title: "Loading headlines...", action: nil, keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Refresh Now", action: #selector(refreshClicked), keyEquivalent: "r"))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit NewsBar", action: #selector(quitClicked), keyEquivalent: "q"))

        for item in menu.items {
            item.target = self
        }

        statusItem.menu = menu
    }

    private func rebuildMenu(with items: [NewsItem]) {
        let menu = NSMenu()

        for source in NewsSource.allCases {
            let sourceItems = items.filter { $0.source == source }
            guard !sourceItems.isEmpty else { continue }

            let header = NSMenuItem(title: source.rawValue, action: nil, keyEquivalent: "")
            header.isEnabled = false
            header.attributedTitle = NSAttributedString(
                string: source.rawValue,
                attributes: [.font: NSFont.boldSystemFont(ofSize: 13)]
            )
            menu.addItem(header)

            for newsItem in sourceItems {
                let menuItem = NSMenuItem(title: newsItem.title, action: #selector(headlineClicked(_:)), keyEquivalent: "")
                menuItem.target = self
                menuItem.representedObject = newsItem.url
                menu.addItem(menuItem)
            }

            menu.addItem(.separator())
        }

        menu.addItem(NSMenuItem(title: "Refresh Now", action: #selector(refreshClicked), keyEquivalent: "r"))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit NewsBar", action: #selector(quitClicked), keyEquivalent: "q"))

        for item in menu.items where item.action != nil && item.target == nil {
            item.target = self
        }

        statusItem.menu = menu
    }

    // MARK: - Actions

    @objc private func headlineClicked(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL else { return }
        NSWorkspace.shared.open(url)
    }

    @objc private func refreshClicked() {
        previousTitles = []
        refresh()
    }

    @objc private func quitClicked() {
        NSApplication.shared.terminate(nil)
    }

    // MARK: - Timer

    private func startRefreshTimer() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: Constants.refreshInterval, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    // MARK: - Data

    private func refresh() {
        Task {
            let items = await newsService.fetchAll()
            await MainActor.run {
                self.headlines = items
                self.rebuildMenu(with: items)

                let currentTitles = Set(items.map(\.title))
                let hasNewHeadlines = !currentTitles.isSubset(of: self.previousTitles)

                if hasNewHeadlines && !items.isEmpty {
                    self.previousTitles = currentTitles
                    self.showTicker(with: items.map(\.title))
                } else if !self.isShowingTicker {
                    self.collapseToIcon()
                }
            }
        }
    }
}
