import SwiftUI

enum PirateIcon {
    case article
    case bell
    case caretDown
    case caretRight
    case caretUp
    case chatCircle
    case check
    case flag
    case flame
    case house
    case list
    case musicNotes
    case pencilSimple
    case plus
    case slidersHorizontal
    case sparkle
    case squaresFour
    case trendUp
    case userCircle
    case users
    case wallet
    case x
}

struct PirateIconView: View {
    let icon: PirateIcon
    var filled = false
    var size: CGFloat = 22
    var color: Color

    @ViewBuilder
    var body: some View {
        if filled {
            PirateFilledIconShape(icon: icon)
                .fill(color, style: FillStyle(eoFill: icon == .userCircle))
                .frame(width: size, height: size)
        } else {
            PirateIconShape(icon: icon)
                .stroke(
                    color,
                    style: StrokeStyle(
                        lineWidth: 2.1,
                        lineCap: .round,
                        lineJoin: .round
                    )
                )
                .frame(width: size, height: size)
        }
    }
}

private struct PirateFilledIconShape: Shape {
    let icon: PirateIcon

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let scaleX = rect.width / 24
        let scaleY = rect.height / 24

        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * scaleX, y: rect.minY + y * scaleY)
        }

        func iconRect(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat) -> CGRect {
            CGRect(
                x: rect.minX + x * scaleX,
                y: rect.minY + y * scaleY,
                width: width * scaleX,
                height: height * scaleY
            )
        }

        func move(_ x: CGFloat, _ y: CGFloat) {
            path.move(to: point(x, y))
        }

        func line(_ x: CGFloat, _ y: CGFloat) {
            path.addLine(to: point(x, y))
        }

        func curve(_ x1: CGFloat, _ y1: CGFloat, _ x2: CGFloat, _ y2: CGFloat, _ x: CGFloat, _ y: CGFloat) {
            path.addCurve(to: point(x, y), control1: point(x1, y1), control2: point(x2, y2))
        }

        func quad(_ x1: CGFloat, _ y1: CGFloat, _ x: CGFloat, _ y: CGFloat) {
            path.addQuadCurve(to: point(x, y), control: point(x1, y1))
        }

        switch icon {
        case .bell:
            move(4.2, 17.2)
            quad(5.7, 16.1, 5.7, 14.7)
            line(5.7, 10.5)
            curve(5.7, 6.6, 8.2, 4, 12, 4)
            curve(15.8, 4, 18.3, 6.6, 18.3, 10.5)
            line(18.3, 14.7)
            quad(18.3, 16.1, 19.8, 17.2)
            quad(20.7, 17.8, 20.2, 18.7)
            quad(20, 19, 19.5, 19)
            line(4.5, 19)
            quad(4, 19, 3.8, 18.7)
            quad(3.3, 17.8, 4.2, 17.2)
            path.closeSubpath()
            move(9.7, 20)
            line(14.3, 20)
            curve(13.7, 21.2, 10.3, 21.2, 9.7, 20)
            path.closeSubpath()

        case .chatCircle:
            path.addRoundedRect(
                in: iconRect(4, 4.8, 16, 12.9),
                cornerSize: CGSize(width: 4.4 * scaleX, height: 4.4 * scaleY)
            )
            move(8.1, 16.4)
            line(5.1, 20)
            quad(4.7, 20.5, 4.2, 20.2)
            quad(3.8, 20, 3.9, 19.4)
            line(4.9, 15.8)
            path.closeSubpath()

        case .house:
            move(3.7, 11)
            line(11.3, 4.8)
            quad(12, 4.2, 12.7, 4.8)
            line(20.3, 11)
            quad(21, 11.6, 20.4, 12.4)
            quad(19.9, 13, 19.2, 12.4)
            line(18, 11.4)
            line(18, 18.9)
            quad(18, 20, 16.9, 20)
            line(14.1, 20)
            line(14.1, 14.6)
            line(9.9, 14.6)
            line(9.9, 20)
            line(7.1, 20)
            quad(6, 20, 6, 18.9)
            line(6, 11.4)
            line(4.8, 12.4)
            quad(4.1, 13, 3.6, 12.4)
            quad(3, 11.6, 3.7, 11)
            path.closeSubpath()

        case .userCircle:
            path.addEllipse(in: iconRect(3, 3, 18, 18))
            path.addEllipse(in: iconRect(8.7, 6.9, 6.6, 6.6))
            move(6.9, 18.4)
            curve(7.9, 15.4, 9.8, 14, 12, 14)
            curve(14.2, 14, 16.1, 15.4, 17.1, 18.4)
            curve(15.8, 19.3, 14.1, 19.8, 12, 19.8)
            curve(9.9, 19.8, 8.2, 19.3, 6.9, 18.4)
            path.closeSubpath()

        case .wallet:
            path.addRoundedRect(
                in: iconRect(3.6, 6.6, 16.8, 12),
                cornerSize: CGSize(width: 3.4 * scaleX, height: 3.4 * scaleY)
            )
            move(5.2, 8.2)
            line(14.5, 5.4)
            quad(16.1, 5, 17.3, 6.6)
            line(5.2, 8.2)
            path.closeSubpath()
            path.addRoundedRect(
                in: iconRect(14.4, 10.7, 6, 4.2),
                cornerSize: CGSize(width: 1.6 * scaleX, height: 1.6 * scaleY)
            )
            path.addEllipse(in: iconRect(16.1, 12, 1.4, 1.4))

        default:
            path = PirateIconShape(icon: icon).path(in: rect)
        }

        return path
    }
}

private struct PirateIconShape: Shape {
    let icon: PirateIcon

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let scaleX = rect.width / 24
        let scaleY = rect.height / 24

        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * scaleX, y: rect.minY + y * scaleY)
        }

        func iconRect(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat) -> CGRect {
            CGRect(
                x: rect.minX + x * scaleX,
                y: rect.minY + y * scaleY,
                width: width * scaleX,
                height: height * scaleY
            )
        }

        func move(_ x: CGFloat, _ y: CGFloat) {
            path.move(to: point(x, y))
        }

        func line(_ x: CGFloat, _ y: CGFloat) {
            path.addLine(to: point(x, y))
        }

        func curve(_ x1: CGFloat, _ y1: CGFloat, _ x2: CGFloat, _ y2: CGFloat, _ x: CGFloat, _ y: CGFloat) {
            path.addCurve(to: point(x, y), control1: point(x1, y1), control2: point(x2, y2))
        }

        func quad(_ x1: CGFloat, _ y1: CGFloat, _ x: CGFloat, _ y: CGFloat) {
            path.addQuadCurve(to: point(x, y), control: point(x1, y1))
        }

        switch icon {
        case .article:
            path.addRoundedRect(in: iconRect(5, 4, 14, 16), cornerSize: CGSize(width: 2.4 * scaleX, height: 2.4 * scaleY))
            move(8, 8)
            line(16, 8)
            move(8, 12)
            line(16, 12)
            move(8, 16)
            line(13.8, 16)

        case .bell:
            move(6, 10.5)
            curve(6, 6.6, 8.5, 4.3, 12, 4.3)
            curve(15.5, 4.3, 18, 6.6, 18, 10.5)
            line(18, 15)
            quad(18.7, 17.1, 20, 18)
            line(4, 18)
            quad(5.3, 17.1, 6, 15)
            line(6, 10.5)
            move(10, 20)
            curve(10.8, 21.1, 13.2, 21.1, 14, 20)

        case .caretDown:
            move(6, 9)
            line(12, 15)
            line(18, 9)

        case .caretRight:
            move(9, 6)
            line(15, 12)
            line(9, 18)

        case .caretUp:
            move(6, 15)
            line(12, 9)
            line(18, 15)

        case .chatCircle:
            path.addRoundedRect(in: iconRect(4.2, 5, 15.6, 12.5), cornerSize: CGSize(width: 4 * scaleX, height: 4 * scaleY))
            move(8, 17.2)
            line(5, 20)
            line(5.9, 15.8)

        case .check:
            move(5, 12.5)
            line(10, 17)
            line(19, 7)

        case .flag:
            move(6, 21)
            line(6, 4)
            move(7, 5)
            curve(10, 3.5, 12.6, 6.4, 16, 4.9)
            curve(15.3, 8, 16.2, 10.4, 18.5, 12.1)
            curve(14.8, 13.9, 11.3, 10.6, 7, 12.2)

        case .flame:
            move(12.4, 21)
            curve(8.2, 20.9, 5.2, 18, 5.2, 14.1)
            curve(5.2, 10.8, 7, 8.4, 10.1, 6.1)
            curve(10.4, 8.2, 11.2, 9.5, 12.2, 10.4)
            curve(13.1, 7.5, 14.9, 5.4, 17.5, 3.7)
            curve(17.4, 7.8, 20, 10.1, 20, 14)
            curve(20, 18.1, 16.7, 20.9, 12.4, 21)
            move(12.2, 17.9)
            curve(10.8, 17.2, 10.2, 16.1, 10.3, 14.8)
            curve(10.4, 13.5, 11.2, 12.3, 12.4, 11.4)
            curve(12.5, 13.1, 13.6, 14, 15, 14.7)
            curve(15, 16.4, 13.9, 17.6, 12.2, 17.9)

        case .house:
            move(4.5, 11.2)
            line(12, 5)
            line(19.5, 11.2)
            move(6.8, 10.4)
            line(6.8, 19)
            line(17.2, 19)
            line(17.2, 10.4)
            move(10, 19)
            line(10, 14.5)
            line(14, 14.5)
            line(14, 19)

        case .list:
            move(5, 7)
            line(19, 7)
            move(5, 12)
            line(19, 12)
            move(5, 17)
            line(19, 17)

        case .musicNotes:
            move(9, 16.8)
            curve(9, 18.3, 7.7, 19.5, 6.2, 19.5)
            curve(4.7, 19.5, 3.5, 18.5, 3.5, 17.2)
            curve(3.5, 15.7, 4.8, 14.5, 6.3, 14.5)
            curve(7.1, 14.5, 8, 14.8, 9, 15.4)
            line(9, 6)
            line(18.8, 4)
            line(18.8, 14.8)
            curve(18.8, 16.3, 17.5, 17.5, 16, 17.5)
            curve(14.5, 17.5, 13.3, 16.5, 13.3, 15.2)
            curve(13.3, 13.7, 14.6, 12.5, 16.1, 12.5)
            curve(17, 12.5, 17.8, 12.8, 18.8, 13.4)
            move(9, 9.4)
            line(18.8, 7.4)

        case .pencilSimple:
            move(5, 18.8)
            line(8.9, 18)
            line(18.2, 8.7)
            curve(19.2, 7.7, 19.2, 6.3, 18.2, 5.3)
            curve(17.2, 4.3, 15.8, 4.3, 14.8, 5.3)
            line(5.5, 14.6)
            line(5, 18.8)
            move(13.6, 6.5)
            line(17, 9.9)

        case .plus:
            move(12, 5)
            line(12, 19)
            move(5, 12)
            line(19, 12)

        case .slidersHorizontal:
            move(4, 7)
            line(9.5, 7)
            move(13.5, 7)
            line(20, 7)
            path.addEllipse(in: iconRect(9.5, 5.5, 4, 3))
            move(4, 12)
            line(6.5, 12)
            move(10.5, 12)
            line(20, 12)
            path.addEllipse(in: iconRect(6.5, 10.5, 4, 3))
            move(4, 17)
            line(13, 17)
            move(17, 17)
            line(20, 17)
            path.addEllipse(in: iconRect(13, 15.5, 4, 3))

        case .sparkle:
            move(12, 3.8)
            line(13.9, 10.1)
            line(20.2, 12)
            line(13.9, 13.9)
            line(12, 20.2)
            line(10.1, 13.9)
            line(3.8, 12)
            line(10.1, 10.1)
            path.closeSubpath()
            move(5.5, 4.8)
            line(5.5, 7.8)
            move(4, 6.3)
            line(7, 6.3)
            move(18.6, 16.2)
            line(18.6, 19)
            move(17.2, 17.6)
                line(20, 17.6)

        case .squaresFour:
            path.addRoundedRect(in: iconRect(4.2, 4.2, 6.4, 6.4), cornerSize: CGSize(width: 1.4 * scaleX, height: 1.4 * scaleY))
            path.addRoundedRect(in: iconRect(13.4, 4.2, 6.4, 6.4), cornerSize: CGSize(width: 1.4 * scaleX, height: 1.4 * scaleY))
            path.addRoundedRect(in: iconRect(4.2, 13.4, 6.4, 6.4), cornerSize: CGSize(width: 1.4 * scaleX, height: 1.4 * scaleY))
            path.addRoundedRect(in: iconRect(13.4, 13.4, 6.4, 6.4), cornerSize: CGSize(width: 1.4 * scaleX, height: 1.4 * scaleY))

        case .trendUp:
            move(4, 17)
            line(9, 12)
            line(13, 15)
            line(20, 7)
            move(15, 7)
            line(20, 7)
            line(20, 12)

        case .userCircle:
            path.addEllipse(in: iconRect(3.5, 3.5, 17, 17))
            path.addEllipse(in: iconRect(9.1, 7.2, 5.8, 5.8))
            move(7.3, 18)
            curve(8.2, 15.4, 10, 14.2, 12, 14.2)
            curve(14, 14.2, 15.8, 15.4, 16.7, 18)

        case .users:
            path.addEllipse(in: iconRect(8.2, 5.2, 6, 6))
            path.addEllipse(in: iconRect(15.1, 7.1, 4.5, 4.5))
            move(4.3, 19)
            curve(5.5, 15.4, 8.2, 13.8, 11.2, 13.8)
            curve(14.2, 13.8, 16.9, 15.4, 18.1, 19)
            move(15.9, 14.3)
            curve(17.7, 14.4, 19.4, 15.6, 20.6, 18.1)

        case .wallet:
            path.addRoundedRect(in: iconRect(3.7, 6.7, 16.6, 11.8), cornerSize: CGSize(width: 3.2 * scaleX, height: 3.2 * scaleY))
            move(5.1, 8.3)
            line(14.2, 5.6)
            quad(16.2, 5.1, 17.4, 6.7)
            move(14.5, 12.6)
            line(20.3, 12.6)
            path.addEllipse(in: iconRect(15.8, 11.3, 1.6, 1.6))

        case .x:
            move(6.5, 6.5)
            line(17.5, 17.5)
            move(17.5, 6.5)
            line(6.5, 17.5)
        }

        return path
    }
}
