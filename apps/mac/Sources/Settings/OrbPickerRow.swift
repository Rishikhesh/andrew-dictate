import SwiftUI
import ThinkingOrbsKit

/// the nine orbs, live, so you choose by watching them.
struct OrbGrid: View {
    @ObservedObject var settings: AppSettings

    private let columns = Array(
        repeating: GridItem(.flexible(), spacing: 8),
        count: 5
    )

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(ListeningOrb.allCases) { orb in
                choice(orb)
            }
        }
        .padding(.vertical, 6)
    }

    private func choice(_ orb: ListeningOrb) -> some View {
        let selected = settings.listeningOrb == orb
        return Button {
            settings.listeningOrb = orb
        } label: {
            VStack(spacing: 6) {
                ThinkingOrb(
                    state: OrbState(rawValue: orb.rawValue) ?? .composing,
                    theme: .auto,
                    displaySize: 44
                )
                .padding(5)
                .background(Circle().fill(.quaternary.opacity(selected ? 1 : 0.4)))
                .overlay(
                    Circle()
                        .strokeBorder(.tint, lineWidth: 2)
                        .opacity(selected ? 1 : 0)
                )
                Text(orb.displayName)
                    .font(.caption)
                    .foregroundStyle(selected ? .primary : .secondary)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(orb.displayName)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
