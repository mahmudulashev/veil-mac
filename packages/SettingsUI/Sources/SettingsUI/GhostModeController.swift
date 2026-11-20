import Cocoa
import TGUIKit
import SwiftSignalKit
import TelegramCore
import Localization
import TelegramContext
import TelegramTheme
import TelegramUtils
import InputDataUI
import GeneralRows

private final class Arguments {
    let context: any AccountContextProtocol
    let update: ((inout GhostMode.Settings) -> Void) -> Void
    init(context: any AccountContextProtocol, update: @escaping ((inout GhostMode.Settings) -> Void) -> Void) {
        self.context = context
        self.update = update
    }
}

private struct State: Equatable {
    var settings: GhostMode.Settings
}

private let _id_read = InputDataIdentifier("_id_ghost_read")
private let _id_online = InputDataIdentifier("_id_ghost_online")
private let _id_typing = InputDataIdentifier("_id_ghost_typing")
private let _id_opened = InputDataIdentifier("_id_ghost_opened")
private let _id_stories = InputDataIdentifier("_id_ghost_stories")
private let _id_keep_deleted = InputDataIdentifier("_id_ghost_keep_deleted")
private let _id_keep_edits = InputDataIdentifier("_id_ghost_keep_edits")
private let _id_read_on_reply = InputDataIdentifier("_id_ghost_read_on_reply")

public func ghostModeSettingsIcon(_ base: CGImage, active: Bool = false) -> CGImage {
    return settingsSymbolIcon(base, symbol: "eye.slash.fill", color: NSColor(red: 0.55, green: 0.42, blue: 0.98, alpha: 1), active: active)
}

public func settingsSymbolIcon(_ base: CGImage, symbol symbolName: String, color: NSColor, active: Bool = false) -> CGImage {
    let size = NSMakeSize(CGFloat(base.width) / System.backingScale, CGFloat(base.height) / System.backingScale)
    return generateImage(size, rotatedContext: { size, ctx in
        ctx.clear(CGRect(origin: .zero, size: size))
        let rect = CGRect(origin: .zero, size: size)
        let path = CGPath(roundedRect: rect, cornerWidth: size.width * 0.24, cornerHeight: size.height * 0.24, transform: nil)
        ctx.addPath(path)
        ctx.setFillColor(active ? NSColor.white.cgColor : color.cgColor)
        ctx.fillPath()
        let config = NSImage.SymbolConfiguration(pointSize: size.height * 0.52, weight: .semibold)
            .applying(NSImage.SymbolConfiguration(paletteColors: [active ? color : .white]))
        if let symbol = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)?.withSymbolConfiguration(config) {
            let symbolSize = symbol.size
            let origin = CGPoint(x: (size.width - symbolSize.width) / 2, y: (size.height - symbolSize.height) / 2)
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
            symbol.draw(in: CGRect(origin: origin, size: symbolSize))
            NSGraphicsContext.restoreGraphicsState()
        }
    })!
}

private func ghostColor(_ hex: UInt32) -> NSColor {
    return NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
}

private func ghostRowIcon(_ symbolName: String, _ color: NSColor) -> CGImage {
    let size = NSMakeSize(30, 30)
    let isDark = theme.colors.isDark
    return generateImage(size, rotatedContext: { size, ctx in
        let rect = CGRect(origin: .zero, size: size)
        ctx.clear(rect)
        ctx.addPath(CGPath(roundedRect: rect, cornerWidth: 9, cornerHeight: 9, transform: nil))
        ctx.setFillColor(color.withAlphaComponent(isDark ? 0.24 : 0.13).cgColor)
        ctx.fillPath()
        let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
            .applying(NSImage.SymbolConfiguration(paletteColors: [color]))
        if let symbol = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)?.withSymbolConfiguration(config) {
            let symbolSize = symbol.size
            let origin = CGPoint(x: (size.width - symbolSize.width) / 2, y: (size.height - symbolSize.height) / 2)
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
            symbol.draw(in: CGRect(origin: origin, size: symbolSize))
            NSGraphicsContext.restoreGraphicsState()
        }
    })!
}

private let _id_hero = InputDataIdentifier("_id_ghost_hero")

private func entries(_ state: State, arguments: Arguments) -> [InputDataEntry] {
    var entries: [InputDataEntry] = []

    var sectionId: Int32 = 0
    var index: Int32 = 0

    let settings = state.settings
    let enabled = settings.enabled
    let rowTheme = GeneralRowItem.Theme.initialize(theme, background: theme.colors.isDark ? nil : .white)

    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1

    let activeCount = [settings.hideReadReceipts, settings.hideOnline, settings.hideTyping, settings.hideOpenedContent, settings.hideStoryViews].filter { $0 }.count

    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_hero, equatable: InputDataEquatable(settings), comparable: nil, item: { initialSize, stableId in
        return GhostHeroRowItem(initialSize, stableId: stableId, enabled: enabled, activeCount: activeCount, viewType: .singleItem, toggle: {
            arguments.update { $0.enabled.toggle() }
        })
    }))
    index += 1

    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1

    entries.append(.desc(sectionId: sectionId, index: index, text: .plain("WHAT GETS HIDDEN"), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
    index += 1

    let rows: [(InputDataIdentifier, String, String, String, UInt32, Bool, (inout GhostMode.Settings) -> Void)] = [
        (_id_read, "Read Receipts", "No double ✓ when you read messages", "checkmark.circle.fill", 0x2F5BFF, settings.hideReadReceipts, { $0.hideReadReceipts.toggle() }),
        (_id_online, "Online Status", "You always appear offline", "wifi.slash", 0x16A34A, settings.hideOnline, { $0.hideOnline.toggle() }),
        (_id_typing, "\"Typing…\"", "Typing and recording are not shown", "keyboard.fill", 0xF59E0B, settings.hideTyping, { $0.hideTyping.toggle() }),
        (_id_opened, "Listened & Watched", "Opening voice and video messages stays hidden", "play.circle.fill", 0xE0457B, settings.hideOpenedContent, { $0.hideOpenedContent.toggle() }),
        (_id_stories, "Story Views", "You don't appear in viewer lists", "circle.dashed", 0x8B5CF6, settings.hideStoryViews, { $0.hideStoryViews.toggle() }),
        (_id_read_on_reply, "Read on Reply", "Sending a message marks earlier ones as read ✓✓", "arrowshape.turn.up.left.fill", 0x0EA5E9, settings.readOnReply, { $0.readOnReply.toggle() }),
    ]
    for (i, row) in rows.enumerated() {
        let (identifier, name, info, symbol, color, value, toggle) = row
        entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: identifier, data: .init(name: name, color: theme.colors.text, icon: ghostRowIcon(symbol, ghostColor(color)), type: .switchable(value), viewType: bestGeneralViewType(rows.map { $0.0 }, for: i), enabled: enabled, description: info, action: {
            arguments.update(toggle)
        }, theme: rowTheme)))
        index += 1
    }

    entries.append(.desc(sectionId: sectionId, index: index, text: .plain("Telegram may show you online for a few seconds after you send a message."), data: .init(color: theme.colors.listGrayText, viewType: .textBottomItem)))
    index += 1

    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1

    entries.append(.desc(sectionId: sectionId, index: index, text: .plain("ARCHIVE"), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
    index += 1

    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_keep_deleted, data: .init(name: "Deleted Messages", color: theme.colors.text, icon: ghostRowIcon("trash.fill", ghostColor(0xEF4444)), type: .switchable(settings.keepDeletedMessages), viewType: .firstItem, description: "Keep messages even after others delete them", action: {
        arguments.update { $0.keepDeletedMessages.toggle() }
    }, theme: rowTheme)))
    index += 1

    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_keep_edits, data: .init(name: "Edit History", color: theme.colors.text, icon: ghostRowIcon("clock.arrow.circlepath", ghostColor(0x64748B)), type: .switchable(settings.keepEditHistory), viewType: .lastItem, description: "Keep the text from before each edit", action: {
        arguments.update { $0.keepEditHistory.toggle() }
    }, theme: rowTheme)))
    index += 1

    entries.append(.desc(sectionId: sectionId, index: index, text: .plain("The archive works even when Ghost is off and is stored only on this Mac."), data: .init(color: theme.colors.listGrayText, viewType: .textBottomItem)))
    index += 1

    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1

    return entries
}

public func GhostModeController(context: any AccountContextProtocol) -> InputDataController {
    let actionsDisposable = DisposableSet()

    let initialState = State(settings: GhostMode.settings)

    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((State) -> State) -> Void = { f in
        statePromise.set(stateValue.modify(f))
    }

    let arguments = Arguments(context: context, update: { f in
        GhostMode.update(f)
        let settings = GhostMode.settings
        updateState { current in
            var current = current
            current.settings = settings
            return current
        }
    })

    let listener = GhostMode.addListener { settings in
        Queue.mainQueue().async {
            updateState { current in
                var current = current
                current.settings = settings
                return current
            }
        }
    }

    let signal = statePromise.get() |> deliverOnPrepareQueue |> map { state in
        return InputDataSignalValue(entries: entries(state, arguments: arguments))
    }

    let controller = InputDataController(dataSignal: signal, title: "Ghost Mode", hasDone: false, identifier: "veil_ghost")

    controller.onDeinit = {
        GhostMode.removeListener(listener)
        actionsDisposable.dispose()
    }

    return controller
}

public func ghostModeSettingsSignal() -> Signal<GhostMode.Settings, NoError> {
    return Signal { subscriber in
        subscriber.putNext(GhostMode.settings)
        let id = GhostMode.addListener { settings in
            subscriber.putNext(settings)
        }
        return ActionDisposable {
            GhostMode.removeListener(id)
        }
    }
}
