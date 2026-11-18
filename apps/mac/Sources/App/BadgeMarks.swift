import AppKit

/// the listening orb the menu bar wears, as geometry: one frame of
/// ThinkingOrbsKit's engine in its own square of `side` units, y down. its
/// own type, so the marks and their tests need no package.
struct OrbGlyph: Sendable {
    struct Dot: Sendable {
        var x, y, radius, alpha: Double
    }

    struct Line: Sendable {
        var x1, y1, x2, y2, width, alpha: Double
    }

    var side: Double
    var dots: [Dot]
    var lines: [Line]

    /// no orb at all: the marks on their own.
    static let none = OrbGlyph(side: 1, dots: [], lines: [])
}

/// every mark the menu bar icon can wear, each one's geometry in one enum
/// below. the icon is your listening orb in one colour, like every other
/// menu bar icon; a meeting puts a red ring round it, a setup gap a red dot
/// on it, a call nobody records a viewfinder in the orb's own colour.
///
/// all of it is drawn in the icon's 18 pt square, y up.
enum BadgeMarks {
    /// the item never changes width, whatever the icon wears: a wider
    /// image shoves every icon to its left sideways and back.
    static let size = NSSize(width: 18, height: 18)

    enum Mark: Equatable, Sendable {
        /// a setup gap: the red dot, top right.
        case setupDot
        /// a call nobody records: a viewfinder, you could catch this.
        case brackets
        /// getting ready, or writing it out: the red ring part of the way round.
        case partRim
        /// recording a meeting: the whole red ring.
        case rim
        /// a meeting's problem: the whole ring, and a red triangle with a "!".
        case warning
    }

    /// which mark each look wears. a take wears none: the orb itself comes
    /// alive while you talk.
    static func mark(for look: BadgeLook) -> Mark? {
        switch look {
        case .idle, .dictating: nil
        case .callNotRecorded: .brackets
        case .gettingReady: .partRim
        case .recordingMeeting: .rim
        case .meetingProblem: .warning
        case .needsSetup: .setupDot
        }
    }

    /// one colour is a template the menu bar tints for Light, Dark, a
    /// highlighted item and an inactive screen. a look with red in it
    /// cannot be, so it draws the orb in the label colour itself.
    static func isTemplate(_ look: BadgeLook) -> Bool {
        switch mark(for: look) {
        case nil, .brackets: true
        case .setupDot, .partRim, .rim, .warning: false
        }
    }

    static func image(for look: BadgeLook, orb: OrbGlyph) -> NSImage {
        let mark = mark(for: look)
        let template = isTemplate(look)
        let image = NSImage(size: size, flipped: false) { rect in
            guard let context = NSGraphicsContext.current?.cgContext else {
                return false
            }
            // resolved as it draws, so the orb follows the menu bar's look.
            let ink: NSColor = template ? .black : .labelColor
            context.saveGState()
            if let keepOut = keepOut(for: mark, in: rect) {
                context.addPath(CGPath(rect: rect, transform: nil).subtracting(keepOut))
                context.clip()
            }
            drawOrb(orb, in: orbRect(for: mark, in: rect), ink: ink, context: context)
            if let mark {
                draw(mark, in: rect, ink: ink, context: context)
            }
            context.restoreGState()
            // what the keep-out made room for, drawn into it.
            if mark == .setupDot {
                context.setFillColor(red.cgColor)
                context.fillEllipse(in: Dot.rect)
            }
            if mark == .warning {
                drawWarning(in: rect, context: context)
            }
            return true
        }
        image.isTemplate = template
        return image
    }

    // MARK: - geometry, one enum per mark

    /// the orb: a point in from every edge, or small enough to sit inside
    /// the ring and the viewfinder with room to breathe.
    enum Orb {
        static let inset: CGFloat = 1
        static let insideInset: CGFloat = 3
    }

    /// 6 pt, top right, with a point and a quarter of nothing round it so
    /// it reads apart from the orb.
    enum Dot {
        static let rect = NSRect(x: 11.5, y: 11.5, width: 6, height: 6)
        static let gap: CGFloat = 1.25
    }

    /// the red ring, its outer edge on the icon's edge.
    enum Rim {
        static let width: CGFloat = 1.5
        /// how far round getting ready goes, clockwise from the top.
        static let readyShare: CGFloat = 0.36
        /// the rest of the way round, so the part reads as a part.
        static let trackOpacity: CGFloat = 0.25
    }

    /// the viewfinder: four corners, each arm this long.
    enum Brackets {
        static let reach: CGFloat = 5
        static let width: CGFloat = 1.5
    }

    /// a red triangle in the bottom-right corner, with a gap round it that
    /// parts it from the ring and the orb.
    enum Warning {
        static let apex = NSPoint(x: 13, y: 9)
        static let baseLeft = NSPoint(x: 9, y: 1)
        static let baseRight = NSPoint(x: 17, y: 1)
        static let gap: CGFloat = 1.25
        static let stem = NSRect(x: 12.5, y: 4, width: 1, height: 2.5)
        static let point = NSRect(x: 12.5, y: 2, width: 1, height: 1)
    }

    // MARK: - drawing

    private static let red = BrandUI.nsColor(BrandUI.attentionRGB)

    private static func orbRect(for mark: Mark?, in rect: NSRect) -> NSRect {
        mark == nil || mark == .setupDot
            ? rect.insetBy(dx: Orb.inset, dy: Orb.inset)
            : rect.insetBy(dx: Orb.insideInset, dy: Orb.insideInset)
    }

    /// where nothing else may draw, so a dot or a triangle sits on a gap
    /// rather than on the orb.
    private static func keepOut(for mark: Mark?, in rect: NSRect) -> CGPath? {
        switch mark {
        case .setupDot:
            CGPath(
                ellipseIn: Dot.rect.insetBy(dx: -Dot.gap, dy: -Dot.gap),
                transform: nil)
        case .warning:
            triangle(in: rect).copy(
                strokingWithWidth: Warning.gap * 2,
                lineCap: .round,
                lineJoin: .round,
                miterLimit: 10
            ).union(triangle(in: rect))
        default:
            nil
        }
    }

    /// the engine's frame, y down in its own units, laid into `target`.
    private static func drawOrb(
        _ orb: OrbGlyph,
        in target: NSRect,
        ink: NSColor,
        context: CGContext
    ) {
        let scale = target.width / orb.side
        func point(_ x: Double, _ y: Double) -> CGPoint {
            CGPoint(x: target.minX + x * scale, y: target.maxY - y * scale)
        }
        context.setLineCap(.round)
        for line in orb.lines {
            context.setStrokeColor(ink.withAlphaComponent(ink.alphaComponent * line.alpha).cgColor)
            context.setLineWidth(line.width * scale)
            context.move(to: point(line.x1, line.y1))
            context.addLine(to: point(line.x2, line.y2))
            context.strokePath()
        }
        for dot in orb.dots {
            let centre = point(dot.x, dot.y)
            let radius = dot.radius * scale
            context.setFillColor(ink.withAlphaComponent(ink.alphaComponent * dot.alpha).cgColor)
            context.fillEllipse(in: CGRect(
                x: centre.x - radius, y: centre.y - radius,
                width: radius * 2, height: radius * 2))
        }
    }

    private static func draw(
        _ mark: Mark,
        in rect: NSRect,
        ink: NSColor,
        context: CGContext
    ) {
        // whole device pixels wide: 2 pt on a 1x screen, 1.5 on a 2x one,
        // never a smeared 1.5 across two pixels.
        let scale = deviceScale(context)
        let width = max(1 / scale, (Rim.width * scale).rounded() / scale)
        let ring = rect.insetBy(dx: width / 2, dy: width / 2)
        context.setLineWidth(width)
        switch mark {
        case .setupDot:
            break
        case .brackets:
            drawBrackets(in: rect, ink: ink, context: context)
        case .partRim:
            context.setStrokeColor(red.withAlphaComponent(Rim.trackOpacity).cgColor)
            context.strokeEllipse(in: ring)
            context.setStrokeColor(red.cgColor)
            context.addArc(
                center: CGPoint(x: ring.midX, y: ring.midY),
                radius: ring.width / 2,
                startAngle: .pi / 2,
                endAngle: .pi / 2 - 2 * .pi * Rim.readyShare,
                clockwise: true)
            context.strokePath()
        case .rim, .warning:
            context.setStrokeColor(red.cgColor)
            context.strokeEllipse(in: ring)
        }
    }

    /// an L in each corner, square ended, on the icon's edge.
    private static func drawBrackets(in rect: NSRect, ink: NSColor, context: CGContext) {
        let reach = Brackets.reach
        let width = Brackets.width
        context.setFillColor(ink.cgColor)
        for (x, y, dx, dy) in [
            (rect.minX, rect.minY, 1.0, 1.0),
            (rect.maxX, rect.minY, -1.0, 1.0),
            (rect.minX, rect.maxY, 1.0, -1.0),
            (rect.maxX, rect.maxY, -1.0, -1.0),
        ] {
            context.fill(CGRect(x: x, y: y, width: reach * dx, height: width * dy).standardized)
            context.fill(CGRect(x: x, y: y, width: width * dx, height: reach * dy).standardized)
        }
    }

    private static func triangle(in rect: NSRect) -> CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: rect.minX + Warning.apex.x, y: rect.minY + Warning.apex.y))
        path.addLine(to: CGPoint(x: rect.minX + Warning.baseRight.x, y: rect.minY + Warning.baseRight.y))
        path.addLine(to: CGPoint(x: rect.minX + Warning.baseLeft.x, y: rect.minY + Warning.baseLeft.y))
        path.closeSubpath()
        return path
    }

    private static func drawWarning(in rect: NSRect, context: CGContext) {
        context.setFillColor(red.cgColor)
        context.addPath(triangle(in: rect))
        context.fillPath()
        // the "!" sits on the triangle's centre line, half a pixel off the
        // grid on a 1x screen: there it moves the half pixel rather than
        // smear over two.
        let scale = deviceScale(context)
        context.setFillColor(NSColor.white.cgColor)
        for part in [Warning.stem, Warning.point] {
            let placed = part.offsetBy(dx: rect.minX, dy: rect.minY)
            context.fill(CGRect(
                x: (placed.minX * scale).rounded() / scale,
                y: (placed.minY * scale).rounded() / scale,
                width: max(1 / scale, (placed.width * scale).rounded() / scale),
                height: (placed.height * scale).rounded() / scale))
        }
    }

    /// pixels per point where this is being drawn: 1 on an external
    /// non-retina screen, 2 on the built-in one.
    private static func deviceScale(_ context: CGContext) -> CGFloat {
        let transform = context.userSpaceToDeviceSpaceTransform
        let scale = hypot(transform.a, transform.b)
        return scale > 0 ? scale : 1
    }
}
