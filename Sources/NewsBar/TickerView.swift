import AppKit
import QuartzCore

final class TickerView: NSView {
    private let textLayer = CATextLayer()
    private let maskLayer = CAGradientLayer()
    private var textWidth: CGFloat = 0
    private var currentText = ""
    private let pixelsPerSecond: CGFloat = 60
    private var finishWorkItem: DispatchWorkItem?

    var onFinished: (() -> Void)?

    override init(frame: NSRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        wantsLayer = true
        layer?.masksToBounds = true

        textLayer.contentsScale = NSScreen.main?.backingScaleFactor ?? 2.0
        textLayer.fontSize = 12
        textLayer.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        textLayer.foregroundColor = NSColor.controlTextColor.cgColor
        textLayer.alignmentMode = .left
        textLayer.anchorPoint = .zero
        textLayer.actions = ["position": NSNull(), "bounds": NSNull()]
        layer?.addSublayer(textLayer)

        maskLayer.colors = [
            NSColor.clear.cgColor,
            NSColor.black.cgColor,
            NSColor.black.cgColor,
            NSColor.clear.cgColor
        ]
        maskLayer.locations = [0, 0.03, 0.97, 1.0]
        maskLayer.startPoint = CGPoint(x: 0, y: 0.5)
        maskLayer.endPoint = CGPoint(x: 1, y: 0.5)
        layer?.mask = maskLayer
    }

    override func layout() {
        super.layout()
        maskLayer.frame = bounds
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        effectiveAppearance.performAsCurrentDrawingAppearance {
            textLayer.foregroundColor = NSColor.controlTextColor.cgColor
        }
    }

    func update(headlines: [String]) {
        let joined = headlines.joined(separator: Constants.headlineSeparator)
        guard !joined.isEmpty else {
            showStatic("NewsBar — Loading...")
            return
        }

        let displayText = joined + Constants.headlineSeparator
        guard displayText != currentText else { return }
        currentText = displayText

        let doubled = displayText + displayText
        let size = (doubled as NSString).size(
            withAttributes: [.font: NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)]
        )
        textWidth = (displayText as NSString).size(
            withAttributes: [.font: NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)]
        ).width

        textLayer.string = doubled
        textLayer.frame = CGRect(x: 0, y: -1, width: size.width, height: bounds.height)

        startAnimation()
    }

    func stop() {
        finishWorkItem?.cancel()
        finishWorkItem = nil
        textLayer.removeAllAnimations()
        textLayer.string = ""
        currentText = ""
    }

    private func showStatic(_ text: String) {
        currentText = ""
        finishWorkItem?.cancel()
        finishWorkItem = nil
        textLayer.removeAllAnimations()
        textLayer.string = text
        let size = (text as NSString).size(
            withAttributes: [.font: NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)]
        )
        textLayer.frame = CGRect(x: 0, y: -1, width: size.width, height: bounds.height)
    }

    private func startAnimation() {
        finishWorkItem?.cancel()
        textLayer.removeAllAnimations()

        let singleLoopDuration = Double(textWidth) / Double(pixelsPerSecond)
        let totalDuration = singleLoopDuration * Double(Constants.tickerLoops)

        let animation = CABasicAnimation(keyPath: "position.x")
        animation.fromValue = 0
        animation.toValue = -textWidth
        animation.duration = singleLoopDuration
        animation.repeatCount = .infinity
        animation.timingFunction = CAMediaTimingFunction(name: .linear)

        textLayer.add(animation, forKey: "scroll")

        let workItem = DispatchWorkItem { [weak self] in
            self?.onFinished?()
        }
        finishWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + totalDuration, execute: workItem)
    }
}
