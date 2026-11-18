import AppKit
import os
import SwiftUI
import ThinkingOrbsKit

/// the menu bar icon is the persistent indicator the hud deliberately is
/// not (ADR 0040): your listening orb, in one colour like every menu bar
/// icon, wearing what `DictationCoordinator.badgeLook` says: a take, a
/// meeting's phase, a call nobody records or a setup gap.
@MainActor
enum MenuBarBrandIcon {
    static func image(for look: BadgeLook, orb: ListeningOrb, time: Double) -> NSImage {
        let image = BadgeMarks.image(for: look, orb: glyph(orb, time: time))
        image.accessibilityDescription = accessibilityDescription(for: look) ?? "Andrew Dictate"
        return image
    }

    /// the engine's frame at `time`, from its preset tuned for small sizes.
    static func glyph(_ orb: ListeningOrb, time: Double) -> OrbGlyph {
        let frame = orbFrame(state: state(orb), size: .px20, t: time)
        return OrbGlyph(
            side: Double(OrbSize.px20.rawValue),
            dots: frame.dots.map {
                OrbGlyph.Dot(x: $0.x, y: $0.y, radius: $0.r, alpha: $0.a)
            },
            lines: frame.lines.map {
                OrbGlyph.Line(x1: $0.x1, y1: $0.y1, x2: $0.x2, y2: $0.y2, width: $0.w, alpha: $0.a)
            }
        )
    }

    /// how fast this orb's engine clock runs against the wall clock.
    static func speed(_ orb: ListeningOrb) -> Double {
        resolvePreset(state(orb), .px20).speed
    }

    private static func state(_ orb: ListeningOrb) -> OrbState {
        OrbState(rawValue: orb.rawValue) ?? .composing
    }

    /// what VoiceOver hears for the image itself; the menu bar item's
    /// label says the state in words on top of this.
    private static func accessibilityDescription(
        for look: BadgeLook
    ) -> String? {
        switch look {
        case .idle: nil
        case .dictating: "Andrew Dictate recording"
        case .callNotRecorded: "Andrew Dictate, a call is on"
        // worn while a meeting gets ready and while one is written out:
        // the menu bar item's label says which.
        case .gettingReady: "Andrew Dictate busy with a meeting"
        case .recordingMeeting: "Andrew Dictate recording a meeting"
        case .meetingProblem: "Andrew Dictate has a problem with the meeting"
        case .needsSetup: "Andrew Dictate needs setup"
        }
    }
}

/// the menu bar item's image: your orb, always moving, and at full pace
/// while you talk.
struct MenuBarIcon: View {
    @ObservedObject var coordinator: DictationCoordinator
    @ObservedObject var settings: AppSettings
    @StateObject private var clock = MenuBarOrbClock()

    var body: some View {
        let look = coordinator.badgeLook
        Image(nsImage: clock.restAnimating
            ? MenuBarOrbClock.blank(for: look)
            : MenuBarBrandIcon.image(for: look, orb: settings.listeningOrb, time: clock.time))
            .onChange(of: look, initial: true) { _, look in
                clock.run(look, orb: settings.listeningOrb)
            }
            .onChange(of: settings.listeningOrb) { _, orb in
                clock.run(look, orb: orb)
            }
    }
}

/// the orb's clock in the menu bar. it never stops, unless Reduce Motion is
/// on, when it holds still:
/// - while you talk, SwiftUI draws it fresh at 15 frames a second;
/// - at rest (the plain look only) it drifts slowly forward and back over a
///   loop of frames drawn once and handed to Core Animation, which plays
///   them in the system's render server. redrawing the label through
///   SwiftUI 8 times a second cost ~20% CPU at rest; this costs ~0.
/// the other looks (a meeting, a call, setup) hold a still frame, since
/// they are marks you should be able to read.
@MainActor
final class MenuBarOrbClock: ObservableObject {
    @Published private(set) var time: Double = 1.2
    /// the rest loop is playing in its layer; the label shows a blank.
    @Published private(set) var restAnimating = false

    private static let framesPerSecond: Double = 15
    private static let restFramesPerSecond: Double = 8
    private static let restPace: Double = 0.35
    /// 48 frames at 8 a second: six seconds forward, six back.
    private static let restFrames = 48

    private var timer: Timer?
    private var lastTick = Date()
    private var speed: Double = 1
    private let rest = RestOrbLayer()

    func run(_ look: BadgeLook, orb: ListeningOrb) {
        timer?.invalidate()
        timer = nil
        rest.stop()
        restAnimating = false
        guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else {
            return
        }
        let speed = MenuBarBrandIcon.speed(orb)
        switch look {
        case .dictating:
            self.speed = speed
            lastTick = Date()
            let timer = Timer(timeInterval: 1 / Self.framesPerSecond, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.tick() }
            }
            timer.tolerance = 0.3 / Self.framesPerSecond
            // .common, so it keeps going while the panel is open.
            RunLoop.main.add(timer, forMode: .common)
            self.timer = timer
        case .idle:
            let step = speed * Self.restPace / Self.restFramesPerSecond
            let base = time
            let frames = (0..<Self.restFrames).map { i in
                MenuBarBrandIcon.image(for: .idle, orb: orb, time: base + Double(i) * step)
            }
            restAnimating = rest.play(frames, framesPerSecond: Self.restFramesPerSecond)
        default:
            break
        }
    }

    /// an empty image the size of the icon, so the item keeps its width
    /// while the layer draws the orb.
    static func blank(for look: BadgeLook) -> NSImage {
        let image = NSImage(size: BadgeMarks.size)
        image.isTemplate = true
        image.accessibilityDescription = "Andrew Dictate"
        return image
    }

    private func tick() {
        let now = Date()
        // a stall (sleep, a busy main thread) is not a jump forward.
        time += min(now.timeIntervalSince(lastTick), 0.25) * speed
        lastTick = now
    }
}

/// the rest loop's layer, laid over the menu bar item. it finds the item's
/// view through its window, the one status bar window this app has, and
/// tints the template frames itself in the menu bar's ink, again whenever
/// the menu bar turns light or dark. if the view can't be found it plays
/// nothing and the label keeps its still frame.
@MainActor
private final class RestOrbLayer {
    private static let logger = Logger(subsystem: AppIdentity.loggingSubsystem, category: "menu-bar")
    private let layer = CALayer()
    private var frames: [NSImage] = []
    private var framesPerSecond: Double = 8
    private var appearanceWatch: NSKeyValueObservation?
    private var frameWatch: NSKeyValueObservation?

    func play(_ frames: [NSImage], framesPerSecond: Double) -> Bool {
        guard let host = Self.statusItemView() else {
            Self.logger.notice("rest orb: no menu bar item view found, holding a still frame")
            return false
        }
        self.frames = frames
        self.framesPerSecond = framesPerSecond
        host.wantsLayer = true
        if layer.superlayer == nil {
            host.layer?.addSublayer(layer)
        }
        appearanceWatch = host.observe(\.effectiveAppearance) { [weak self] _, _ in
            Task { @MainActor in self?.animate(in: host) }
        }
        // the item is laid out after it first shows: centre again on every size.
        frameWatch = host.observe(\.frame) { [weak self] _, _ in
            Task { @MainActor in self?.center(in: host) }
        }
        animate(in: host)
        return true
    }

    func stop() {
        appearanceWatch = nil
        frameWatch = nil
        layer.removeAllAnimations()
        layer.removeFromSuperlayer()
    }

    private func animate(in host: NSView) {
        let scale = host.window?.backingScaleFactor ?? 2
        layer.contentsScale = scale
        center(in: host)

        var ink = NSColor.black
        host.effectiveAppearance.performAsCurrentDrawingAppearance {
            ink = NSColor.labelColor.usingColorSpace(.sRGB) ?? .black
        }
        let tinted = frames.compactMap { Self.tint($0, ink: ink, scale: scale) }
        guard tinted.count > 1 else { return }
        // forward, then back without repeating either end: no jump at the turn.
        let loop = tinted + tinted.reversed().dropFirst().dropLast()
        let animation = CAKeyframeAnimation(keyPath: "contents")
        animation.values = loop
        animation.calculationMode = .discrete
        animation.duration = Double(loop.count) / framesPerSecond
        animation.repeatCount = .infinity
        layer.contents = tinted.first
        layer.add(animation, forKey: "orb")
    }

    private func center(in host: NSView) {
        let size = BadgeMarks.size
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.frame = CGRect(
            x: (host.bounds.width - size.width) / 2,
            y: (host.bounds.height - size.height) / 2,
            width: size.width,
            height: size.height
        )
        CATransaction.commit()
    }

    /// a template frame filled with the ink, as the menu bar would tint it.
    private static func tint(_ image: NSImage, ink: NSColor, scale: CGFloat) -> CGImage? {
        let width = Int(image.size.width * scale)
        let height = Int(image.size.height * scale)
        guard let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        let rect = CGRect(x: 0, y: 0, width: width, height: height)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
        image.draw(in: rect)
        NSGraphicsContext.restoreGraphicsState()
        context.setBlendMode(.sourceIn)
        context.setFillColor(ink.cgColor)
        context.fill(rect)
        return context.makeImage()
    }

    /// the menu bar item's own view: the content of this app's status bar
    /// window. an app with one menu bar item has one such window.
    private static func statusItemView() -> NSView? {
        NSApp.windows
            .first { String(describing: type(of: $0)).contains("StatusBarWindow") }?
            .contentView
    }
}
