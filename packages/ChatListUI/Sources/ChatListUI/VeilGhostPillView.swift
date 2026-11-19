import Cocoa
import TGUIKit
import TelegramCore
import TelegramTheme

final class VeilGhostPillView: Control {
    static let height: CGFloat = 28

    private let dotView = View()
    private let textView = TextView()
    private var listener: Int?

    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        if #available(macOS 10.15, *) {
            layer?.cornerCurve = .continuous
        }
        dotView.setFrameSize(NSMakeSize(7, 7))
        dotView.layer?.cornerRadius = 3.5
        dotView.isEventLess = true
        textView.userInteractionEnabled = false
        textView.isSelectable = false
        textView.backgroundColor = .clear
        addSubview(dotView)
        addSubview(textView)

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

    var preferredWidth: CGFloat {
        return 11 + dotView.frame.width + 6 + textView.frame.width + 12
    }

    private func updateGhostState() {
        let enabled = GhostMode.settings.enabled
        let ink = NSColor(srgbRed: 14.0 / 255.0, green: 20.0 / 255.0, blue: 48.0 / 255.0, alpha: 1.0)
        let glow = NSColor(srgbRed: 0.45, green: 0.6, blue: 1.0, alpha: 1.0)

        backgroundColor = enabled ? ink : .clear
        layer?.cornerRadius = VeilGhostPillView.height / 2
        layer?.borderWidth = enabled ? 0 : 1
        layer?.borderColor = theme.colors.text.withAlphaComponent(0.14).cgColor

        dotView.backgroundColor = enabled ? glow : theme.colors.grayIcon.withAlphaComponent(0.6)
        dotView.layer?.shadowColor = glow.cgColor
        dotView.layer?.shadowRadius = 4
        dotView.layer?.shadowOffset = .zero
        dotView.layer?.shadowOpacity = enabled ? 0.9 : 0
        dotView.layer?.masksToBounds = false

        let layout = TextViewLayout(.initialize(string: "Ghost", color: enabled ? .white : theme.colors.grayText, font: .medium(12)))
        layout.measure(width: .greatestFiniteMagnitude)
        textView.update(layout)
        textView.setFrameSize(layout.layoutSize)

        toolTip = enabled ? "Ghost yoqilgan, o'chirish uchun bosing (⌘⇧G)" : "Ghost o'chiq, yoqish uchun bosing (⌘⇧G)"
        setAccessibilityLabel(enabled ? "Ghost rejimi: yoqilgan" : "Ghost rejimi: o'chiq")
        needsLayout = true
    }

    override func layout() {
        super.layout()
        dotView.setFrameOrigin(NSMakePoint(11, floor((frame.height - dotView.frame.height) / 2)))
        textView.setFrameOrigin(NSMakePoint(dotView.frame.maxX + 6, floor((frame.height - textView.frame.height) / 2)))
    }
}
