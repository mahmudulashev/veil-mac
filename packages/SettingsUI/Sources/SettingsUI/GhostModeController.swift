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

private let _id_enabled = InputDataIdentifier("_id_ghost_enabled")
private let _id_read = InputDataIdentifier("_id_ghost_read")
private let _id_online = InputDataIdentifier("_id_ghost_online")
private let _id_typing = InputDataIdentifier("_id_ghost_typing")
private let _id_opened = InputDataIdentifier("_id_ghost_opened")
private let _id_stories = InputDataIdentifier("_id_ghost_stories")
private let _id_keep_deleted = InputDataIdentifier("_id_ghost_keep_deleted")
private let _id_keep_edits = InputDataIdentifier("_id_ghost_keep_edits")
private let _id_read_on_reply = InputDataIdentifier("_id_ghost_read_on_reply")

public func ghostModeSettingsIcon(_ base: CGImage) -> CGImage {
    let size = NSMakeSize(CGFloat(base.width) / System.backingScale, CGFloat(base.height) / System.backingScale)
    return generateImage(size, contextGenerator: { size, ctx in
        ctx.clear(CGRect(origin: .zero, size: size))
        let rect = CGRect(origin: .zero, size: size)
        let path = CGPath(roundedRect: rect, cornerWidth: size.width * 0.24, cornerHeight: size.height * 0.24, transform: nil)
        ctx.addPath(path)
        ctx.setFillColor(NSColor(red: 0.55, green: 0.42, blue: 0.98, alpha: 1).cgColor)
        ctx.fillPath()
        let config = NSImage.SymbolConfiguration(pointSize: size.height * 0.52, weight: .semibold)
            .applying(NSImage.SymbolConfiguration(paletteColors: [.white]))
        if let symbol = NSImage(systemSymbolName: "eye.slash.fill", accessibilityDescription: nil)?.withSymbolConfiguration(config) {
            let symbolSize = symbol.size
            let origin = CGPoint(x: (size.width - symbolSize.width) / 2, y: (size.height - symbolSize.height) / 2)
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
            symbol.draw(in: CGRect(origin: origin, size: symbolSize))
            NSGraphicsContext.restoreGraphicsState()
        }
    })!
}

private func entries(_ state: State, arguments: Arguments) -> [InputDataEntry] {
    var entries: [InputDataEntry] = []

    var sectionId: Int32 = 0
    var index: Int32 = 0

    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1

    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_enabled, data: .init(name: "Ghost rejimi", color: theme.colors.text, type: .switchable(state.settings.enabled), viewType: .singleItem, action: {
        arguments.update { $0.enabled.toggle() }
    })))
    index += 1

    entries.append(.desc(sectionId: sectionId, index: index, text: .plain("Yoqilganda boshqalar sizning faolligingizni ko'rmaydi. Bu faqat shu qurilmaga ta'sir qiladi."), data: .init(color: theme.colors.listGrayText, viewType: .textBottomItem)))
    index += 1

    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1

    entries.append(.desc(sectionId: sectionId, index: index, text: .plain("NIMALAR YASHIRILADI"), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
    index += 1

    let enabled = state.settings.enabled
    let rows: [(InputDataIdentifier, String, String, Bool, (inout GhostMode.Settings) -> Void)] = [
        (_id_read, "O'qilganlik belgisi", "Xabarlarni o'qisangiz ham ikkita ✓ chiqmaydi", state.settings.hideReadReceipts, { $0.hideReadReceipts.toggle() }),
        (_id_online, "Onlayn holat", "Doim oflayn ko'rinasiz, oxirgi faollik yangilanmaydi", state.settings.hideOnline, { $0.hideOnline.toggle() }),
        (_id_typing, "\"Yozmoqda…\"", "Yozish, ovoz yozish va fayl tanlash ko'rinmaydi", state.settings.hideTyping, { $0.hideTyping.toggle() }),
        (_id_opened, "Tinglash va ko'rish", "Ovozli va video xabarlarni ochganingiz bilinmaydi", state.settings.hideOpenedContent, { $0.hideOpenedContent.toggle() }),
        (_id_stories, "Storis ko'rish", "Storislarni ko'rganingiz ro'yxatda chiqmaydi", state.settings.hideStoryViews, { $0.hideStoryViews.toggle() }),
        (_id_read_on_reply, "Javob yozsam o'qilgan bo'lsin", "Xabar yuborganingizda o'sha chatdagi avvalgi xabarlar ikkita ✓ bo'ladi", state.settings.readOnReply, { $0.readOnReply.toggle() }),
    ]
    for (i, row) in rows.enumerated() {
        let (identifier, name, info, value, toggle) = row
        entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: identifier, data: .init(name: name, color: theme.colors.text, type: .switchable(value), viewType: bestGeneralViewType(rows.map { $0.0 }, for: i), enabled: enabled, description: info, action: {
            arguments.update(toggle)
        })))
        index += 1
    }

    entries.append(.desc(sectionId: sectionId, index: index, text: .plain("Ghost yoqilganda o'qigan xabarlaringiz faqat shu qurilmada o'qilgan bo'ladi. Xabar yuborsangiz, Telegram sizni qisqa vaqt onlayn ko'rsatishi mumkin."), data: .init(color: theme.colors.listGrayText, viewType: .textBottomItem)))
    index += 1

    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1

    entries.append(.desc(sectionId: sectionId, index: index, text: .plain("ARXIV"), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
    index += 1

    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_keep_deleted, data: .init(name: "O'chirilgan xabarlarni saqlash", color: theme.colors.text, type: .switchable(state.settings.keepDeletedMessages), viewType: .firstItem, description: "Suhbatdosh o'chirgan xabarlar sizda qoladi", action: {
        arguments.update { $0.keepDeletedMessages.toggle() }
    })))
    index += 1

    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_keep_edits, data: .init(name: "Tahrir tarixini saqlash", color: theme.colors.text, type: .switchable(state.settings.keepEditHistory), viewType: .lastItem, description: "Tahrirlangan xabarning eski matnlari saqlanadi", action: {
        arguments.update { $0.keepEditHistory.toggle() }
    })))
    index += 1

    entries.append(.desc(sectionId: sectionId, index: index, text: .plain("Arxiv Ghost rejimidan qat'i nazar ishlaydi va faqat shu qurilmada saqlanadi."), data: .init(color: theme.colors.listGrayText, viewType: .textBottomItem)))
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

    let controller = InputDataController(dataSignal: signal, title: "Ghost rejimi")

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
