import AppKit

final class StatusBarController {
    private let statusItem: NSStatusItem
    private let newsService = NewsService()
    private let popover = NSPopover()
    private let popoverController = HeadlinePopoverController()
    private let bubbleController = BubbleWindowController()
    private var refreshTimer: Timer?
    private var headlines: [NewsItem] = []
    private var previousTitles: Set<String> = []
    private var badgeDot: CALayer?

    init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        popover.contentViewController = popoverController
        popover.behavior = .transient

        popoverController.onRefresh = { [weak self] in
            self?.previousTitles = []
            self?.refresh()
        }
        popoverController.onQuit = {
            NSApplication.shared.terminate(nil)
        }

        setupIcon()
        setupClickAction()
        startRefreshTimer()
        refresh()
    }

    // MARK: - Icon

    private func setupIcon() {
        guard let button = statusItem.button else { return }
        if let image = NSImage(systemSymbolName: Constants.menuBarIconName, accessibilityDescription: "NewsBar") {
            let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
            if let configured = image.withSymbolConfiguration(config) {
                configured.isTemplate = true
                button.image = configured
                button.imagePosition = .imageOnly
                statusItem.length = NSStatusItem.squareLength
            } else {
                button.image = image
                button.imagePosition = .imageOnly
                statusItem.length = NSStatusItem.squareLength
            }
        } else {
            // Fallback to a text glyph so the status item is never invisible.
            button.image = nil
            button.title = "N"
            button.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
            statusItem.length = NSStatusItem.squareLength
        }
    }

    // MARK: - Badge

    private func showBadge() {
        guard badgeDot == nil, let button = statusItem.button else { return }

        let dot = CALayer()
        dot.backgroundColor = NSColor.systemRed.cgColor
        dot.cornerRadius = 3
        dot.frame = CGRect(x: button.bounds.width - 8, y: button.bounds.height - 10, width: 6, height: 6)

        button.wantsLayer = true
        button.layer?.addSublayer(dot)
        badgeDot = dot
    }

    private func clearBadge() {
        badgeDot?.removeFromSuperlayer()
        badgeDot = nil
    }

    // MARK: - Click Handling

    private func setupClickAction() {
        statusItem.button?.target = self
        statusItem.button?.action = #selector(togglePopover)
    }

    @objc private func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
        } else {
            guard let button = statusItem.button else { return }
            clearBadge()
            bubbleController.dismiss(animated: false)
            popoverController.update(headlines: headlines)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    // MARK: - Timer

    private func startRefreshTimer() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: Constants.refreshInterval, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    // MARK: - Data

    private func refresh() {
        fputs("[NewsBar] refresh() called\n", stderr)
        Task {
            fputs("[NewsBar] fetching...\n", stderr)
            let items = await newsService.fetchAll()
            fputs("[NewsBar] got \(items.count) items\n", stderr)
            await MainActor.run {
                self.headlines = items

                let currentTitles = Set(items.map(\.title))
                let newItems = items.filter { !self.previousTitles.contains($0.title) }

                fputs("[NewsBar] \(items.count) items, \(newItems.count) new\n", stderr)
                if !newItems.isEmpty {
                    if !self.previousTitles.isEmpty {
                        self.showBadge()
                    }
                    if let button = self.statusItem.button {
                        let bubbleItems = self.makeBalancedBubbleItems(from: newItems, limit: 5)
                        fputs("[NewsBar] showing bubbles for \(bubbleItems.count) items, button.window=\(String(describing: button.window))\n", stderr)
                        self.bubbleController.show(headlines: bubbleItems, below: button)
                    }
                }
                self.previousTitles = currentTitles

                if self.popover.isShown {
                    self.popoverController.update(headlines: items)
                }
            }
        }
    }

    private func makeBalancedBubbleItems(from items: [NewsItem], limit: Int) -> [NewsItem] {
        guard limit > 0 else { return [] }

        var queues: [NewsSource: [NewsItem]] = [:]
        for source in NewsSource.allCases {
            queues[source] = items.filter { $0.source == source }
        }

        var result: [NewsItem] = []
        while result.count < limit {
            var addedAny = false
            for source in NewsSource.allCases {
                guard var queue = queues[source], !queue.isEmpty else { continue }
                result.append(queue.removeFirst())
                queues[source] = queue
                addedAny = true
                if result.count == limit { break }
            }
            if !addedAny { break }
        }

        return result
    }
}
