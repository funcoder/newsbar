import AppKit

final class BubbleWindowController {
    private var window: NSPanel?
    private var currentBubble: BubbleView?
    private var pendingHeadlines: [NewsItem] = []
    private var displayTimer: Timer?
    private var screenAnchor: NSRect = .zero
    private let bubbleWidth: CGFloat = 300
    private let panelWidth: CGFloat = 320

    func show(headlines: [NewsItem], below button: NSStatusBarButton) {
        cancelPending()
        dismiss(animated: false)

        guard !headlines.isEmpty else { return }
        guard let buttonWindow = button.window else { return }

        screenAnchor = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
        pendingHeadlines = headlines

        showNext()
    }

    func dismiss(animated: Bool = true) {
        cancelPending()

        guard let panel = window, let bubble = currentBubble else {
            tearDown()
            return
        }

        if animated {
            // Slide the whole window up behind the menu bar
            let targetFrame = NSRect(
                x: panel.frame.origin.x,
                y: screenAnchor.minY,
                width: panelWidth,
                height: 0
            )
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = Constants.bubbleAnimationDuration
                context.timingFunction = CAMediaTimingFunction(name: .easeIn)
                panel.animator().setFrame(targetFrame, display: true)
                bubble.animator().alphaValue = 0
            }, completionHandler: { [weak self] in
                self?.tearDown()
            })
        } else {
            tearDown()
        }
    }

    // MARK: - Carousel

    private func showNext() {
        guard !pendingHeadlines.isEmpty else {
            dismiss(animated: false)
            return
        }

        let item = pendingHeadlines.removeFirst()

        let bubble = BubbleView(item: item, displayDuration: Constants.bubbleDisplayDuration) { [weak self] clickedItem in
            NSWorkspace.shared.open(clickedItem.url)
            self?.dismiss(animated: true)
        }
        bubble.translatesAutoresizingMaskIntoConstraints = false

        // Compute bubble height by laying it out at the target width
        let widthConstraint = bubble.widthAnchor.constraint(equalToConstant: bubbleWidth)
        widthConstraint.isActive = true
        bubble.layoutSubtreeIfNeeded()
        let bubbleHeight = bubble.fittingSize.height

        let screenWidth = NSScreen.main?.frame.width ?? 1440
        let xOrigin = (screenWidth - panelWidth) / 2
        // Final position: just below the menu bar
        let finalY = screenAnchor.minY - bubbleHeight - 14
        // Start position: hidden behind menu bar
        let startY = screenAnchor.minY

        // Slide out old bubble first, then show new
        if let oldPanel = window, let oldBubble = currentBubble {
            let hideFrame = NSRect(x: oldPanel.frame.origin.x, y: screenAnchor.minY, width: panelWidth, height: 0)
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = Constants.bubbleAnimationDuration
                context.timingFunction = CAMediaTimingFunction(name: .easeIn)
                oldPanel.animator().setFrame(hideFrame, display: true)
                oldBubble.animator().alphaValue = 0
            }, completionHandler: { [weak self] in
                oldBubble.removeFromSuperview()
                oldPanel.orderOut(nil)
                self?.presentBubble(bubble, x: xOrigin, startY: startY, finalY: finalY, height: bubbleHeight)
            })
        } else {
            presentBubble(bubble, x: xOrigin, startY: startY, finalY: finalY, height: bubbleHeight)
        }
    }

    private func presentBubble(_ bubble: BubbleView, x: CGFloat, startY: CGFloat, finalY: CGFloat, height: CGFloat) {
        let panel = NSPanel(
            contentRect: NSRect(x: x, y: startY, width: panelWidth, height: 0),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = .floating
        panel.hasShadow = false
        panel.isMovable = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let contentView = NSView()
        contentView.wantsLayer = true
        panel.contentView = contentView
        contentView.addSubview(bubble)

        NSLayoutConstraint.activate([
            bubble.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 10),
            bubble.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -10),
            bubble.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),
        ])

        self.window = panel
        self.currentBubble = bubble

        panel.orderFront(nil)

        // Animate window frame from 0-height to full height (slides down from menu bar)
        let finalFrame = NSRect(x: x, y: finalY, width: panelWidth, height: height + 14)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = Constants.bubbleAnimationDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().setFrame(finalFrame, display: true)
        }

        if Settings.soundEnabled {
            NSSound(named: .init("Bubble"))?.play()
        }

        displayTimer = Timer.scheduledTimer(withTimeInterval: Constants.bubbleDisplayDuration, repeats: false) { [weak self] _ in
            guard let self else { return }
            if self.pendingHeadlines.isEmpty {
                self.dismiss(animated: true)
            } else {
                self.showNext()
            }
        }
    }

    // MARK: - Private

    private func cancelPending() {
        displayTimer?.invalidate()
        displayTimer = nil
        pendingHeadlines.removeAll()
    }

    private func tearDown() {
        currentBubble?.removeFromSuperview()
        currentBubble = nil
        window?.orderOut(nil)
        window = nil
    }
}

// MARK: - BubbleView

private final class BubbleView: NSView {
    let item: NewsItem
    private let onClick: (NewsItem) -> Void
    private let displayDuration: TimeInterval
    private var imageLoadTask: Task<Void, Never>?
    private weak var imageView: NSImageView?
    private weak var progressContainerView: NSView?
    private let progressLayer = CALayer()

    init(item: NewsItem, displayDuration: TimeInterval, onClick: @escaping (NewsItem) -> Void) {
        self.item = item
        self.displayDuration = displayDuration
        self.onClick = onClick
        super.init(frame: NSRect(x: 0, y: 0, width: 300, height: 40))

        wantsLayer = true
        setupViews()
        setupTracking()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }

    private func setupViews() {
        let effect = NSVisualEffectView()
        effect.material = .popover
        effect.state = .active
        effect.wantsLayer = true
        effect.layer?.cornerRadius = 16
        effect.layer?.masksToBounds = true
        effect.layer?.borderWidth = 1
        effect.layer?.borderColor = sourceColor(item.source).withAlphaComponent(0.18).cgColor
        effect.translatesAutoresizingMaskIntoConstraints = false

        let backgroundTint = NSView()
        backgroundTint.wantsLayer = true
        backgroundTint.translatesAutoresizingMaskIntoConstraints = false
        backgroundTint.layer?.backgroundColor = sourceColor(item.source).withAlphaComponent(0.06).cgColor

        let sourceLabel = NSTextField(labelWithString: item.source.rawValue.uppercased())
        sourceLabel.font = .systemFont(ofSize: 10, weight: .semibold)
        sourceLabel.textColor = sourceColor(item.source).blended(withFraction: 0.2, of: .labelColor) ?? .labelColor
        sourceLabel.alignment = .center
        sourceLabel.wantsLayer = true
        sourceLabel.layer?.backgroundColor = sourceColor(item.source).withAlphaComponent(0.18).cgColor
        sourceLabel.layer?.cornerRadius = 10
        sourceLabel.layer?.masksToBounds = true
        sourceLabel.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = NSTextField(wrappingLabelWithString: item.title)
        titleLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        titleLabel.textColor = .labelColor
        titleLabel.isSelectable = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.maximumNumberOfLines = 4

        let hintLabel = NSTextField(labelWithString: "Open story")
        hintLabel.font = .systemFont(ofSize: 11, weight: .medium)
        hintLabel.textColor = .secondaryLabelColor
        hintLabel.translatesAutoresizingMaskIntoConstraints = false

        let chevron = NSImageView(image: NSImage(systemSymbolName: "arrow.up.right", accessibilityDescription: nil) ?? NSImage())
        chevron.contentTintColor = .secondaryLabelColor
        chevron.translatesAutoresizingMaskIntoConstraints = false

        let metaRow = NSStackView(views: [hintLabel, chevron])
        metaRow.orientation = .horizontal
        metaRow.alignment = .centerY
        metaRow.spacing = 4
        metaRow.translatesAutoresizingMaskIntoConstraints = false

        let progressContainer = NSView()
        progressContainer.wantsLayer = true
        progressContainer.layer?.cornerRadius = 1.5
        progressContainer.layer?.masksToBounds = true
        progressContainer.layer?.backgroundColor = NSColor.labelColor.withAlphaComponent(0.12).cgColor
        progressContainer.translatesAutoresizingMaskIntoConstraints = false
        progressContainer.isHidden = displayDuration <= 0
        self.progressContainerView = progressContainer

        addSubview(effect)
        effect.addSubview(backgroundTint)
        effect.addSubview(sourceLabel)
        effect.addSubview(titleLabel)
        effect.addSubview(metaRow)
        effect.addSubview(progressContainer)

        var imageBottomAnchor = titleLabel.topAnchor
        if item.imageURL != nil {
            let mediaContainer = NSView()
            mediaContainer.wantsLayer = true
            mediaContainer.layer?.cornerRadius = 10
            mediaContainer.layer?.masksToBounds = true
            mediaContainer.layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.6).cgColor
            mediaContainer.translatesAutoresizingMaskIntoConstraints = false

            let imageView = NSImageView()
            imageView.imageScaling = .scaleAxesIndependently
            imageView.animates = true
            imageView.translatesAutoresizingMaskIntoConstraints = false
            imageView.contentTintColor = .tertiaryLabelColor
            imageView.image = NSImage(systemSymbolName: "photo", accessibilityDescription: nil)
            self.imageView = imageView

            mediaContainer.addSubview(imageView)
            effect.addSubview(mediaContainer)

            NSLayoutConstraint.activate([
                mediaContainer.topAnchor.constraint(equalTo: sourceLabel.bottomAnchor, constant: 8),
                mediaContainer.leadingAnchor.constraint(equalTo: effect.leadingAnchor, constant: 12),
                mediaContainer.trailingAnchor.constraint(equalTo: effect.trailingAnchor, constant: -12),
                mediaContainer.heightAnchor.constraint(equalToConstant: 132),

                imageView.topAnchor.constraint(equalTo: mediaContainer.topAnchor),
                imageView.leadingAnchor.constraint(equalTo: mediaContainer.leadingAnchor),
                imageView.trailingAnchor.constraint(equalTo: mediaContainer.trailingAnchor),
                imageView.bottomAnchor.constraint(equalTo: mediaContainer.bottomAnchor),
            ])

            imageBottomAnchor = mediaContainer.bottomAnchor
            loadImageIfNeeded()
        }

        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.35)
        shadow.shadowBlurRadius = 16
        shadow.shadowOffset = NSSize(width: 0, height: -6)
        self.shadow = shadow

        NSLayoutConstraint.activate([
            effect.topAnchor.constraint(equalTo: topAnchor),
            effect.leadingAnchor.constraint(equalTo: leadingAnchor),
            effect.trailingAnchor.constraint(equalTo: trailingAnchor),
            effect.bottomAnchor.constraint(equalTo: bottomAnchor),

            backgroundTint.topAnchor.constraint(equalTo: effect.topAnchor),
            backgroundTint.leadingAnchor.constraint(equalTo: effect.leadingAnchor),
            backgroundTint.trailingAnchor.constraint(equalTo: effect.trailingAnchor),
            backgroundTint.bottomAnchor.constraint(equalTo: effect.bottomAnchor),

            sourceLabel.topAnchor.constraint(equalTo: effect.topAnchor, constant: 10),
            sourceLabel.leadingAnchor.constraint(equalTo: effect.leadingAnchor, constant: 12),
            sourceLabel.heightAnchor.constraint(equalToConstant: 20),
            sourceLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 86),

            titleLabel.topAnchor.constraint(equalTo: imageBottomAnchor, constant: 10),
            titleLabel.leadingAnchor.constraint(equalTo: effect.leadingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: effect.trailingAnchor, constant: -12),

            metaRow.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            metaRow.leadingAnchor.constraint(equalTo: effect.leadingAnchor, constant: 12),
            metaRow.bottomAnchor.constraint(equalTo: progressContainer.topAnchor, constant: -10),

            progressContainer.leadingAnchor.constraint(equalTo: effect.leadingAnchor, constant: 12),
            progressContainer.trailingAnchor.constraint(equalTo: effect.trailingAnchor, constant: -12),
            progressContainer.bottomAnchor.constraint(equalTo: effect.bottomAnchor, constant: -10),
            progressContainer.heightAnchor.constraint(equalToConstant: 3),
        ])

        configureProgressLayerIfNeeded()
        startProgressAnimationIfNeeded()
    }

    deinit {
        imageLoadTask?.cancel()
    }

    private func setupTracking() {
        let area = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
    }

    override func mouseEntered(with event: NSEvent) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.18
            self.animator().alphaValue = 0.94
        }
    }

    override func mouseExited(with event: NSEvent) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            self.animator().alphaValue = 1.0
        }
    }

    override func mouseDown(with event: NSEvent) {
        onClick(item)
    }

    private func configureProgressLayerIfNeeded() {
        guard displayDuration > 0, let containerLayer = progressContainerView?.layer else { return }
        progressLayer.removeFromSuperlayer()
        progressLayer.frame = containerLayer.bounds
        progressLayer.backgroundColor = sourceColor(item.source).withAlphaComponent(0.85).cgColor
        progressLayer.anchorPoint = CGPoint(x: 0, y: 0.5)
        progressLayer.position = CGPoint(x: 0, y: containerLayer.bounds.midY)
        containerLayer.addSublayer(progressLayer)
    }

    override func layout() {
        super.layout()
        guard let containerLayer = progressContainerView?.layer else { return }
        progressLayer.frame = containerLayer.bounds
        progressLayer.position = CGPoint(x: 0, y: containerLayer.bounds.midY)
    }

    private func startProgressAnimationIfNeeded() {
        guard displayDuration > 0 else { return }

        let animation = CABasicAnimation(keyPath: "transform.scale.x")
        animation.fromValue = 1.0
        animation.toValue = 0.0
        animation.duration = displayDuration
        animation.timingFunction = CAMediaTimingFunction(name: .linear)
        animation.fillMode = .forwards
        animation.isRemovedOnCompletion = false
        progressLayer.add(animation, forKey: "countdown")
    }

    private func loadImageIfNeeded() {
        guard let url = item.imageURL else { return }
        imageLoadTask?.cancel()
        imageLoadTask = Task { [weak self] in
            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                guard !Task.isCancelled else { return }
                guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else { return }
                guard let image = NSImage(data: data) else { return }
                await MainActor.run {
                    self?.imageView?.image = image
                }
            } catch {
                // Keep placeholder icon when image download fails.
            }
        }
    }

    private func sourceColor(_ source: NewsSource) -> NSColor {
        switch source {
        case .bbc: return NSColor(red: 0.73, green: 0.04, blue: 0.04, alpha: 1)
        case .hackerNews: return NSColor(red: 1.0, green: 0.4, blue: 0.0, alpha: 1)
        }
    }
}
