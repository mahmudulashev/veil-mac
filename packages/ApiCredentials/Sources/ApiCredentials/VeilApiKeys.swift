import Cocoa
import Security

public enum VeilApiKeys {
    private static let service = "uz.veil.telegram.api"

    private static func read(_ account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess, let data = result as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    private static func write(_ value: String, _ account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
        var add = query
        add[kSecValueData as String] = Data(value.utf8)
        add[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        SecItemAdd(add as CFDictionary, nil)
    }

    public static func clear() {
        for account in ["api_id", "api_hash"] {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: account
            ]
            SecItemDelete(query as CFDictionary)
        }
    }

    public static var current: (id: Int32, hash: String)? {
        guard let idString = read("api_id"), let id = Int32(idString), let hash = read("api_hash"), !hash.isEmpty else {
            return nil
        }
        return (id, hash)
    }

    static func validate(id: String, hash: String) -> String? {
        let id = id.trimmingCharacters(in: .whitespacesAndNewlines)
        let hash = hash.trimmingCharacters(in: .whitespacesAndNewlines)
        if id.isEmpty || hash.isEmpty {
            return "Fill in both fields"
        }
        guard let value = Int32(id), value > 0 else {
            return "api_id must contain only digits"
        }
        let hex = CharacterSet(charactersIn: "0123456789abcdefABCDEF")
        if hash.count != 32 || hash.unicodeScalars.contains(where: { !hex.contains($0) }) {
            return "api_hash must be 32 characters long"
        }
        return nil
    }

    static func store(id: String, hash: String) {
        write(id.trimmingCharacters(in: .whitespacesAndNewlines), "api_id")
        write(hash.trimmingCharacters(in: .whitespacesAndNewlines), "api_hash")
    }

    public static func ensure() -> Bool {
        if current != nil {
            return true
        }
        let controller = VeilWelcomeWindowController()
        return controller.runModal()
    }
}

private final class VeilFlippedView: NSView {
    override var isFlipped: Bool {
        return true
    }
}

private final class VeilCapsuleButton: NSButton {
    private let fill: NSColor
    private let titleColor: NSColor

    init(title: String, fill: NSColor, titleColor: NSColor, font: NSFont) {
        self.fill = fill
        self.titleColor = titleColor
        super.init(frame: .zero)
        self.isBordered = false
        self.wantsLayer = true
        self.layer?.cornerCurve = .continuous
        self.focusRingType = .none
        self.attributedTitle = NSAttributedString(string: title, attributes: [.foregroundColor: titleColor, .font: font])
        self.updateFill(highlighted: false)
    }

    required init?(coder: NSCoder) {
        fatalError()
    }

    override func layout() {
        super.layout()
        self.layer?.cornerRadius = self.bounds.height / 2
    }

    override var isHighlighted: Bool {
        didSet {
            self.updateFill(highlighted: isHighlighted)
        }
    }

    private func updateFill(highlighted: Bool) {
        self.layer?.backgroundColor = (highlighted ? self.fill.withAlphaComponent(self.fill.alphaComponent * 0.8) : self.fill).cgColor
    }

    override func resetCursorRects() {
        self.addCursorRect(self.bounds, cursor: .pointingHand)
    }
}

private final class VeilFieldView: NSView {
    let field: NSTextField

    init(placeholder: String, secure: Bool) {
        self.field = secure ? NSSecureTextField() : NSTextField()
        super.init(frame: .zero)
        self.wantsLayer = true
        self.layer?.cornerRadius = 14
        self.layer?.cornerCurve = .continuous
        self.layer?.backgroundColor = NSColor(white: 1, alpha: 0.07).cgColor
        self.layer?.borderWidth = 1
        self.layer?.borderColor = NSColor(white: 1, alpha: 0.12).cgColor
        self.field.isBordered = false
        self.field.drawsBackground = false
        self.field.focusRingType = .none
        self.field.font = .systemFont(ofSize: 15)
        self.field.textColor = .white
        self.field.cell?.usesSingleLineMode = true
        self.field.cell?.isScrollable = true
        self.field.placeholderAttributedString = NSAttributedString(string: placeholder, attributes: [.foregroundColor: NSColor(white: 1, alpha: 0.35), .font: NSFont.systemFont(ofSize: 15)])
        self.addSubview(self.field)
    }

    required init?(coder: NSCoder) {
        fatalError()
    }

    override func layout() {
        super.layout()
        let height: CGFloat = 20
        self.field.frame = NSMakeRect(16, floor((self.bounds.height - height) / 2), self.bounds.width - 32, height)
    }

    func setError(_ error: Bool) {
        self.layer?.borderColor = (error ? NSColor(red: 1, green: 0.27, blue: 0.23, alpha: 0.8) : NSColor(white: 1, alpha: 0.12)).cgColor
    }
}

private final class VeilWelcomeWindowController: NSObject, NSWindowDelegate, NSTextFieldDelegate {
    private let window: NSWindow
    private let idField = VeilFieldView(placeholder: "api_id  —  e.g. 1234567", secure: false)
    private let hashField = VeilFieldView(placeholder: "api_hash  —  32 characters", secure: true)
    private let errorLabel = NSTextField(labelWithString: "")
    private var saved = false

    override init() {
        let size = NSMakeSize(460, 724)
        self.window = NSWindow(contentRect: NSMakeRect(0, 0, size.width, size.height), styleMask: [.titled, .closable, .fullSizeContentView], backing: .buffered, defer: false)
        super.init()
        self.window.titleVisibility = .hidden
        self.window.titlebarAppearsTransparent = true
        self.window.isMovableByWindowBackground = true
        self.window.appearance = NSAppearance(named: .darkAqua)
        self.window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        self.window.standardWindowButton(.zoomButton)?.isHidden = true
        self.window.delegate = self
        self.window.title = "Veil"
        self.buildContent(size: size)
        self.window.center()
    }

    private func label(_ text: String, size: CGFloat, weight: NSFont.Weight, color: NSColor, alignment: NSTextAlignment = .center) -> NSTextField {
        let label = NSTextField(wrappingLabelWithString: text)
        label.font = .systemFont(ofSize: size, weight: weight)
        label.textColor = color
        label.alignment = alignment
        label.isSelectable = false
        return label
    }

    private func buildContent(size: NSSize) {
        let effect = NSVisualEffectView(frame: NSMakeRect(0, 0, size.width, size.height))
        effect.material = .hudWindow
        effect.blendingMode = .behindWindow
        effect.state = .active
        effect.autoresizingMask = [.width, .height]
        effect.wantsLayer = true

        let tint = CALayer()
        tint.backgroundColor = NSColor(red: 0.03, green: 0.03, blue: 0.05, alpha: 0.55).cgColor
        tint.frame = NSMakeRect(0, 0, size.width, size.height)
        effect.layer?.addSublayer(tint)

        let glow = CAGradientLayer()
        glow.type = .radial
        glow.colors = [NSColor(red: 0.42, green: 0.32, blue: 1, alpha: 0.32).cgColor, NSColor(red: 0.42, green: 0.32, blue: 1, alpha: 0).cgColor]
        glow.startPoint = CGPoint(x: 0.5, y: 0.5)
        glow.endPoint = CGPoint(x: 1, y: 1)
        glow.frame = NSMakeRect(-120, size.height - 380, size.width + 240, 520)
        effect.layer?.addSublayer(glow)

        let glow2 = CAGradientLayer()
        glow2.type = .radial
        glow2.colors = [NSColor(red: 0.1, green: 0.75, blue: 0.75, alpha: 0.18).cgColor, NSColor(red: 0.1, green: 0.75, blue: 0.75, alpha: 0).cgColor]
        glow2.startPoint = CGPoint(x: 0.5, y: 0.5)
        glow2.endPoint = CGPoint(x: 1, y: 1)
        glow2.frame = NSMakeRect(-200, -260, size.width + 200, 520)
        effect.layer?.addSublayer(glow2)

        let content = VeilFlippedView(frame: effect.bounds)
        content.autoresizingMask = [.width, .height]
        effect.addSubview(content)
        self.window.contentView = effect

        let width = size.width
        let inset: CGFloat = 40
        var y: CGFloat = 52

        let icon = NSImageView(frame: NSMakeRect((width - 104) / 2, y, 104, 104))
        icon.image = NSApp.applicationIconImage
        icon.imageScaling = .scaleProportionallyUpOrDown
        icon.wantsLayer = true
        icon.shadow = {
            let shadow = NSShadow()
            shadow.shadowColor = NSColor(white: 0, alpha: 0.5)
            shadow.shadowBlurRadius = 24
            shadow.shadowOffset = NSMakeSize(0, -8)
            return shadow
        }()
        content.addSubview(icon)
        y += 104 + 22

        let title = self.label("Welcome to Veil", size: 26, weight: .bold, color: .white)
        title.frame = NSMakeRect(inset, y, width - inset * 2, 34)
        content.addSubview(title)
        y += 34 + 8

        let subtitle = self.label("All of Telegram, with an invisible mode. Enter your personal API keys to get started.", size: 13.5, weight: .regular, color: NSColor(white: 1, alpha: 0.6))
        subtitle.frame = NSMakeRect(inset, y, width - inset * 2, 40)
        content.addSubview(subtitle)
        y += 40 + 24

        let card = NSView(frame: NSMakeRect(inset - 8, y, width - (inset - 8) * 2, 118))
        card.wantsLayer = true
        card.layer?.cornerRadius = 18
        card.layer?.cornerCurve = .continuous
        card.layer?.backgroundColor = NSColor(white: 1, alpha: 0.05).cgColor
        card.layer?.borderWidth = 1
        card.layer?.borderColor = NSColor(white: 1, alpha: 0.08).cgColor
        let cardContent = VeilFlippedView(frame: card.bounds)
        card.addSubview(cardContent)
        content.addSubview(card)

        let steps = [
            "Sign in to my.telegram.org/apps with your phone number",
            "Click \"Create application\" to create an app",
            "Enter the api_id and api_hash you get below"
        ]
        var stepY: CGFloat = 16
        for (i, step) in steps.enumerated() {
            let badge = NSView(frame: NSMakeRect(16, stepY, 22, 22))
            badge.wantsLayer = true
            badge.layer?.backgroundColor = NSColor(white: 0.95, alpha: 1).cgColor
            badge.layer?.cornerRadius = 11
            let number = NSTextField(labelWithString: "\(i + 1)")
            number.font = .systemFont(ofSize: 11.5, weight: .bold)
            number.textColor = .black
            number.alignment = .center
            number.sizeToFit()
            number.frame = NSMakeRect(0, floor((22 - number.frame.height) / 2), 22, number.frame.height)
            badge.addSubview(number)
            cardContent.addSubview(badge)
            let text = self.label(step, size: 13, weight: .regular, color: NSColor(white: 1, alpha: 0.82), alignment: .left)
            text.frame = NSMakeRect(46, stepY + 2, card.frame.width - 62, 18)
            cardContent.addSubview(text)
            stepY += 32
        }
        y += 118 + 22

        self.idField.frame = NSMakeRect(inset, y, width - inset * 2, 48)
        self.idField.field.delegate = self
        content.addSubview(self.idField)
        y += 48 + 10

        self.hashField.frame = NSMakeRect(inset, y, width - inset * 2, 48)
        self.hashField.field.delegate = self
        content.addSubview(self.hashField)
        y += 48 + 8

        self.errorLabel.font = .systemFont(ofSize: 12, weight: .medium)
        self.errorLabel.textColor = NSColor(red: 1, green: 0.42, blue: 0.4, alpha: 1)
        self.errorLabel.alignment = .left
        self.errorLabel.frame = NSMakeRect(inset + 4, y, width - inset * 2, 16)
        content.addSubview(self.errorLabel)
        y += 16 + 12

        let save = VeilCapsuleButton(title: "Continue", fill: NSColor(white: 0.97, alpha: 1), titleColor: .black, font: .systemFont(ofSize: 15, weight: .semibold))
        save.frame = NSMakeRect(inset, y, width - inset * 2, 48)
        save.target = self
        save.action = #selector(self.saveAction)
        save.keyEquivalent = "\r"
        content.addSubview(save)
        y += 48 + 12

        let open = VeilCapsuleButton(title: "Open my.telegram.org", fill: NSColor(white: 1, alpha: 0.08), titleColor: .white, font: .systemFont(ofSize: 14, weight: .medium))
        open.frame = NSMakeRect(inset, y, width - inset * 2, 42)
        open.target = self
        open.action = #selector(self.openAction)
        content.addSubview(open)
        y += 42 + 18

        let footer = self.label("🔒  Keys are stored only in this Mac's Keychain", size: 11.5, weight: .regular, color: NSColor(white: 1, alpha: 0.4))
        footer.frame = NSMakeRect(inset, y, width - inset * 2, 16)
        content.addSubview(footer)

        self.window.initialFirstResponder = self.idField.field
    }

    func runModal() -> Bool {
        NSApp.activate(ignoringOtherApps: true)
        self.window.makeKeyAndOrderFront(nil)
        NSApp.runModal(for: self.window)
        self.window.orderOut(nil)
        return self.saved
    }

    @objc private func saveAction() {
        let id = self.idField.field.stringValue
        let hash = self.hashField.field.stringValue
        if let error = VeilApiKeys.validate(id: id, hash: hash) {
            self.errorLabel.stringValue = error
            self.idField.setError(Int32(id.trimmingCharacters(in: .whitespacesAndNewlines)) == nil)
            self.hashField.setError(!error.hasPrefix("api_id") && hash.trimmingCharacters(in: .whitespacesAndNewlines).count != 32)
            self.window.animator().alphaValue = 1
            self.shake()
            return
        }
        VeilApiKeys.store(id: id, hash: hash)
        self.saved = true
        NSApp.stopModal()
    }

    @objc private func openAction() {
        if let url = URL(string: "https://my.telegram.org/apps") {
            NSWorkspace.shared.open(url)
        }
    }

    func controlTextDidChange(_ obj: Notification) {
        self.errorLabel.stringValue = ""
        self.idField.setError(false)
        self.hashField.setError(false)
    }

    func windowWillClose(_ notification: Notification) {
        NSApp.stopModal()
    }

    private func shake() {
        let frame = self.window.frame
        let animation = CAKeyframeAnimation()
        let path = CGMutablePath()
        path.move(to: CGPoint(x: frame.minX, y: frame.minY))
        for i in 0 ..< 4 {
            path.addLine(to: CGPoint(x: frame.minX + (i % 2 == 0 ? -8 : 8), y: frame.minY))
        }
        path.addLine(to: CGPoint(x: frame.minX, y: frame.minY))
        animation.path = path
        animation.duration = 0.35
        self.window.animations = ["frameOrigin": animation]
        self.window.animator().setFrameOrigin(frame.origin)
    }
}
