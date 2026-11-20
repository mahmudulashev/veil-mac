import Cocoa
import TGUIKit
import SwiftSignalKit
import TelegramCore
import Postbox
import TelegramTheme
import TelegramContext
import TelegramUtils
import GeneralRows
import InputDataUI

struct VeilChatStats: Equatable {
    struct Sender: Equatable {
        let id: PeerId
        let name: String
        let count: Int
    }

    var total: Int = 0
    var mine: Int = 0
    var myChars: Int = 0
    var theirChars: Int = 0
    var myTextCount: Int = 0
    var theirTextCount: Int = 0
    var hours: [Int] = Array(repeating: 0, count: 24)
    var weekdays: [Int] = Array(repeating: 0, count: 7)
    var firstDate: Int32 = 0
    var lastDate: Int32 = 0
    var busiestDay: Int32 = 0
    var busiestDayCount: Int = 0
    var activeDays: Int = 0
    var longestStreak: Int = 0
    var myReply: Int32?
    var theirReply: Int32?
    var media: [Int] = Array(repeating: 0, count: VeilChatStats.mediaKinds.count)
    var emojis: [(String, Int)] = []
    var senders: [Sender] = []

    var theirs: Int {
        return total - mine
    }

    static let mediaKinds: [(title: String, symbol: String, color: UInt32)] = [
        ("Photos", "photo.fill", 0x2F5BFF),
        ("Videos", "video.fill", 0xE0457B),
        ("Voice Messages", "waveform", 0xF59E0B),
        ("Video Messages", "record.circle.fill", 0x8B5CF6),
        ("Stickers", "face.smiling.fill", 0x16A34A),
        ("GIFs", "sparkles.rectangle.stack.fill", 0x0EA5E9),
        ("Files", "doc.fill", 0x64748B),
        ("Links", "link", 0x14B8A6)
    ]

    static func == (lhs: VeilChatStats, rhs: VeilChatStats) -> Bool {
        return lhs.total == rhs.total && lhs.mine == rhs.mine && lhs.myChars == rhs.myChars && lhs.theirChars == rhs.theirChars && lhs.hours == rhs.hours && lhs.weekdays == rhs.weekdays && lhs.firstDate == rhs.firstDate && lhs.lastDate == rhs.lastDate && lhs.busiestDay == rhs.busiestDay && lhs.busiestDayCount == rhs.busiestDayCount && lhs.activeDays == rhs.activeDays && lhs.longestStreak == rhs.longestStreak && lhs.myReply == rhs.myReply && lhs.theirReply == rhs.theirReply && lhs.media == rhs.media && lhs.emojis.map { $0.0 } == rhs.emojis.map { $0.0 } && lhs.emojis.map { $0.1 } == rhs.emojis.map { $0.1 } && lhs.senders == rhs.senders
    }
}

private func isEmojiCharacter(_ character: Character) -> Bool {
    guard let scalar = character.unicodeScalars.first else {
        return false
    }
    if scalar.properties.isEmojiPresentation {
        return true
    }
    return scalar.properties.isEmoji && character.unicodeScalars.count > 1 && scalar.value > 0x238C
}

private func median(_ values: [Int32]) -> Int32? {
    if values.isEmpty {
        return nil
    }
    let sorted = values.sorted()
    return sorted[sorted.count / 2]
}

func computeVeilChatStats(_ messages: [Message], accountPeerId: PeerId) -> VeilChatStats {
    var stats = VeilChatStats()
    let calendar = Calendar.current
    var dayCounts: [Int: Int] = [:]
    var emojiCounts: [String: Int] = [:]
    var senderCounts: [PeerId: Int] = [:]
    var senderNames: [PeerId: String] = [:]
    var myReplies: [Int32] = []
    var theirReplies: [Int32] = []
    var previousAuthor: PeerId?
    var previousTimestamp: Int32 = 0

    for message in messages {
        if message.media.contains(where: { $0 is TelegramMediaAction }) {
            continue
        }
        let author = message.author?.id ?? message.id.peerId
        let isMine = author == accountPeerId
        stats.total += 1
        if isMine {
            stats.mine += 1
        }
        if stats.firstDate == 0 || message.timestamp < stats.firstDate {
            stats.firstDate = message.timestamp
        }
        stats.lastDate = max(stats.lastDate, message.timestamp)

        let date = Date(timeIntervalSince1970: TimeInterval(message.timestamp))
        let components = calendar.dateComponents([.hour, .weekday], from: date)
        if let hour = components.hour {
            stats.hours[hour] += 1
        }
        if let weekday = components.weekday {
            stats.weekdays[(weekday + 5) % 7] += 1
        }
        let day = Int(calendar.startOfDay(for: date).timeIntervalSince1970 / 86400)
        dayCounts[day, default: 0] += 1

        if let previousAuthor, previousAuthor != author {
            let delta = message.timestamp - previousTimestamp
            if delta >= 0 && delta < 12 * 60 * 60 {
                if isMine {
                    myReplies.append(delta)
                } else if previousAuthor == accountPeerId {
                    theirReplies.append(delta)
                }
            }
        }
        previousAuthor = author
        previousTimestamp = message.timestamp

        senderCounts[author, default: 0] += 1
        if senderNames[author] == nil, let peer = message.author {
            senderNames[author] = isMine ? "You" : peer.compactDisplayTitle
        }

        if !message.text.isEmpty {
            let length = message.text.count
            if isMine {
                stats.myChars += length
                stats.myTextCount += 1
            } else {
                stats.theirChars += length
                stats.theirTextCount += 1
            }
            for character in message.text where isEmojiCharacter(character) {
                emojiCounts[String(character), default: 0] += 1
            }
        }

        for media in message.media {
            if media is TelegramMediaImage {
                stats.media[0] += 1
            } else if let file = media as? TelegramMediaFile {
                if file.isInstantVideo {
                    stats.media[3] += 1
                } else if file.isVoice {
                    stats.media[2] += 1
                } else if file.isSticker || file.isAnimatedSticker {
                    stats.media[4] += 1
                } else if file.isAnimated {
                    stats.media[5] += 1
                } else if file.isVideo {
                    stats.media[1] += 1
                } else {
                    stats.media[6] += 1
                }
            } else if media is TelegramMediaWebpage {
                stats.media[7] += 1
            }
        }
    }

    if let busiest = dayCounts.max(by: { $0.value < $1.value }) {
        stats.busiestDay = Int32(busiest.key * 86400)
        stats.busiestDayCount = busiest.value
    }
    stats.activeDays = dayCounts.count
    var streak = 0
    var previousDay: Int?
    for day in dayCounts.keys.sorted() {
        if let previousDay, day == previousDay + 1 {
            streak += 1
        } else {
            streak = 1
        }
        stats.longestStreak = max(stats.longestStreak, streak)
        previousDay = day
    }
    stats.myReply = median(myReplies)
    stats.theirReply = median(theirReplies)
    stats.emojis = emojiCounts.sorted(by: { $0.value > $1.value }).prefix(5).map { ($0.key, $0.value) }
    stats.senders = senderCounts.sorted(by: { $0.value > $1.value }).prefix(5).map { VeilChatStats.Sender(id: $0.key, name: senderNames[$0.key] ?? "Unknown", count: $0.value) }
    return stats
}

private func veilStatsColor(_ hex: UInt32, alpha: CGFloat = 1) -> NSColor {
    return NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

private func veilStatsIcon(_ symbolName: String, _ color: NSColor) -> CGImage {
    let isDark = theme.colors.isDark
    return generateImage(NSMakeSize(30, 30), rotatedContext: { size, ctx in
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

private func formatCount(_ value: Int) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.locale = Locale(identifier: "en_US")
    return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
}

private func formatDate(_ timestamp: Int32) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US")
    formatter.dateFormat = "MMM d, yyyy"
    return formatter.string(from: Date(timeIntervalSince1970: TimeInterval(timestamp)))
}

private func formatDuration(_ seconds: Int32) -> String {
    if seconds < 60 {
        return "\(max(1, seconds)) sec"
    } else if seconds < 3600 {
        return "\(seconds / 60) min"
    } else {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        return minutes > 0 ? "\(hours) h \(minutes) min" : "\(hours) h"
    }
}

private let weekdayNames = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]

private final class Arguments {
    let context: any AccountContextProtocol
    let loadMore: () -> Void
    init(context: any AccountContextProtocol, loadMore: @escaping () -> Void) {
        self.context = context
        self.loadMore = loadMore
    }
}

private struct State: Equatable {
    var stats: VeilChatStats?
    var isLoading: Bool = true
    var hasMore: Bool = false
    var limit: Int
}

private let _id_hero = InputDataIdentifier("_id_veil_stats_hero")
private let _id_hours = InputDataIdentifier("_id_veil_stats_hours")
private let _id_load_more = InputDataIdentifier("_id_veil_stats_more")
private let _id_loading = InputDataIdentifier("_id_veil_stats_loading")
private func _id_highlight(_ index: Int) -> InputDataIdentifier {
    return InputDataIdentifier("_id_veil_stats_highlight_\(index)")
}
private func _id_media(_ index: Int) -> InputDataIdentifier {
    return InputDataIdentifier("_id_veil_stats_media_\(index)")
}
private func _id_emoji(_ index: Int) -> InputDataIdentifier {
    return InputDataIdentifier("_id_veil_stats_emoji_\(index)")
}
private func _id_sender(_ index: Int) -> InputDataIdentifier {
    return InputDataIdentifier("_id_veil_stats_sender_\(index)")
}

private let veilStatsMaxLimit = 20000

private func entries(_ state: State, peerName: String, isGroup: Bool, arguments: Arguments) -> [InputDataEntry] {
    var entries: [InputDataEntry] = []
    var sectionId: Int32 = 0
    var index: Int32 = 0
    let rowTheme = GeneralRowItem.Theme.initialize(theme, background: theme.colors.isDark ? nil : .white)

    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1

    guard let stats = state.stats, stats.total > 0 else {
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_loading, equatable: InputDataEquatable(state.isLoading), comparable: nil, item: { initialSize, stableId in
            return GeneralTextRowItem(initialSize, stableId: stableId, text: state.isLoading ? "Loading messages…" : "No messages to analyze yet.", alignment: .center, centerViewAlignment: true, viewType: .singleItem)
        }))
        return entries
    }

    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_hero, equatable: InputDataEquatable(stats), comparable: nil, item: { initialSize, stableId in
        return VeilStatsHeroRowItem(initialSize, stableId: stableId, stats: stats, otherName: isGroup ? "Others" : peerName, isLoading: state.isLoading)
    }))
    index += 1

    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1

    entries.append(.desc(sectionId: sectionId, index: index, text: .plain("ACTIVITY BY HOUR"), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
    index += 1

    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_hours, equatable: InputDataEquatable(stats.hours), comparable: nil, item: { initialSize, stableId in
        return VeilStatsHoursRowItem(initialSize, stableId: stableId, hours: stats.hours)
    }))
    index += 1

    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1

    entries.append(.desc(sectionId: sectionId, index: index, text: .plain("HIGHLIGHTS"), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
    index += 1

    let spanDays = max(1, Int((stats.lastDate - stats.firstDate) / 86400) + 1)
    var highlights: [(String, String, String, UInt32)] = []
    highlights.append(("Busiest Day", "\(formatDate(stats.busiestDay)) · \(formatCount(stats.busiestDayCount))", "flame.fill", 0xEF4444))
    if let best = stats.weekdays.enumerated().max(by: { $0.element < $1.element }) {
        highlights.append(("Favorite Weekday", weekdayNames[best.offset], "calendar", 0x2F5BFF))
    }
    highlights.append(("Active Days", "\(formatCount(stats.activeDays)) of \(formatCount(spanDays))", "checkmark.seal.fill", 0x16A34A))
    highlights.append(("Longest Streak", stats.longestStreak == 1 ? "1 day" : "\(stats.longestStreak) days", "bolt.fill", 0xF59E0B))
    if let myReply = stats.myReply {
        highlights.append(("Your Reply Time", formatDuration(myReply), "arrowshape.turn.up.left.fill", 0x0EA5E9))
    }
    if !isGroup, let theirReply = stats.theirReply {
        highlights.append(("\(peerName)'s Reply Time", formatDuration(theirReply), "arrowshape.turn.up.right.fill", 0x8B5CF6))
    }
    if stats.myTextCount > 0 {
        highlights.append(("Your Average Length", "\(stats.myChars / stats.myTextCount) chars", "text.alignleft", 0x64748B))
    }
    if stats.theirTextCount > 0 {
        highlights.append((isGroup ? "Others' Average Length" : "\(peerName)'s Average Length", "\(stats.theirChars / stats.theirTextCount) chars", "text.alignright", 0x64748B))
    }

    for (i, highlight) in highlights.enumerated() {
        entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_highlight(i), data: .init(name: highlight.0, color: theme.colors.text, icon: veilStatsIcon(highlight.2, veilStatsColor(highlight.3)), type: .context(highlight.1), viewType: bestGeneralViewType(highlights.map { $0.0 }, for: i), theme: rowTheme)))
        index += 1
    }

    let mediaRows = stats.media.enumerated().filter { $0.element > 0 }
    if !mediaRows.isEmpty {
        entries.append(.sectionId(sectionId, type: .normal))
        sectionId += 1

        entries.append(.desc(sectionId: sectionId, index: index, text: .plain("MEDIA"), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
        index += 1

        for (i, row) in mediaRows.enumerated() {
            let kind = VeilChatStats.mediaKinds[row.offset]
            entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_media(row.offset), data: .init(name: kind.title, color: theme.colors.text, icon: veilStatsIcon(kind.symbol, veilStatsColor(kind.color)), type: .context(formatCount(row.element)), viewType: bestGeneralViewType(mediaRows.map { "\($0.offset)" }, for: i), theme: rowTheme)))
            index += 1
        }
    }

    if !stats.emojis.isEmpty {
        entries.append(.sectionId(sectionId, type: .normal))
        sectionId += 1

        entries.append(.desc(sectionId: sectionId, index: index, text: .plain("TOP EMOJI"), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
        index += 1

        for (i, emoji) in stats.emojis.enumerated() {
            entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_emoji(i), data: .init(name: emoji.0, color: theme.colors.text, type: .context(formatCount(emoji.1)), viewType: bestGeneralViewType(stats.emojis.map { $0.0 }, for: i), theme: rowTheme)))
            index += 1
        }
    }

    if isGroup, !stats.senders.isEmpty {
        entries.append(.sectionId(sectionId, type: .normal))
        sectionId += 1

        entries.append(.desc(sectionId: sectionId, index: index, text: .plain("MOST ACTIVE MEMBERS"), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
        index += 1

        for (i, sender) in stats.senders.enumerated() {
            entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_sender(i), data: .init(name: sender.name, color: theme.colors.text, type: .context(formatCount(sender.count)), viewType: bestGeneralViewType(stats.senders.map { "\($0.id)" }, for: i), theme: rowTheme)))
            index += 1
        }
    }

    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1

    if state.hasMore && state.limit < veilStatsMaxLimit && !state.isLoading {
        entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_load_more, data: .init(name: "Analyze More Messages", color: theme.colors.accent, type: .none, viewType: .singleItem, action: arguments.loadMore, theme: rowTheme)))
        index += 1
    }

    let footer: String
    if state.isLoading {
        footer = "Loading history… \(formatCount(stats.total)) messages so far."
    } else if state.hasMore {
        footer = "Based on the latest \(formatCount(stats.total)) messages. Calculated on this Mac only."
    } else {
        footer = "Based on all \(formatCount(stats.total)) messages. Calculated on this Mac only."
    }
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(footer), data: .init(color: theme.colors.listGrayText, viewType: state.hasMore && state.limit < veilStatsMaxLimit && !state.isLoading ? .textBottomItem : .textTopItem)))
    index += 1

    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1

    return entries
}

public func VeilChatStatsController(context: any AccountContextProtocol, peerId: PeerId, peerName: String, isGroup: Bool) -> InputDataController {
    let actionsDisposable = DisposableSet()

    let initialState = State(limit: 2000)
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((State) -> State) -> Void = { f in
        statePromise.set(stateValue.modify(f))
    }

    let limitPromise = ValuePromise(initialState.limit, ignoreRepeated: true)

    let arguments = Arguments(context: context, loadMore: {
        let limit = min(veilStatsMaxLimit, stateValue.with { $0.limit } * 3)
        updateState { current in
            var current = current
            current.limit = limit
            current.isLoading = true
            return current
        }
        limitPromise.set(limit)
    })

    let accountPeerId = context.peerId
    let computeQueue = Queue(name: "veil.chatStats")
    let statsSignal = limitPromise.get() |> mapToSignal { limit in
        return context.account.viewTracker.aroundMessageHistoryViewForLocation(.peer(peerId: peerId, threadId: nil), index: .upperBound, anchorIndex: .upperBound, count: limit, fixedCombinedReadStates: nil)
        |> deliverOn(computeQueue)
        |> map { result -> (VeilChatStats, Bool, Bool) in
            let view = result.0
            let stats = computeVeilChatStats(view.entries.map { $0.message }, accountPeerId: accountPeerId)
            return (stats, view.isLoading, view.earlierId != nil)
        }
    }

    actionsDisposable.add((statsSignal |> deliverOnMainQueue).start(next: { stats, isLoading, hasMore in
        updateState { current in
            var current = current
            current.stats = stats
            current.isLoading = isLoading
            current.hasMore = hasMore
            return current
        }
    }))

    let signal = statePromise.get() |> deliverOnPrepareQueue |> map { state in
        return InputDataSignalValue(entries: entries(state, peerName: peerName, isGroup: isGroup, arguments: arguments))
    }

    let controller = InputDataController(dataSignal: signal, title: "Chat Stats", hasDone: false, identifier: "veil_chat_stats")

    controller.onDeinit = {
        actionsDisposable.dispose()
    }

    return controller
}

final class VeilStatsHeroRowItem: GeneralRowItem {
    let stats: VeilChatStats
    let otherName: String
    let isLoading: Bool

    init(_ initialSize: NSSize, stableId: AnyHashable, stats: VeilChatStats, otherName: String, isLoading: Bool) {
        self.stats = stats
        self.otherName = otherName
        self.isLoading = isLoading
        super.init(initialSize, height: 178, stableId: stableId, viewType: .singleItem)
    }

    override func viewClass() -> AnyClass {
        return VeilStatsHeroRowView.self
    }
}

private final class VeilStatsHeroRowView: GeneralContainableRowView {
    private let labelView = TextView()
    private let titleView = TextView()
    private let subtitleView = TextView()
    private let trackView = View()
    private let mineView = View()
    private let mineLabel = TextView()
    private let otherLabel = TextView()

    private static let padding: CGFloat = 22

    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        containerView.cornerRadius = 22
        for textView in [labelView, titleView, subtitleView, mineLabel, otherLabel] {
            textView.userInteractionEnabled = false
            textView.isSelectable = false
            textView.backgroundColor = .clear
            containerView.addSubview(textView)
        }
        trackView.layer?.cornerRadius = 5
        mineView.layer?.cornerRadius = 5
        trackView.addSubview(mineView)
        containerView.addSubview(trackView)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func updateColors() {
        super.updateColors()
        borderView.isHidden = true
        containerView.backgroundColor = theme.colors.isDark ? theme.colors.background : .white
    }

    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        guard let item = item as? VeilStatsHeroRowItem else {
            return
        }
        let stats = item.stats
        let accent = veilStatsColor(0x2F5BFF)
        let other = veilStatsColor(0x8B5CF6)
        let textWidth = max(100, item.blockWidth - VeilStatsHeroRowView.padding * 2)

        let label = NSAttributedString(string: item.isLoading ? "CHAT STATS · LOADING" : "CHAT STATS", attributes: [
            .font: NSFont.systemFont(ofSize: 11, weight: .semibold),
            .foregroundColor: accent,
            .kern: 1.2
        ])
        let labelLayout = TextViewLayout(label)
        labelLayout.measure(width: textWidth)
        labelView.update(labelLayout)

        let titleLayout = TextViewLayout(.initialize(string: stats.total == 1 ? "1 message" : "\(formatCount(stats.total)) messages", color: theme.colors.text, font: NSFont.systemFont(ofSize: 28, weight: .bold)), maximumNumberOfLines: 1)
        titleLayout.measure(width: textWidth)
        titleView.update(titleLayout)

        let days = max(1, Int((stats.lastDate - stats.firstDate) / 86400) + 1)
        let subtitleLayout = TextViewLayout(.initialize(string: "Since \(formatDate(stats.firstDate)) · \(days == 1 ? "1 day" : "\(formatCount(days)) days")", color: theme.colors.grayText, font: .normal(13)), maximumNumberOfLines: 1)
        subtitleLayout.measure(width: textWidth)
        subtitleView.update(subtitleLayout)

        let minePercent = stats.total > 0 ? Int((Double(stats.mine) / Double(stats.total) * 100).rounded()) : 0
        let mineLayout = TextViewLayout(.initialize(string: "You · \(minePercent)%", color: accent, font: .medium(13)), maximumNumberOfLines: 1)
        mineLayout.measure(width: textWidth / 2)
        mineLabel.update(mineLayout)

        let otherLayout = TextViewLayout(.initialize(string: "\(item.otherName) · \(100 - minePercent)%", color: other, font: .medium(13)), maximumNumberOfLines: 1)
        otherLayout.measure(width: textWidth / 2)
        otherLabel.update(otherLayout)

        trackView.backgroundColor = other.withAlphaComponent(theme.colors.isDark ? 0.55 : 0.35)
        mineView.backgroundColor = accent

        updateColors()
        needsLayout = true
    }

    override func layout() {
        super.layout()
        guard let item = item as? VeilStatsHeroRowItem else {
            return
        }
        let bounds = containerView.bounds
        let padding = VeilStatsHeroRowView.padding

        labelView.setFrameSize(labelView.textLayout?.layoutSize ?? .zero)
        labelView.setFrameOrigin(NSMakePoint(padding, padding))

        titleView.setFrameSize(titleView.textLayout?.layoutSize ?? .zero)
        titleView.setFrameOrigin(NSMakePoint(padding, labelView.frame.maxY + 8))

        subtitleView.setFrameSize(subtitleView.textLayout?.layoutSize ?? .zero)
        subtitleView.setFrameOrigin(NSMakePoint(padding, titleView.frame.maxY + 2))

        let trackWidth = bounds.width - padding * 2
        trackView.frame = NSMakeRect(padding, subtitleView.frame.maxY + 18, trackWidth, 10)
        let ratio = item.stats.total > 0 ? CGFloat(item.stats.mine) / CGFloat(item.stats.total) : 0
        mineView.frame = NSMakeRect(0, 0, max(10, floor(trackWidth * ratio)), 10)

        mineLabel.setFrameSize(mineLabel.textLayout?.layoutSize ?? .zero)
        mineLabel.setFrameOrigin(NSMakePoint(padding, trackView.frame.maxY + 8))
        otherLabel.setFrameSize(otherLabel.textLayout?.layoutSize ?? .zero)
        otherLabel.setFrameOrigin(NSMakePoint(bounds.width - padding - otherLabel.frame.width, trackView.frame.maxY + 8))
    }
}

final class VeilStatsHoursRowItem: GeneralRowItem {
    let hours: [Int]

    init(_ initialSize: NSSize, stableId: AnyHashable, hours: [Int]) {
        self.hours = hours
        super.init(initialSize, height: 168, stableId: stableId, viewType: .singleItem)
    }

    override func viewClass() -> AnyClass {
        return VeilStatsHoursRowView.self
    }
}

private final class VeilStatsHoursRowView: GeneralContainableRowView {
    private var bars: [View] = []
    private var axisLabels: [TextView] = []
    private let peakView = TextView()

    private static let padding: CGFloat = 18
    private static let axisHours = [0, 6, 12, 18, 23]

    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        containerView.cornerRadius = 22
        for _ in 0 ..< 24 {
            let bar = View()
            bar.layer?.cornerRadius = 3
            bars.append(bar)
            containerView.addSubview(bar)
        }
        for _ in VeilStatsHoursRowView.axisHours {
            let label = TextView()
            label.userInteractionEnabled = false
            label.isSelectable = false
            label.backgroundColor = .clear
            axisLabels.append(label)
            containerView.addSubview(label)
        }
        peakView.userInteractionEnabled = false
        peakView.isSelectable = false
        peakView.backgroundColor = .clear
        containerView.addSubview(peakView)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func updateColors() {
        super.updateColors()
        borderView.isHidden = true
        containerView.backgroundColor = theme.colors.isDark ? theme.colors.background : .white
    }

    private var peakHour: Int {
        guard let item = item as? VeilStatsHoursRowItem else {
            return 0
        }
        return item.hours.enumerated().max(by: { $0.element < $1.element })?.offset ?? 0
    }

    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        guard let item = item as? VeilStatsHoursRowItem else {
            return
        }
        let accent = veilStatsColor(0x2F5BFF)
        let peak = peakHour
        for (hour, bar) in bars.enumerated() {
            bar.backgroundColor = hour == peak ? accent : accent.withAlphaComponent(theme.colors.isDark ? 0.4 : 0.22)
        }
        for (i, label) in axisLabels.enumerated() {
            let layout = TextViewLayout(.initialize(string: String(format: "%02d", VeilStatsHoursRowView.axisHours[i]), color: theme.colors.grayText, font: .normal(11)))
            layout.measure(width: .greatestFiniteMagnitude)
            label.update(layout)
        }
        let total = item.hours.reduce(0, +)
        let peakText = total > 0 ? "Most active at \(String(format: "%02d:00", peak))" : "No activity yet"
        let peakLayout = TextViewLayout(.initialize(string: peakText, color: theme.colors.text, font: .medium(13)))
        peakLayout.measure(width: .greatestFiniteMagnitude)
        peakView.update(peakLayout)

        updateColors()
        needsLayout = true
    }

    override func layout() {
        super.layout()
        guard let item = item as? VeilStatsHoursRowItem else {
            return
        }
        let bounds = containerView.bounds
        let padding = VeilStatsHoursRowView.padding

        peakView.setFrameSize(peakView.textLayout?.layoutSize ?? .zero)
        peakView.setFrameOrigin(NSMakePoint(padding, padding - 2))

        let chartTop = peakView.frame.maxY + 14
        let axisHeight: CGFloat = 16
        let chartBottom = bounds.height - padding - axisHeight
        let chartHeight = max(10, chartBottom - chartTop)
        let available = bounds.width - padding * 2
        let gap: CGFloat = 4
        let barWidth = max(2, floor((available - gap * 23) / 24))
        let maxValue = max(1, item.hours.max() ?? 1)

        for (hour, bar) in bars.enumerated() {
            let value = CGFloat(item.hours[hour]) / CGFloat(maxValue)
            let height = max(4, floor(chartHeight * value))
            bar.frame = NSMakeRect(padding + CGFloat(hour) * (barWidth + gap), chartBottom - height, barWidth, height)
        }

        for (i, label) in axisLabels.enumerated() {
            label.setFrameSize(label.textLayout?.layoutSize ?? .zero)
            let bar = bars[VeilStatsHoursRowView.axisHours[i]]
            var x = bar.frame.midX - label.frame.width / 2
            x = min(max(padding, x), bounds.width - padding - label.frame.width)
            label.setFrameOrigin(NSMakePoint(x, chartBottom + 4))
        }
    }
}
