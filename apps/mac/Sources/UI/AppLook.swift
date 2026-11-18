import AppKit
import SwiftUI

/// the look every window shares since the redesign (settings-c and the
/// menu bar mock): the Mac's own Light or Dark, the Mac's accent colour,
/// Liquid Glass surfaces, sentence case, and one soft glow at the foot of a
/// window. gold stays only in the brand's own marks; nothing here uses it.
///
/// the pieces:
/// - `.glassWindow(glow:)` for a window's whole surface
/// - `.glassModule()` for a rounded, faintly lit group (control center's)
/// - `IconTile` for a symbol in a coloured rounded square (System Settings')
/// - `SectionHero` for the big icon, title and one line atop a pane
/// - `BottomGlow` for the drifting colour at a window's foot
/// - buttons: the system's `.glass` and `.glassProminent` styles, tinted
///   with `AppLook.accent`; key names: `SettingsKeyCap`.
enum AppLook {
    /// the Mac's accent colour, never the app's gold (`SystemAccent`).
    static var accent: Color { SystemAccent.color }

    /// how strong the foot glow is: dimmer in Light, where colour reads louder.
    static func glowOpacity(_ scheme: ColorScheme) -> Double {
        scheme == .dark ? 0.32 : 0.22
    }

    /// the glow's colour for a tint: half the tint, half purple, as in the mock.
    static func glowColor(_ tint: Color) -> Color {
        tint.mix(with: .purple, by: 0.45)
    }
}

/// a soft colour drifting slowly at the bottom of a window. it fades and
/// grows into place when the window opens, eases to a new colour when its
/// tint changes, holds still with Reduce Motion and is gone with Reduce
/// Transparency.
struct BottomGlow: View {
    var tint: Color = AppLook.accent
    var size: CGFloat = 380

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var scheme
    @State private var shown = false
    @State private var drifted = false

    var body: some View {
        if !reduceTransparency {
            Circle()
                .fill(AppLook.glowColor(tint))
                .frame(width: size, height: size)
                .blur(radius: size / 5.5)
                .offset(x: drifted ? -40 : 50, y: size * 0.6 + (drifted ? 18 : -12))
                .scaleEffect(shown ? 1 : 0.8)
                .opacity(shown ? AppLook.glowOpacity(scheme) : 0)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .clipped()
                .allowsHitTesting(false)
                .accessibilityHidden(true)
                .animation(.easeInOut(duration: 0.9), value: tint)
                .onAppear {
                    withAnimation(.timingCurve(0.23, 1, 0.32, 1, duration: 1.4)) {
                        shown = true
                    }
                    guard !reduceMotion else { return }
                    withAnimation(.easeInOut(duration: 24).repeatForever(autoreverses: true)) {
                        drifted = true
                    }
                }
        }
    }
}

/// a window's whole surface: Liquid Glass over the desktop, in the Mac's
/// Light or Dark, with the glow at its foot. the window goes see-through so
/// the glass has something to sample; with Reduce Transparency it is the
/// plain window colour.
private struct GlassWindowSurface: ViewModifier {
    let glow: Color?

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        content
            .background {
                if let glow {
                    BottomGlow(tint: glow)
                }
            }
            .background {
                if reduceTransparency {
                    Color(nsColor: .windowBackgroundColor)
                } else {
                    Color.clear.glassEffect(.regular, in: Rectangle())
                }
            }
            .background(WindowTransparency())
            .tint(AppLook.accent)
    }
}

/// a rounded, faintly lit group: control center's module.
private struct GlassModule: ViewModifier {
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        content
            .background(shape.fill(.primary.opacity(0.05)))
            .overlay(shape.strokeBorder(.primary.opacity(0.08), lineWidth: 0.5))
    }
}

extension View {
    /// the shared window surface; `glow: nil` leaves the foot plain.
    func glassWindow(glow: Color? = AppLook.accent) -> some View {
        modifier(GlassWindowSurface(glow: glow))
    }

    func glassModule(cornerRadius: CGFloat = 16) -> some View {
        modifier(GlassModule(cornerRadius: cornerRadius))
    }
}

/// a symbol in a coloured rounded square, lit from above: System Settings'
/// icon, at any size.
struct IconTile: View {
    let symbol: String
    let tint: Color
    var size: CGFloat = 24

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.55, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(
                LinearGradient(
                    colors: [tint.mix(with: .white, by: 0.2), tint],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                in: RoundedRectangle(cornerRadius: size * 0.27, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: size * 0.27, style: .continuous)
                    .strokeBorder(.white.opacity(0.25), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(size > 40 ? 0.18 : 0), radius: 9, y: 5)
            .accessibilityHidden(true)
    }
}

/// what opens a pane: a big icon, its title and one line on what it is for,
/// centred, as System Settings opens each of its panes.
struct SectionHero: View {
    let symbol: String
    let tint: Color
    let title: String
    let blurb: String

    var body: some View {
        VStack(spacing: 6) {
            IconTile(symbol: symbol, tint: tint, size: 60)
                .padding(.bottom, 6)
            Text(title)
                .font(.title.weight(.bold))
            Text(blurb)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 440)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .accessibilityElement(children: .combine)
    }
}
