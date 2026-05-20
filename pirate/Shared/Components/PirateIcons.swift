import SwiftUI

enum PirateIcon {
    case article
    case arrowCircleUp
    case arrowClockwise
    case arrowDown
    case arrowSquareOut
    case arrowUp
    case bell
    case broadcast
    case calendar
    case caretDown
    case caretLeft
    case caretRight
    case caretUp
    case caretUpDown
    case chatCircle
    case check
    case checkCircle
    case comments
    case copy
    case crownCross
    case currencyBtc
    case fileText
    case flag
    case flame
    case handPalm
    case house
    case identificationCard
    case image
    case list
    case link
    case lock
    case musicNotes
    case paperPlane
    case pause
    case pencilSimple
    case play
    case plus
    case question
    case qrCode
    case shield
    case slidersHorizontal
    case sparkle
    case squaresFour
    case ticket
    case textAlignLeft
    case trendUp
    case userCircle
    case userPlus
    case users
    case usersThree
    case video
    case wallet
    case warning
    case warningCircle
    case x
}

struct PirateIconView: View {
    let icon: PirateIcon
    var filled = false
    var size: CGFloat = 22
    var color: Color

    var body: some View {
        PirateIconGlyph(icon: icon, filled: filled)
            .foregroundStyle(color)
            .frame(width: size, height: size)
    }
}

struct PirateSystemIconView: View {
    let systemName: String
    var size: CGFloat = 20

    var body: some View {
        PirateIconGlyph(icon: systemIcon.icon, filled: systemIcon.filled)
            .frame(width: size, height: size)
    }

    private var systemIcon: (icon: PirateIcon, filled: Bool) {
        switch systemName {
        case "antenna.radiowaves.left.and.right", "dot.radiowaves.left.and.right":
            return (.broadcast, false)
        case "arrow.clockwise":
            return (.arrowClockwise, false)
        case "arrow.down":
            return (.arrowDown, false)
        case "arrow.up":
            return (.arrowUp, false)
        case "arrow.up.circle":
            return (.arrowCircleUp, false)
        case "arrow.up.right":
            return (.arrowSquareOut, false)
        case "bell":
            return (.bell, false)
        case "bitcoinsign":
            return (.currencyBtc, false)
        case "bolt.shield":
            return (.shield, false)
        case "bubble.left":
            return (.chatCircle, false)
        case "bubble.left.and.text.bubble.right":
            return (.comments, false)
        case "calendar":
            return (.calendar, false)
        case "checkmark":
            return (.check, false)
        case "checkmark.circle":
            return (.checkCircle, false)
        case "checkmark.circle.fill":
            return (.checkCircle, true)
        case "chevron.left":
            return (.caretLeft, false)
        case "chevron.right":
            return (.caretRight, false)
        case "chevron.up.chevron.down":
            return (.caretUpDown, false)
        case "doc.on.doc":
            return (.copy, false)
        case "doc.text":
            return (.fileText, false)
        case "exclamationmark.circle":
            return (.warningCircle, false)
        case "exclamationmark.triangle":
            return (.warning, false)
        case "flag.checkered":
            return (.flag, true)
        case "hand.raised", "hand.raised.fill":
            return (.handPalm, systemName == "hand.raised.fill")
        case "person.text.rectangle", "person.text.rectangle.fill":
            return (.identificationCard, systemName == "person.text.rectangle.fill")
        case "link":
            return (.link, false)
        case "lock":
            return (.lock, false)
        case "lock.fill":
            return (.lock, true)
        case "music.note":
            return (.musicNotes, false)
        case "paperplane.fill":
            return (.paperPlane, true)
        case "pause.fill":
            return (.pause, true)
        case "person.badge.plus":
            return (.userPlus, false)
        case "person.crop.circle":
            return (.userCircle, false)
        case "person.fill":
            return (.userCircle, true)
        case "person.2.fill":
            return (.users, true)
        case "person.3":
            return (.usersThree, false)
        case "photo":
            return (.image, false)
        case "play.fill":
            return (.play, true)
        case "plus":
            return (.plus, false)
        case "qrcode", "qrcode.viewfinder":
            return (.qrCode, false)
        case "slider.horizontal.3":
            return (.slidersHorizontal, false)
        case "text.alignleft":
            return (.textAlignLeft, false)
        case "ticket":
            return (.ticket, false)
        case "video":
            return (.video, false)
        case "xmark":
            return (.x, false)
        default:
            return (.question, false)
        }
    }
}

private struct PirateIconGlyph: View {
    let icon: PirateIcon
    let filled: Bool

    var body: some View {
        Image(assetName)
            .renderingMode(.template)
            .interpolation(.medium)
            .resizable()
            .scaledToFit()
    }

    private var assetName: String {
        filled ? "\(regularAssetName)-fill" : regularAssetName
    }

    private var regularAssetName: String {
        switch icon {
        case .article:
            return "article"
        case .arrowCircleUp:
            return "arrow-circle-up"
        case .arrowClockwise:
            return "arrow-clockwise"
        case .arrowDown:
            return "arrow-down"
        case .arrowSquareOut:
            return "arrow-square-out"
        case .arrowUp:
            return "arrow-up"
        case .bell:
            return "bell"
        case .broadcast:
            return "broadcast"
        case .calendar:
            return "calendar"
        case .caretDown:
            return "caret-down"
        case .caretLeft:
            return "caret-left"
        case .caretRight:
            return "caret-right"
        case .caretUp:
            return "caret-up"
        case .caretUpDown:
            return "caret-up-down"
        case .chatCircle:
            return "chat-circle"
        case .check:
            return "check"
        case .checkCircle:
            return "check-circle"
        case .comments:
            return "comments"
        case .copy:
            return "copy"
        case .crownCross:
            return "crown-cross"
        case .currencyBtc:
            return "currency-btc"
        case .fileText:
            return "file-text"
        case .flag:
            return "flag"
        case .flame:
            return "fire"
        case .handPalm:
            return "hand-palm"
        case .house:
            return "house"
        case .identificationCard:
            return "identification-card"
        case .image:
            return "image"
        case .list:
            return "list"
        case .link:
            return "link"
        case .lock:
            return "lock"
        case .musicNotes:
            return "music-notes"
        case .paperPlane:
            return "paper-plane"
        case .pause:
            return "pause"
        case .pencilSimple:
            return "pencil-simple"
        case .play:
            return "play"
        case .plus:
            return "plus"
        case .qrCode:
            return "qr-code"
        case .question:
            return "question"
        case .shield:
            return "shield"
        case .slidersHorizontal:
            return "sliders-horizontal"
        case .sparkle:
            return "sparkle"
        case .squaresFour:
            return "squares-four"
        case .ticket:
            return "ticket"
        case .textAlignLeft:
            return "text-align-left"
        case .trendUp:
            return "trend-up"
        case .userCircle:
            return "user-circle"
        case .userPlus:
            return "user-plus"
        case .users:
            return "users"
        case .usersThree:
            return "users-three"
        case .video:
            return "video"
        case .wallet:
            return "wallet"
        case .warning:
            return "warning"
        case .warningCircle:
            return "warning-circle"
        case .x:
            return "x"
        }
    }
}
