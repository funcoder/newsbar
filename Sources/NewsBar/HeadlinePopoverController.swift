import AppKit

final class HeadlinePopoverController: NSViewController {
    private let scrollView = NSScrollView()
    private let contentContainer = FlippedView()
    private let contentStack = NSStackView()
    private let dateLabel = NSTextField(labelWithString: "")
    private var headlines: [NewsItem] = []
    private var soundToggleButton: NSButton?

    var onRefresh: (() -> Void)?
    var onQuit: (() -> Void)?

    override func loadView() {
        let root = NSView(frame: NSRect(x: 0, y: 0, width: 760, height: 820))
        root.wantsLayer = true
        root.layer?.backgroundColor = NSColor(red: 0.97, green: 0.96, blue: 0.93, alpha: 1).cgColor
        root.layer?.cornerRadius = 12
        root.layer?.masksToBounds = true
        root.layer?.borderColor = NSColor.black.withAlphaComponent(0.2).cgColor
        root.layer?.borderWidth = 1

        let masthead = makeMasthead()
        masthead.translatesAutoresizingMaskIntoConstraints = false

        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        contentStack.orientation = .vertical
        contentStack.alignment = .width
        contentStack.spacing = 10
        contentStack.translatesAutoresizingMaskIntoConstraints = false

        contentContainer.translatesAutoresizingMaskIntoConstraints = false
        contentContainer.addSubview(contentStack)
        scrollView.documentView = contentContainer

        let footerRule = makeRule()
        footerRule.translatesAutoresizingMaskIntoConstraints = false

        let footer = makeFooter()
        footer.translatesAutoresizingMaskIntoConstraints = false

        root.addSubview(masthead)
        root.addSubview(scrollView)
        root.addSubview(footerRule)
        root.addSubview(footer)

        NSLayoutConstraint.activate([
            masthead.topAnchor.constraint(equalTo: root.topAnchor, constant: 10),
            masthead.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 14),
            masthead.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -14),
            masthead.heightAnchor.constraint(equalToConstant: 146),

            scrollView.topAnchor.constraint(equalTo: masthead.bottomAnchor, constant: 8),
            scrollView.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 10),
            scrollView.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -10),
            scrollView.bottomAnchor.constraint(equalTo: footerRule.topAnchor, constant: -8),

            footerRule.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 12),
            footerRule.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -12),
            footerRule.heightAnchor.constraint(equalToConstant: 1),
            footerRule.bottomAnchor.constraint(equalTo: footer.topAnchor, constant: -6),

            footer.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 14),
            footer.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -14),
            footer.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -8),
            footer.heightAnchor.constraint(equalToConstant: 32),

            contentStack.topAnchor.constraint(equalTo: contentContainer.topAnchor, constant: 8),
            contentStack.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor, constant: 8),
            contentStack.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor, constant: -8),
            contentStack.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor, constant: -8),
            contentStack.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor, constant: -16),
            contentContainer.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor),
        ])

        view = root
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        resizeToFitContent()
    }

    func update(headlines: [NewsItem]) {
        self.headlines = headlines
        dateLabel.stringValue = "Wednesday \(Self.dateFormatter.string(from: Date()))  |  No 74971"
        rebuildFrontPage()
        scrollToTop()
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        scrollToTop()
    }

    // MARK: - Front Page

    private func rebuildFrontPage() {
        contentStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        guard !headlines.isEmpty else {
            addFullWidth(makeEmptyState())
            resizeToFitContent()
            return
        }

        let lead = headlines[0]
        let secondary = headlines[safe: 1]
        let tertiary = headlines[safe: 2]

        addFullWidth(makeLeadRibbon(lead: lead, secondary: secondary))
        addFullWidth(makeHeroRow(lead: lead, secondary: secondary, tertiary: tertiary))

        let mainHeadlineItem = headlines[safe: 3] ?? lead
        let mainHeadline = StoryButton(item: mainHeadlineItem, style: .mainHeadline)
        mainHeadline.target = self
        mainHeadline.action = #selector(headlineClicked(_:))
        addFullWidth(mainHeadline)

        addFullWidth(makeRule())
        addFullWidth(makeSectionsRow())

        resizeToFitContent()
    }

    private func makeLeadRibbon(lead: NewsItem, secondary: NewsItem?) -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 8
        row.distribution = .fill
        row.translatesAutoresizingMaskIntoConstraints = false
        row.heightAnchor.constraint(equalToConstant: 96).isActive = true

        let leadButton = StoryButton(item: lead, style: .ribbonLead)
        leadButton.target = self
        leadButton.action = #selector(headlineClicked(_:))
        row.addArrangedSubview(leadButton)

        if let secondary {
            let sideButton = StoryButton(item: secondary, style: .ribbonSide)
            sideButton.target = self
            sideButton.action = #selector(headlineClicked(_:))
            row.addArrangedSubview(sideButton)
            leadButton.widthAnchor.constraint(equalTo: row.widthAnchor, multiplier: 0.68).isActive = true
        }

        return row
    }

    private func makeHeroRow(lead: NewsItem, secondary: NewsItem?, tertiary: NewsItem?) -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 8
        row.distribution = .fill
        row.translatesAutoresizingMaskIntoConstraints = false
        row.heightAnchor.constraint(equalToConstant: 260).isActive = true

        let heroButton = StoryButton(item: lead, style: .heroImage)
        heroButton.target = self
        heroButton.action = #selector(headlineClicked(_:))
        row.addArrangedSubview(heroButton)
        heroButton.widthAnchor.constraint(equalTo: row.widthAnchor, multiplier: 0.68).isActive = true

        let sideColumn = NSStackView()
        sideColumn.orientation = .vertical
        sideColumn.spacing = 8
        sideColumn.alignment = .width
        sideColumn.translatesAutoresizingMaskIntoConstraints = false

        let sideTop = StoryButton(item: secondary ?? lead, style: .sideFeature)
        sideTop.target = self
        sideTop.action = #selector(headlineClicked(_:))
        sideColumn.addArrangedSubview(sideTop)

        let sideBottom = StoryButton(item: tertiary ?? secondary ?? lead, style: .sideFeature)
        sideBottom.target = self
        sideBottom.action = #selector(headlineClicked(_:))
        sideColumn.addArrangedSubview(sideBottom)

        row.addArrangedSubview(sideColumn)
        return row
    }

    private func makeSectionsRow() -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 14
        row.distribution = .fillEqually
        row.translatesAutoresizingMaskIntoConstraints = false

        let bbcSection = makeSectionColumn(
            title: "WORLD DESK",
            items: headlines.filter { $0.source == .bbc }
        )
        let hnSection = makeSectionColumn(
            title: "TECH DESK",
            items: headlines.filter { $0.source == .hackerNews }
        )

        row.addArrangedSubview(bbcSection)
        row.addArrangedSubview(hnSection)
        return row
    }

    private func makeSectionColumn(title: String, items: [NewsItem]) -> NSView {
        let column = NSStackView()
        column.orientation = .vertical
        column.spacing = 6
        column.alignment = .width
        column.translatesAutoresizingMaskIntoConstraints = false

        let sectionTitle = NSTextField(labelWithString: title)
        sectionTitle.font = NSFont(name: "TimesNewRomanPS-BoldMT", size: 20) ?? .systemFont(ofSize: 20, weight: .bold)
        sectionTitle.textColor = .black
        sectionTitle.translatesAutoresizingMaskIntoConstraints = false
        column.addArrangedSubview(sectionTitle)
        sectionTitle.widthAnchor.constraint(equalTo: column.widthAnchor).isActive = true

        let sectionRule = makeRule()
        column.addArrangedSubview(sectionRule)
        sectionRule.widthAnchor.constraint(equalTo: column.widthAnchor).isActive = true

        for item in items {
            let story = StoryButton(item: item, style: .columnStory)
            story.target = self
            story.action = #selector(headlineClicked(_:))
            column.addArrangedSubview(story)
            story.widthAnchor.constraint(equalTo: column.widthAnchor).isActive = true
        }

        return column
    }

    // MARK: - Shell

    private func makeMasthead() -> NSView {
        let container = NSView()

        let topLine = NSTextField(labelWithString: "DAILY NEWSPAPER OF THE YEAR")
        topLine.font = .systemFont(ofSize: 10, weight: .bold)
        topLine.textColor = NSColor(red: 0.74, green: 0.26, blue: 0.35, alpha: 1)
        topLine.alignment = .center
        topLine.translatesAutoresizingMaskIntoConstraints = false

        let title = NSTextField(labelWithString: "THE NEWSBAR TIMES")
        title.font = NSFont(name: "TimesNewRomanPS-BoldMT", size: 52) ?? .systemFont(ofSize: 52, weight: .bold)
        title.textColor = NSColor(red: 0.03, green: 0.06, blue: 0.12, alpha: 1)
        title.alignment = .center
        title.cell?.wraps = false
        title.lineBreakMode = .byClipping
        title.translatesAutoresizingMaskIntoConstraints = false

        dateLabel.font = NSFont(name: "TimesNewRomanPSMT", size: 11) ?? .systemFont(ofSize: 11, weight: .regular)
        dateLabel.textColor = NSColor.black.withAlphaComponent(0.7)
        dateLabel.alignment = .center
        dateLabel.translatesAutoresizingMaskIntoConstraints = false

        let bottomRule = makeRule()
        bottomRule.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(topLine)
        container.addSubview(title)
        container.addSubview(dateLabel)
        container.addSubview(bottomRule)

        NSLayoutConstraint.activate([
            topLine.topAnchor.constraint(equalTo: container.topAnchor),
            topLine.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            topLine.trailingAnchor.constraint(equalTo: container.trailingAnchor),

            title.topAnchor.constraint(equalTo: topLine.bottomAnchor, constant: 14),
            title.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            title.trailingAnchor.constraint(equalTo: container.trailingAnchor),

            dateLabel.topAnchor.constraint(equalTo: title.bottomAnchor, constant: -2),
            dateLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            dateLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),

            bottomRule.topAnchor.constraint(equalTo: dateLabel.bottomAnchor, constant: 8),
            bottomRule.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            bottomRule.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            bottomRule.heightAnchor.constraint(equalToConstant: 1),
        ])

        return container
    }

    private func makeFooter() -> NSView {
        let footer = NSView()

        let refreshButton = NSButton(title: "Refresh", target: self, action: #selector(refreshClicked))
        refreshButton.isBordered = false
        refreshButton.font = NSFont(name: "TimesNewRomanPS-BoldMT", size: 15) ?? .systemFont(ofSize: 15, weight: .bold)
        refreshButton.contentTintColor = .black
        refreshButton.translatesAutoresizingMaskIntoConstraints = false

        let muteButton = makeSoundToggleButton()
        muteButton.translatesAutoresizingMaskIntoConstraints = false
        soundToggleButton = muteButton

        let quitButton = NSButton(title: "Quit", target: self, action: #selector(quitClicked))
        quitButton.isBordered = false
        quitButton.font = NSFont(name: "TimesNewRomanPS-BoldMT", size: 15) ?? .systemFont(ofSize: 15, weight: .bold)
        quitButton.contentTintColor = .black
        quitButton.translatesAutoresizingMaskIntoConstraints = false

        footer.addSubview(refreshButton)
        footer.addSubview(muteButton)
        footer.addSubview(quitButton)

        NSLayoutConstraint.activate([
            refreshButton.leadingAnchor.constraint(equalTo: footer.leadingAnchor, constant: 4),
            refreshButton.centerYAnchor.constraint(equalTo: footer.centerYAnchor),
            muteButton.centerXAnchor.constraint(equalTo: footer.centerXAnchor),
            muteButton.centerYAnchor.constraint(equalTo: footer.centerYAnchor),
            quitButton.trailingAnchor.constraint(equalTo: footer.trailingAnchor, constant: -4),
            quitButton.centerYAnchor.constraint(equalTo: footer.centerYAnchor),
        ])

        return footer
    }

    private func makeSoundToggleButton() -> NSButton {
        let button = NSButton(frame: .zero)
        button.isBordered = false
        button.setButtonType(.momentaryChange)
        button.target = self
        button.action = #selector(soundToggleClicked)
        updateSoundToggleIcon(button)
        return button
    }

    private func updateSoundToggleIcon(_ button: NSButton) {
        let symbolName = Settings.soundEnabled ? "speaker.wave.2" : "speaker.slash"
        if let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "Toggle sound") {
            let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
            button.image = image.withSymbolConfiguration(config) ?? image
            button.contentTintColor = Settings.soundEnabled ? .black : NSColor.black.withAlphaComponent(0.4)
            button.setAccessibilityLabel("Sound")
            button.setAccessibilityHelp(Settings.soundEnabled ? "Sound is on" : "Sound is off")
        }
    }

    private func makeRule() -> NSView {
        let rule = NSView()
        rule.wantsLayer = true
        rule.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.2).cgColor
        rule.translatesAutoresizingMaskIntoConstraints = false
        rule.heightAnchor.constraint(equalToConstant: 1).isActive = true
        return rule
    }

    private func makeEmptyState() -> NSView {
        let label = NSTextField(wrappingLabelWithString: "No stories yet. Press Refresh to print the next edition.")
        label.font = NSFont(name: "TimesNewRomanPSMT", size: 20) ?? .systemFont(ofSize: 20, weight: .regular)
        label.textColor = NSColor.black.withAlphaComponent(0.7)
        label.alignment = .center
        label.maximumNumberOfLines = 2
        label.translatesAutoresizingMaskIntoConstraints = false

        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.heightAnchor.constraint(equalToConstant: 200).isActive = true
        container.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
            label.centerYAnchor.constraint(equalTo: container.centerYAnchor),
        ])
        return container
    }

    private func addFullWidth(_ view: NSView) {
        view.translatesAutoresizingMaskIntoConstraints = false
        contentStack.addArrangedSubview(view)
        view.widthAnchor.constraint(equalTo: contentStack.widthAnchor).isActive = true
    }

    private func resizeToFitContent() {
        let contentHeight = contentStack.fittingSize.height + 190
        preferredContentSize = NSSize(width: 760, height: min(max(contentHeight, 560), 820))
    }

    private func scrollToTop() {
        scrollView.layoutSubtreeIfNeeded()
        scrollView.contentView.scroll(to: .zero)
        scrollView.reflectScrolledClipView(scrollView.contentView)
    }

    // MARK: - Actions

    @objc private func headlineClicked(_ sender: StoryButton) {
        NSWorkspace.shared.open(sender.item.url)
        view.window?.performClose(nil)
    }

    @objc private func refreshClicked() {
        onRefresh?()
    }

    @objc private func soundToggleClicked() {
        Settings.soundEnabled = !Settings.soundEnabled
        if let button = soundToggleButton {
            updateSoundToggleIcon(button)
        }
    }

    @objc private func quitClicked() {
        onQuit?()
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d yyyy"
        return formatter
    }()
}

private enum StoryStyle {
    case ribbonLead
    case ribbonSide
    case heroImage
    case sideFeature
    case mainHeadline
    case columnStory
}

private final class StoryButton: NSButton {
    let item: NewsItem
    private let style: StoryStyle
    private var imageTask: Task<Void, Never>?
    private var trackingArea: NSTrackingArea?
    private var originalBackgroundColor: CGColor?
    private var cursorPushed = false

    init(item: NewsItem, style: StoryStyle) {
        self.item = item
        self.style = style
        super.init(frame: .zero)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }

    deinit {
        imageTask?.cancel()
        if cursorPushed {
            NSCursor.pop()
        }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInActiveApp],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        if superview == nil {
            layer?.removeAllAnimations()
            if cursorPushed {
                NSCursor.pop()
                cursorPushed = false
            }
        }
    }

    override func mouseEntered(with event: NSEvent) {
        if !cursorPushed {
            NSCursor.pointingHand.push()
            cursorPushed = true
        }

        layer?.shadowColor = NSColor(red: 0.1, green: 0.08, blue: 0.06, alpha: 1).cgColor
        layer?.shadowOffset = CGSize(width: 0, height: -2)

        layer?.shadowOpacity = 0.15
        let shadowAnim = CABasicAnimation(keyPath: "shadowOpacity")
        shadowAnim.fromValue = 0
        shadowAnim.toValue = 0.15
        shadowAnim.duration = 0.2
        layer?.add(shadowAnim, forKey: "hoverShadowOpacity")

        layer?.shadowRadius = 8
        let radiusAnim = CABasicAnimation(keyPath: "shadowRadius")
        radiusAnim.fromValue = 0
        radiusAnim.toValue = 8
        radiusAnim.duration = 0.2
        layer?.add(radiusAnim, forKey: "hoverShadowRadius")

        let tintColor = hoverTintColor()
        layer?.backgroundColor = tintColor
        let bgAnim = CABasicAnimation(keyPath: "backgroundColor")
        bgAnim.fromValue = originalBackgroundColor
        bgAnim.toValue = tintColor
        bgAnim.duration = 0.2
        layer?.add(bgAnim, forKey: "hoverBackground")
    }

    override func mouseExited(with event: NSEvent) {
        if cursorPushed {
            NSCursor.pop()
            cursorPushed = false
        }

        layer?.shadowOpacity = 0
        let shadowAnim = CABasicAnimation(keyPath: "shadowOpacity")
        shadowAnim.fromValue = 0.15
        shadowAnim.toValue = 0
        shadowAnim.duration = 0.2
        layer?.add(shadowAnim, forKey: "hoverShadowOpacity")

        layer?.shadowRadius = 0
        let radiusAnim = CABasicAnimation(keyPath: "shadowRadius")
        radiusAnim.fromValue = 8
        radiusAnim.toValue = 0
        radiusAnim.duration = 0.2
        layer?.add(radiusAnim, forKey: "hoverShadowRadius")

        layer?.backgroundColor = originalBackgroundColor
        let bgAnim = CABasicAnimation(keyPath: "backgroundColor")
        bgAnim.fromValue = hoverTintColor()
        bgAnim.toValue = originalBackgroundColor
        bgAnim.duration = 0.2
        layer?.add(bgAnim, forKey: "hoverBackground")
    }

    private func hoverTintColor() -> CGColor {
        switch style {
        case .ribbonLead:
            return NSColor(red: 0.82, green: 0.82, blue: 0.92, alpha: 1).cgColor
        case .ribbonSide:
            return NSColor(red: 0.85, green: 0.79, blue: 0.87, alpha: 1).cgColor
        case .heroImage:
            return NSColor.black.withAlphaComponent(0.09).cgColor
        case .sideFeature:
            return NSColor.white.withAlphaComponent(0.65).cgColor
        case .mainHeadline, .columnStory:
            return NSColor(red: 0.95, green: 0.94, blue: 0.91, alpha: 1).cgColor
        }
    }

    private func setup() {
        isBordered = false
        title = ""
        setButtonType(.momentaryChange)
        wantsLayer = true
        translatesAutoresizingMaskIntoConstraints = false

        switch style {
        case .ribbonLead:
            configureRibbonLead()
        case .ribbonSide:
            configureRibbonSide()
        case .heroImage:
            configureHero()
        case .sideFeature:
            configureSideFeature()
        case .mainHeadline:
            configureMainHeadline()
        case .columnStory:
            configureColumnStory()
        }
    }

    private func configureRibbonLead() {
        let bgColor = NSColor(red: 0.86, green: 0.86, blue: 0.94, alpha: 1).cgColor
        layer?.backgroundColor = bgColor
        originalBackgroundColor = bgColor
        layer?.cornerRadius = 2

        let headline = NSTextField(wrappingLabelWithString: item.title)
        headline.font = NSFont(name: "TimesNewRomanPSMT", size: 55) ?? .systemFont(ofSize: 55, weight: .regular)
        headline.textColor = NSColor(red: 0.17, green: 0.26, blue: 0.56, alpha: 1)
        headline.maximumNumberOfLines = 2
        headline.translatesAutoresizingMaskIntoConstraints = false

        addSubview(headline)
        NSLayoutConstraint.activate([
            headline.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            headline.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            headline.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            headline.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10),
        ])
    }

    private func configureRibbonSide() {
        let bgColor = NSColor(red: 0.89, green: 0.83, blue: 0.9, alpha: 1).cgColor
        layer?.backgroundColor = bgColor
        originalBackgroundColor = bgColor
        layer?.cornerRadius = 2

        let kicker = NSTextField(labelWithString: "SPOTLIGHT")
        kicker.font = .systemFont(ofSize: 10, weight: .bold)
        kicker.textColor = NSColor(red: 0.64, green: 0.18, blue: 0.49, alpha: 1)
        kicker.translatesAutoresizingMaskIntoConstraints = false

        let headline = NSTextField(wrappingLabelWithString: item.title)
        headline.font = NSFont(name: "TimesNewRomanPS-BoldMT", size: 22) ?? .systemFont(ofSize: 22, weight: .bold)
        headline.textColor = NSColor(red: 0.34, green: 0.14, blue: 0.41, alpha: 1)
        headline.maximumNumberOfLines = 2
        headline.translatesAutoresizingMaskIntoConstraints = false

        addSubview(kicker)
        addSubview(headline)
        NSLayoutConstraint.activate([
            kicker.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            kicker.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            headline.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            headline.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            headline.topAnchor.constraint(equalTo: kicker.bottomAnchor, constant: 4),
            headline.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -10),
        ])
    }

    private func configureHero() {
        let bgColor = NSColor.black.withAlphaComponent(0.06).cgColor
        layer?.backgroundColor = bgColor
        originalBackgroundColor = bgColor
        layer?.cornerRadius = 2

        let imageView = NSImageView()
        imageView.wantsLayer = true
        imageView.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.1).cgColor
        imageView.layer?.masksToBounds = true
        imageView.imageScaling = .scaleAxesIndependently
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.image = NSImage(systemSymbolName: "photo", accessibilityDescription: nil)
        imageView.contentTintColor = NSColor.black.withAlphaComponent(0.5)

        let caption = NSTextField(wrappingLabelWithString: summaryText(maxLength: 150))
        caption.font = NSFont(name: "TimesNewRomanPSMT", size: 12) ?? .systemFont(ofSize: 12, weight: .regular)
        caption.textColor = NSColor.black.withAlphaComponent(0.78)
        caption.maximumNumberOfLines = 3
        caption.translatesAutoresizingMaskIntoConstraints = false

        addSubview(imageView)
        addSubview(caption)

        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: topAnchor),
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            imageView.heightAnchor.constraint(equalToConstant: 220),

            caption.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 6),
            caption.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 2),
            caption.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -2),
            caption.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor),
        ])

        loadImage(into: imageView)
    }

    private func configureSideFeature() {
        let bgColor = NSColor.white.withAlphaComponent(0.45).cgColor
        layer?.backgroundColor = bgColor
        originalBackgroundColor = bgColor
        layer?.cornerRadius = 2
        layer?.borderColor = NSColor.black.withAlphaComponent(0.08).cgColor
        layer?.borderWidth = 1

        let headline = NSTextField(wrappingLabelWithString: item.title)
        headline.font = NSFont(name: "TimesNewRomanPSMT", size: 20) ?? .systemFont(ofSize: 20, weight: .regular)
        headline.textColor = NSColor.black.withAlphaComponent(0.85)
        headline.maximumNumberOfLines = 5
        headline.translatesAutoresizingMaskIntoConstraints = false

        let summary = NSTextField(wrappingLabelWithString: summaryText(maxLength: 120))
        summary.font = NSFont(name: "TimesNewRomanPSMT", size: 11) ?? .systemFont(ofSize: 11, weight: .regular)
        summary.textColor = NSColor.black.withAlphaComponent(0.72)
        summary.maximumNumberOfLines = 3
        summary.translatesAutoresizingMaskIntoConstraints = false

        addSubview(headline)
        addSubview(summary)
        NSLayoutConstraint.activate([
            headline.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            headline.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            headline.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            summary.topAnchor.constraint(equalTo: headline.bottomAnchor, constant: 4),
            summary.leadingAnchor.constraint(equalTo: headline.leadingAnchor),
            summary.trailingAnchor.constraint(equalTo: headline.trailingAnchor),
            summary.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -8),
        ])
    }

    private func configureMainHeadline() {
        let headline = NSTextField(wrappingLabelWithString: item.title)
        headline.font = NSFont(name: "TimesNewRomanPS-BoldMT", size: 44) ?? .systemFont(ofSize: 44, weight: .bold)
        headline.textColor = NSColor.black.withAlphaComponent(0.86)
        headline.maximumNumberOfLines = 4
        headline.translatesAutoresizingMaskIntoConstraints = false

        let deck = NSTextField(wrappingLabelWithString: summaryText(maxLength: 260))
        deck.font = NSFont(name: "TimesNewRomanPS-BoldMT", size: 18) ?? .systemFont(ofSize: 18, weight: .bold)
        deck.textColor = NSColor.black.withAlphaComponent(0.78)
        deck.maximumNumberOfLines = 3
        deck.translatesAutoresizingMaskIntoConstraints = false

        addSubview(headline)
        addSubview(deck)
        NSLayoutConstraint.activate([
            headline.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 2),
            headline.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -2),
            headline.topAnchor.constraint(equalTo: topAnchor, constant: 2),
            deck.leadingAnchor.constraint(equalTo: headline.leadingAnchor),
            deck.trailingAnchor.constraint(equalTo: headline.trailingAnchor),
            deck.topAnchor.constraint(equalTo: headline.bottomAnchor, constant: 5),
            deck.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -4),
        ])
    }

    private func configureColumnStory() {
        let headline = NSTextField(wrappingLabelWithString: item.title)
        headline.font = NSFont(name: "TimesNewRomanPS-BoldMT", size: 23) ?? .systemFont(ofSize: 23, weight: .bold)
        headline.textColor = NSColor.black.withAlphaComponent(0.85)
        headline.maximumNumberOfLines = 3
        headline.translatesAutoresizingMaskIntoConstraints = false

        let body = NSTextField(wrappingLabelWithString: summaryText(maxLength: 300))
        body.font = NSFont(name: "TimesNewRomanPSMT", size: 14) ?? .systemFont(ofSize: 14, weight: .regular)
        body.textColor = NSColor.black.withAlphaComponent(0.75)
        body.maximumNumberOfLines = 4
        body.translatesAutoresizingMaskIntoConstraints = false

        let host = item.url.host()?.replacingOccurrences(of: "www.", with: "") ?? item.source.rawValue
        let byline = NSTextField(labelWithString: host)
        byline.font = NSFont(name: "TimesNewRomanPS-ItalicMT", size: 11) ?? .systemFont(ofSize: 11, weight: .regular)
        byline.textColor = NSColor.black.withAlphaComponent(0.6)
        byline.translatesAutoresizingMaskIntoConstraints = false

        addSubview(headline)
        addSubview(body)
        addSubview(byline)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(greaterThanOrEqualToConstant: 150),
            headline.topAnchor.constraint(equalTo: topAnchor, constant: 2),
            headline.leadingAnchor.constraint(equalTo: leadingAnchor),
            headline.trailingAnchor.constraint(equalTo: trailingAnchor),
            body.topAnchor.constraint(equalTo: headline.bottomAnchor, constant: 5),
            body.leadingAnchor.constraint(equalTo: headline.leadingAnchor),
            body.trailingAnchor.constraint(equalTo: headline.trailingAnchor),
            byline.topAnchor.constraint(equalTo: body.bottomAnchor, constant: 4),
            byline.leadingAnchor.constraint(equalTo: headline.leadingAnchor),
            byline.trailingAnchor.constraint(equalTo: headline.trailingAnchor),
            byline.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -2),
        ])
    }

    private func summaryText(maxLength: Int) -> String {
        let raw = item.summary ?? "Open for full story and latest reporting."
        if raw.count <= maxLength { return raw }
        let end = raw.index(raw.startIndex, offsetBy: maxLength)
        return "\(raw[..<end])..."
    }

    private func loadImage(into imageView: NSImageView) {
        guard let url = item.imageURL else { return }
        imageTask?.cancel()
        imageTask = Task { [weak imageView] in
            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                guard !Task.isCancelled else { return }
                guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else { return }
                guard let image = NSImage(data: data) else { return }
                await MainActor.run {
                    imageView?.image = image
                }
            } catch {
                // keep placeholder
            }
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}

private final class FlippedView: NSView {
    override var isFlipped: Bool { true }
}
