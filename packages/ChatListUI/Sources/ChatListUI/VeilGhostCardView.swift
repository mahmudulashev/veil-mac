import Cocoa
import TGUIKit
import TelegramCore

final class VeilGhostCardView: Control {
    static let height: CGFloat = 72

    private let gradientLayer = CAGradientLayer()
    private let glowLayer = CAGradientLayer()
    private let captionView = TextView()
    private let titleView = TextView()
    private let pillView = View()
    private let pillTextView = TextView()
    private var listener: Int?

    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 20
        if #available(macOS 10.15, *) {
            layer?.cornerCurve = .continuous
        }
        layer?.masksToBounds = true

        gradientLayer.startPoint = CGPoint(x: 0, y: 1)
        gradientLayer.endPoint = CGPoint(x: 1, y: 0)
        layer?.addSublayer(gradientLayer)

        glowLayer.type = .radial
        glowLayer.startPoint = CGPoint(x: 0.2, y: 0.8)
        glowLayer.endPoint = CGPoint(x: 0.9, y: -0.2)
        layer?.addSublayer(glowLayer)

        for view in [captionView, titleView, pillTextView] {
            view.userInteractionEnabled = false
            view.isSelectable = false
            view.backgroundColor = .clear
        }
        pillView.layer?.cornerRadius = 15
        pillView.layer?.borderWidth = 1
        pillView.layer?.borderColor = NSColor.white.withAlphaComponent(0.35).cgColor
        pillView.backgroundColor = NSColor.white.withAlphaComponent(0.14)
        pillView.isEventLess = true
        pillView.addSubview(pillTextView)

        addSubview(captionView)
        addSubview(titleView)
        addSubview(pillView)

        scaleOnClick = true
        set(handler: { _ in
            GhostMode.update { $0.enabled.toggle() }
        }, for: .Click)

        listener = GhostMode.addListener { [weak self] _ in
            DispatchQueue.main.async {
                self?.updateGhostState()
            }
        }
        setAccessibilityRole(.button)
        updateGhostState()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        if let listener {
            GhostMode.removeListener(listener)
        }
    }

    private func updateGhostState() {
        let enabled = GhostMode.settings.enabled
        if enabled {
            gradientLayer.colors = [veilColor(0x0B1030).cgColor, veilColor(0x1B2FA8).cgColor, veilColor(0x3A6DFF).cgColor]
            glowLayer.colors = [veilColor(0x82AAFF, 0.75).cgColor, veilColor(0x82AAFF, 0).cgColor]
        } else {
            gradientLayer.colors = [veilColor(0x3A4460).cgColor, veilColor(0x5E6883).cgColor, veilColor(0x8A93A8).cgColor]
            glowLayer.colors = [veilColor(0xFFFFFF, 0.25).cgColor, veilColor(0xFFFFFF, 0).cgColor]
        }
        gradientLayer.locations = [0, 0.6, 1]

        let caption = TextViewLayout(.initialize(string: "Ghost rejimi", color: NSColor.white.withAlphaComponent(0.75), font: .normal(12)))
        caption.measure(width: .greatestFiniteMagnitude)
        captionView.update(caption)
        captionView.setFrameSize(caption.layoutSize)

        let title = TextViewLayout(.initialize(string: enabled ? "Ko'rinmassiz" : "Ko'rinasiz", color: .white, font: .medium(22)))
        title.measure(width: .greatestFiniteMagnitude)
        titleView.update(title)
        titleView.setFrameSize(title.layoutSize)

        let pill = TextViewLayout(.initialize(string: enabled ? "O'chirish" : "Yoqish", color: .white, font: .medium(12)))
        pill.measure(width: .greatestFiniteMagnitude)
        pillTextView.update(pill)
        pillTextView.setFrameSize(pill.layoutSize)

        toolTip = enabled ? "Ghost rejimini o'chirish (⌘⇧G)" : "Ghost rejimini yoqish (⌘⇧G)"
        setAccessibilityLabel(enabled ? "Ghost rejimi: yoqilgan" : "Ghost rejimi: o'chiq")
        needsLayout = true
    }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        gradientLayer.frame = bounds
        glowLayer.frame = bounds
        CATransaction.commit()

        captionView.setFrameOrigin(NSMakePoint(16, 14))
        titleView.setFrameOrigin(NSMakePoint(16, captionView.frame.maxY + 2))

        let pillSize = NSMakeSize(pillTextView.frame.width + 24, 30)
        pillView.frame = NSMakeRect(frame.width - pillSize.width - 14, floor((frame.height - pillSize.height) / 2), pillSize.width, pillSize.height)
        pillTextView.setFrameOrigin(NSMakePoint(12, floor((pillSize.height - pillTextView.frame.height) / 2)))
    }
}

private func veilColor(_ hex: UInt32, _ alpha: CGFloat = 1.0) -> NSColor {
    return NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}
