import AppKit
import XCTest

/// what a person checks by eye, asked of the rendered pixels at 1x and 2x:
/// where the red and the orb's ink land, and where they don't. no
/// whole-image snapshots, so a nudge to a mark's geometry fails only if it
/// moves a mark somewhere it should not be.
final class BadgeMarksTests: XCTestCase {
    private let scales = [1, 2]

    /// the item never changes width: a wider image shoves every icon to
    /// its left sideways and back.
    func testEveryLookKeepsTheItemEighteenPointsSquare() {
        for look in BadgeLook.allCases {
            let image = BadgeMarks.image(for: look, orb: orb)

            XCTAssertEqual(image.size, NSSize(width: 18, height: 18), "\(look)")
        }
    }

    /// one colour is a template, so it matches every other menu bar icon
    /// in Light and Dark; only a look with red in it draws its own colours.
    func testOnlyTheLooksWithRedInThemAreNotTemplates() {
        let coloured: Set<String> = ["gettingReady", "recordingMeeting", "meetingProblem", "needsSetup"]
        for look in BadgeLook.allCases {
            XCTAssertEqual(
                BadgeMarks.image(for: look, orb: orb).isTemplate,
                !coloured.contains("\(look)"),
                "\(look)")
        }
    }

    func testTheBareOrbIsDrawnAndNothingRed() {
        for scale in scales {
            for look in [BadgeLook.idle, .dictating] {
                let rendered = render(look, scale: scale)

                XCTAssertTrue(rendered.hasInk(in: NSRect(x: 7, y: 7, width: 4, height: 4)), "\(look) \(scale)x")
                XCTAssertEqual(rendered.count(of: red, outside: .zero), 0, "\(look) \(scale)x")
            }
        }
    }

    func testRecordingIsRedAllTheWayRound() {
        for scale in scales {
            let rendered = render(.recordingMeeting, scale: scale, orb: .none)

            for edge in Edge.allCases {
                XCTAssertTrue(
                    rendered.has(red, in: edge.middle),
                    "\(edge) at \(scale)x"
                )
            }
        }
    }

    func testGettingReadyIsRedOnlyPartOfTheWayRound() {
        for scale in scales {
            let rendered = render(.gettingReady, scale: scale, orb: .none)
            let redEdges = Edge.allCases.filter {
                rendered.has(red, in: $0.middle)
            }

            XCTAssertFalse(redEdges.isEmpty, "\(scale)x")
            XCTAssertLessThan(redEdges.count, 4, "\(scale)x")
        }
    }

    func testACallIsMarkedAtTheCornersAndNotBetween() {
        for scale in scales {
            let rendered = render(.callNotRecorded, scale: scale, orb: .none)

            for corner in corners {
                XCTAssertTrue(
                    rendered.hasInk(in: corner),
                    "corner \(corner) at \(scale)x"
                )
            }
            for edge in Edge.allCases {
                XCTAssertFalse(
                    rendered.hasInk(in: edge.middle),
                    "\(edge) at \(scale)x"
                )
            }
        }
    }

    /// the ring, and a red triangle in the bottom-right corner carrying a
    /// white "!".
    func testAProblemHasTheRingAndAWarningInTheBottomRightCorner() {
        let bottomRight = NSRect(x: 9, y: 0, width: 9, height: 9)
        for scale in scales {
            let rendered = render(.meetingProblem, scale: scale)

            XCTAssertTrue(rendered.has(red, in: Edge.top.middle), "\(scale)x")
            XCTAssertTrue(rendered.has(red, in: NSRect(x: 11, y: 2, width: 4, height: 2)), "\(scale)x")
            XCTAssertTrue(
                rendered.has(white, in: NSRect(x: 12, y: 2, width: 2, height: 4.5)),
                "\(scale)x"
            )
            XCTAssertTrue(rendered.has(red, in: bottomRight), "\(scale)x")
        }
    }

    func testSetupKeepsItsRedDotInTheTopRightCorner() {
        let topRight = NSRect(x: 10, y: 10, width: 8, height: 8)
        for scale in scales {
            let rendered = render(.needsSetup, scale: scale)

            XCTAssertTrue(rendered.has(red, in: topRight), "\(scale)x")
            XCTAssertEqual(rendered.count(of: red, outside: topRight), 0, "\(scale)x")
        }
    }

    // MARK: - what is looked for, and where

    private let red = BrandUI.attentionRGB
    private let white: [Double] = [255, 255, 255]

    /// a stand-in orb: one solid dot filling the middle, enough to see
    /// where the orb lands without the engine.
    private let orb = OrbGlyph(
        side: 20,
        dots: [OrbGlyph.Dot(x: 10, y: 10, radius: 4, alpha: 1)],
        lines: []
    )

    /// two points deep along each edge, four long round its middle: where
    /// a ring lies and a corner bracket does not reach.
    private enum Edge: CaseIterable {
        case top, right, bottom, left

        var middle: NSRect {
            switch self {
            case .top: NSRect(x: 7, y: 16, width: 4, height: 2)
            case .right: NSRect(x: 16, y: 7, width: 2, height: 4)
            case .bottom: NSRect(x: 7, y: 0, width: 4, height: 2)
            case .left: NSRect(x: 0, y: 7, width: 2, height: 4)
            }
        }
    }

    /// three points square: where a viewfinder's corner lies.
    private let corners = [
        NSRect(x: 0, y: 0, width: 3, height: 3),
        NSRect(x: 15, y: 0, width: 3, height: 3),
        NSRect(x: 0, y: 15, width: 3, height: 3),
        NSRect(x: 15, y: 15, width: 3, height: 3)
    ]

    // MARK: - rendering

    private func render(_ look: BadgeLook, scale: Int, orb: OrbGlyph? = nil) -> Rendered {
        render(BadgeMarks.image(for: look, orb: orb ?? self.orb), scale: scale)
    }

    /// drawn the way the menu bar draws it: into a context with `scale`
    /// pixels per point, transparent behind.
    private func render(_ image: NSImage, scale: Int) -> Rendered {
        let side = 18 * scale
        let context = CGContext(
            data: nil,
            width: side,
            height: side,
            bitsPerComponent: 8,
            bytesPerRow: side * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.scaleBy(x: CGFloat(scale), y: CGFloat(scale))
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(
            cgContext: context,
            flipped: false
        )
        image.draw(in: NSRect(x: 0, y: 0, width: 18, height: 18))
        NSGraphicsContext.restoreGraphicsState()

        let bytes = context.data!.assumingMemoryBound(to: UInt8.self)
        return Rendered(
            scale: scale,
            bytes: Array(UnsafeBufferPointer(start: bytes, count: side * side * 4))
        )
    }

}

/// a rendered badge, RGBA, top row first.
private struct Rendered: Equatable {
    let scale: Int
    let bytes: [UInt8]

    /// an opaque pixel within a few values of `rgb` in every channel: the
    /// mark itself, not an edge blended into the badge behind it.
    func has(_ rgb: [Double], in region: NSRect) -> Bool {
        pixels(in: region).contains { Self.matches($0, rgb) }
    }

    /// an opaque pixel of any colour: the orb or a mark drawn in its ink.
    func hasInk(in region: NSRect) -> Bool {
        pixels(in: region).contains { $0[3] > 200 }
    }

    func count(of rgb: [Double], outside region: NSRect) -> Int {
        let everywhere = NSRect(x: 0, y: 0, width: 18, height: 18)
        let inside = pixels(in: region).filter { Self.matches($0, rgb) }.count
        return pixels(in: everywhere).filter { Self.matches($0, rgb) }.count
            - inside
    }

    /// every pixel whose centre lies in `region`, given in points, y up
    /// like the drawing.
    private func pixels(in region: NSRect) -> [[UInt8]] {
        let side = 18 * scale
        var found: [[UInt8]] = []
        for row in 0..<side {
            for column in 0..<side {
                let centre = NSPoint(
                    x: (Double(column) + 0.5) / Double(scale),
                    y: 18 - (Double(row) + 0.5) / Double(scale)
                )
                guard region.contains(centre) else {
                    continue
                }
                let start = (row * side + column) * 4
                found.append(Array(bytes[start..<start + 4]))
            }
        }
        return found
    }

    private static func matches(_ pixel: [UInt8], _ rgb: [Double]) -> Bool {
        pixel[3] == 255
            && (0..<3).allSatisfy { abs(Double(pixel[$0]) - rgb[$0]) <= 16 }
    }
}
