import Cocoa
import TGUIKit
import TelegramTheme
import GeneralRows

final class GhostHeroRowItem: GeneralRowItem {
    let ghostEnabled: Bool
    let activeCount: Int
    let toggle: () -> Void

    init(_ initialSize: NSSize, stableId: AnyHashable, enabled: Bool, activeCount: Int, viewType: GeneralViewType, toggle: @escaping () -> Void) {
        self.ghostEnabled = enabled
        self.activeCount = activeCount
        self.toggle = toggle
        super.init(initialSize, height: 184, stableId: stableId, viewType: viewType)
    }

    override func viewClass() -> AnyClass {
        return GhostHeroRowView.self
    }

    override var accessibilityLabel: String? {
        return ghostEnabled ? "Ghost rejimi yoqilgan" : "Ghost rejimi o'chiq"
    }
}

private func veilColor(_ hex: UInt32, alpha: CGFloat = 1) -> NSColor {
    return NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

private final class GhostHeroRowView: GeneralContainableRowView {
    private let gradientLayer = CAGradientLayer()
    private let glowLayer = CAGradientLayer()
    private let symbolView = ImageView()
    private let dotView = View()
    private let labelView = TextView()
    private let titleView = TextView()
    private let subtitleView = TextView()
    private let button = Control()
    private let buttonText = TextView()

    private static let cornerRadius: CGFloat = 22
    private static let padding: CGFloat = 22

    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        gradientLayer.startPoint = CGPoint(x: 0, y: 1)
        gradientLayer.endPoint = CGPoint(x: 1, y: 0)
        glowLayer.type = .radial
        glowLayer.startPoint = CGPoint(x: 0.5, y: 0.5)
        glowLayer.endPoint = CGPoint(x: 1, y: 1)
        containerView.cornerRadius = GhostHeroRowView.cornerRadius
        containerView.layer?.insertSublayer(gradientLayer, at: 0)
        containerView.layer?.insertSublayer(glowLayer, at: 1)
        if #available(macOS 10.15, *) {
            gradientLayer.cornerCurve = .continuous
            button.layer?.cornerCurve = .continuous
        }
        gradientLayer.masksToBounds = true

        dotView.setFrameSize(NSMakeSize(8, 8))
        dotView.layer?.cornerRadius = 4
        dotView.layer?.masksToBounds = false
        dotView.isEventLess = true

        for textView in [labelView, titleView, subtitleView, buttonText] {
            textView.userInteractionEnabled = false
            textView.isSelectable = false
            textView.backgroundColor = .clear
        }

        symbolView.isEventLess = true

        button.addSubview(buttonText)
        button.scaleOnClick = true
        button.set(handler: { [weak self] _ in
            (self?.item as? GhostHeroRowItem)?.toggle()
        }, for: .Click)

        containerView.addSubview(symbolView)
        containerView.addSubview(dotView)
        containerView.addSubview(labelView)
        containerView.addSubview(titleView)
        containerView.addSubview(subtitleView)
        containerView.addSubview(button)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private var isOn: Bool {
        return (item as? GhostHeroRowItem)?.ghostEnabled ?? false
    }

    private var cardColor: NSColor {
        if isOn {
            return veilColor(0x0E1430)
        }
        return theme.colors.isDark ? theme.colors.background : .white
    }

    override var backdorColor: NSColor {
        return cardColor
    }

    override func updateColors() {
        super.updateColors()
        borderView.isHidden = true
        backgroundColor = (item as? GeneralRowItem)?.viewType.rowBackground ?? .clear
        containerView.backgroundColor = cardColor
        let glow = veilColor(0x4B7DFF)
        if isOn {
            gradientLayer.colors = [veilColor(0x0E1430).cgColor, veilColor(0x1C2A6E).cgColor]
            glowLayer.colors = [glow.withAlphaComponent(0.55).cgColor, glow.withAlphaComponent(0).cgColor]
        } else {
            gradientLayer.colors = [cardColor.cgColor, cardColor.cgColor]
            glowLayer.colors = [glow.withAlphaComponent(theme.colors.isDark ? 0.25 : 0.16).cgColor, glow.withAlphaComponent(0).cgColor]
        }
    }

    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        guard let item = item as? GhostHeroRowItem else {
            return
        }
        let on = item.ghostEnabled
        let ink = veilColor(0x0E1430)
        let accent = veilColor(0x2F5BFF)
        let glow = veilColor(0x73A0FF)

        let primary: NSColor = on ? .white : theme.colors.text
        let secondary: NSColor = on ? NSColor.white.withAlphaComponent(0.66) : theme.colors.grayText

        dotView.backgroundColor = on ? glow : theme.colors.grayIcon.withAlphaComponent(0.6)
        dotView.layer?.shadowColor = glow.cgColor
        dotView.layer?.shadowRadius = 5
        dotView.layer?.shadowOffset = .zero
        dotView.layer?.shadowOpacity = on ? 1 : 0

        let label = NSAttributedString(string: on ? "GHOST · FAOL" : "GHOST · O'CHIQ", attributes: [
            .font: NSFont.systemFont(ofSize: 11, weight: .semibold),
            .foregroundColor: on ? glow : theme.colors.grayText,
            .kern: 1.2
        ])
        let labelLayout = TextViewLayout(label)
        labelLayout.measure(width: .greatestFiniteMagnitude)
        labelView.update(labelLayout)

        let textWidth = max(100, item.blockWidth - GhostHeroRowView.padding * 2 - 96)

        let titleLayout = TextViewLayout(.initialize(string: on ? "Siz ko'rinmaysiz" : "Siz hammaga ko'rinasiz", color: primary, font: NSFont.systemFont(ofSize: 26, weight: .bold)), maximumNumberOfLines: 2)
        titleLayout.measure(width: textWidth)
        titleView.update(titleLayout)

        let subtitle = on ? "\(item.activeCount) ta himoya ishlayapti · faqat shu Mac'da" : "Yoqing: o'qish, onlayn, yozish va storislar yashiriladi"
        let subtitleLayout = TextViewLayout(.initialize(string: subtitle, color: secondary, font: .normal(13)), maximumNumberOfLines: 2)
        subtitleLayout.measure(width: textWidth)
        subtitleView.update(subtitleLayout)

        let buttonLayout = TextViewLayout(.initialize(string: on ? "O'chirish" : "Ghost'ni yoqish", color: on ? ink : .white, font: .medium(13)))
        buttonLayout.measure(width: .greatestFiniteMagnitude)
        buttonText.update(buttonLayout)
        button.backgroundColor = on ? .white : accent
        button.setFrameSize(NSMakeSize(buttonLayout.layoutSize.width + 36, 36))
        button.layer?.cornerRadius = 18

        let config = NSImage.SymbolConfiguration(pointSize: 84, weight: .semibold)
            .applying(NSImage.SymbolConfiguration(paletteColors: [on ? NSColor.white.withAlphaComponent(0.1) : accent.withAlphaComponent(0.1)]))
        if let symbol = NSImage(systemSymbolName: on ? "eye.slash.fill" : "eye.fill", accessibilityDescription: nil)?.withSymbolConfiguration(config) {
            var rect = CGRect(origin: .zero, size: symbol.size)
            symbolView.image = symbol.cgImage(forProposedRect: &rect, context: nil, hints: nil)
            symbolView.setFrameSize(symbol.size)
        }

        updateColors()
        needsLayout = true
    }

    override func layout() {
        super.layout()
        let bounds = containerView.bounds
        let padding = GhostHeroRowView.padding
        let radius = GhostHeroRowView.cornerRadius

        gradientLayer.frame = bounds
        gradientLayer.cornerRadius = radius
        glowLayer.frame = NSMakeRect(bounds.width - 260, -120, 340, 300)

        symbolView.setFrameOrigin(NSMakePoint(bounds.width - symbolView.frame.width - padding + 6, floor((bounds.height - symbolView.frame.height) / 2) - 6))

        labelView.setFrameSize(labelView.textLayout?.layoutSize ?? .zero)
        dotView.setFrameOrigin(NSMakePoint(padding, padding + floor((labelView.frame.height - dotView.frame.height) / 2)))
        labelView.setFrameOrigin(NSMakePoint(dotView.frame.maxX + 8, padding))

        titleView.setFrameSize(titleView.textLayout?.layoutSize ?? .zero)
        titleView.setFrameOrigin(NSMakePoint(padding, labelView.frame.maxY + 12))

        subtitleView.setFrameSize(subtitleView.textLayout?.layoutSize ?? .zero)
        subtitleView.setFrameOrigin(NSMakePoint(padding, titleView.frame.maxY + 4))

        button.setFrameOrigin(NSMakePoint(padding, bounds.height - padding - button.frame.height))
        buttonText.setFrameSize(buttonText.textLayout?.layoutSize ?? .zero)
        buttonText.center()
    }
}
