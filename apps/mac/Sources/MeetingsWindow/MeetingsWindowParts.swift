import AppKit
import SwiftUI

/// the small pieces the meetings window is made of, shared by its panes:
/// one set of spacings, the speaker colours, a copy button, a spinner, a
/// shimmer. kept in one place so the sidebar, the panes and the bar cannot
/// drift into three ideas of the same 8.
enum MW {
    /// a date set by a template, `EEE d MMM`, from a formatter made once per
    /// template, calendar and locale. making one is among the slower things
    /// Foundation does, and the rows and the header are drawn again often.
    @MainActor
    static func date(
        _ date: Date, _ template: String,
        calendar: Calendar = .current, locale: Locale = .current
    ) -> String {
        let key = "\(template)|\(locale.identifier)|\(calendar.identifier)|\(calendar.timeZone.identifier)"
        if let formatter = formatters[key] { return formatter.string(from: date) }
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.setLocalizedDateFormatFromTemplate(template)
        formatters[key] = formatter
        return formatter.string(from: date)
    }

    @MainActor private static var formatters: [String: DateFormatter] = [:]

    /// the spacing ladder. nothing in the window uses a gap off it.
    static let s8: CGFloat = 8
    static let s12: CGFloat = 12
    static let s16: CGFloat = 16
    static let s24: CGFloat = 24

    /// the system's red: the one colour that means a mic is open.
    static let recordingRed = Color.red

    /// the motion that moves things in and out of the bar and the panes:
    /// a quick ease-out, so nothing lingers on its way in.
    static let barSpring = Animation.timingCurve(0.23, 1, 0.32, 1, duration: 0.3)
    static let morphSpring = Animation.spring(duration: 0.3, bounce: 0.12)

    /// a label as macOS writes it: its first letter a capital, the rest as
    /// given (a name stays the name it was typed as).
    static func capitalized(_ text: String) -> String {
        text.prefix(1).uppercased() + text.dropFirst()
    }

    static func copy(_ text: String) {
        let board = NSPasteboard.general
        board.clearContents()
        board.setString(text, forType: .string)
    }

    static func animation(_ animation: Animation, reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : animation
    }
}

/// who said it: `you` is the Mac's accent, everyone else cycles four system
/// colours, which keep their contrast in Light and in Dark.
enum SpeakerInk {
    static let others: [Color] = [.teal, .orange, .pink, .purple]

    static func color(_ colour: Int?) -> Color {
        guard let colour else { return AppLook.accent }
        return others[colour % others.count]
    }
}

// MARK: - buttons

/// a 28pt square icon button: quiet until the pointer is on it.
struct MWIconButton: View {
    let symbol: String
    let help: String
    var isDisabled = false
    var tint: Color?
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            MWIconLabel(symbol: symbol, isHovering: isHovering && !isDisabled, tint: tint)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.4 : 1)
        .onHover { isHovering = $0 }
        .help(help)
        .accessibilityLabel(help)
    }
}

struct MWIconLabel: View {
    let symbol: String
    var isHovering = false
    var tint: Color?

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(tint.map(AnyShapeStyle.init)
                ?? (isHovering ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary)))
            .frame(width: 28, height: 28)
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(.primary.opacity(isHovering ? 0.08 : 0))
            }
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

/// copy, then a green check for a moment: the one sign it worked.
struct MWCopyButton: View {
    let help: String
    var isDisabled = false
    let text: () -> String

    @State private var copied = false
    @State private var reset: Task<Void, Never>?

    var body: some View {
        MWIconButton(
            symbol: copied ? "checkmark" : "doc.on.doc", help: help, isDisabled: isDisabled,
            tint: copied ? .green : nil
        ) {
            MW.copy(text())
            copied = true
            reset?.cancel()
            reset = Task {
                try? await Task.sleep(for: .seconds(1.2))
                if !Task.isCancelled { copied = false }
            }
        }
        .contentTransition(.symbolEffect(.replace))
        .animation(.easeOut(duration: 0.2), value: copied)
    }
}

// MARK: - motion

/// an arc going round: working on it, and no promise how long.
struct MWSpinner: View {
    var size: CGFloat = 14
    var lineWidth: CGFloat = 2
    /// the window's tint (the Mac's accent) unless told otherwise.
    var color: Color?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var angle = 0.0

    var body: some View {
        Circle()
            .trim(from: 0, to: 0.28)
            .stroke(color.map(AnyShapeStyle.init) ?? AnyShapeStyle(.tint), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            .frame(width: size, height: size)
            .rotationEffect(.degrees(angle))
            .onAppear {
                // still, when the mac is asked for less motion: the arc
                // alone says it is working.
                guard !reduceMotion else { return }
                withAnimation(.linear(duration: 0.9).repeatForever(autoreverses: false)) {
                    angle = 360
                }
            }
            .accessibilityLabel("Working")
    }
}

/// a light band sliding over placeholder bars while something is being
/// written. still, when the mac is asked for less motion.
struct MWShimmer: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay {
                if !reduceMotion {
                    GeometryReader { proxy in
                        let width = proxy.size.width
                        LinearGradient(
                            colors: [.clear, Color.white.opacity(0.13), .clear],
                            startPoint: .leading, endPoint: .trailing
                        )
                        .frame(width: max(width * 0.5, 1))
                        .offset(x: -width * 0.5 + phase * width * 1.5)
                    }
                    .mask(content)
                    .allowsHitTesting(false)
                }
            }
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}

extension View {
    func mwShimmer() -> some View { modifier(MWShimmer()) }

    /// comes in out of a soft blur, as the notes do when they arrive.
    func mwBlurFade() -> some View {
        transition(.opacity.combined(with: .modifier(
            active: MWBlur(radius: 6), identity: MWBlur(radius: 0))))
    }
}

private struct MWBlur: ViewModifier {
    let radius: CGFloat
    func body(content: Content) -> some View { content.blur(radius: radius) }
}

/// grey bars where the notes will be: three sections of a heading and three
/// lines.
struct MWSkeleton: View {
    private static let lines: [[CGFloat]] = [[1, 0.88, 0.62], [0.94, 0.7, 0.8], [1, 0.76, 0.5]]

    var body: some View {
        VStack(alignment: .leading, spacing: MW.s24) {
            ForEach(0..<3, id: \.self) { section in
                VStack(alignment: .leading, spacing: MW.s12) {
                    bar(width: 0.28, height: 10).opacity(0.7)
                    ForEach(0..<3, id: \.self) { line in
                        bar(width: Self.lines[section][line], height: 10)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .mwShimmer()
        .accessibilityElement()
        .accessibilityLabel("Writing the notes")
    }

    private func bar(width: CGFloat, height: CGFloat) -> some View {
        GeometryReader { proxy in
            RoundedRectangle(cornerRadius: height / 2, style: .continuous)
                .fill(.primary.opacity(0.07))
                .frame(width: proxy.size.width * width, height: height)
        }
        .frame(height: height)
    }
}

/// a rounded module for the pane states (`glassModule`), or a faint wash of
/// `tint` when it carries a warning.
struct MWCard<Content: View>: View {
    var tint: Color?
    @ViewBuilder var content: Content

    @ViewBuilder
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        let card = content
            .padding(MW.s16)
            .frame(maxWidth: .infinity, alignment: .leading)
        if let tint {
            card
                .background(shape.fill(tint.opacity(0.10)))
                .overlay(shape.strokeBorder(tint.opacity(0.28), lineWidth: 0.5))
        } else {
            card.glassModule(cornerRadius: 14)
        }
    }
}

/// the header row of a pane: its name, what it offers on the right.
struct MWPaneHeader<Trailing: View>: View {
    let title: String
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: MW.s8) {
            Text(MW.capitalized(title))
                .font(.headline)
            Spacer(minLength: MW.s8)
            trailing
        }
        .padding(.horizontal, MW.s24)
        .frame(height: 44)
    }
}

/// attributes set by their key types: the key-path spelling
/// (`text.foregroundColor = …`) trips strict concurrency, because the
/// scopes' key paths are not `Sendable`.
extension AttributedString {
    typealias SwiftUIKeys = AttributeScopes.SwiftUIAttributes

    mutating func paint(_ range: Range<Index>, background: Color) {
        self[range][SwiftUIKeys.BackgroundColorAttribute.self] = background
    }

    mutating func paint(_ range: Range<Index>, foreground: Color) {
        self[range][SwiftUIKeys.ForegroundColorAttribute.self] = foreground
    }

    mutating func underline(_ range: Range<Index>) {
        self[range][SwiftUIKeys.UnderlineStyleAttribute.self] = .single
    }

    mutating func setFont(_ range: Range<Index>, _ font: Font) {
        self[range][SwiftUIKeys.FontAttribute.self] = font
    }
}
