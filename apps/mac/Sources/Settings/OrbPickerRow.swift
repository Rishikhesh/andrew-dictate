import SwiftUI
import ThinkingOrbsKit

/// which orb listens while you talk: all nine, live, so you choose by
/// watching them; and whether it sits on its dark chip.
struct OrbPickerRow: View {
    @ObservedObject var settings: AppSettings

    private let columns = Array(
        repeating: GridItem(.flexible(), spacing: 8),
        count: 5
    )

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SettingsRowLabel(
                "orb",
                explanation: "what listens while you talk. one for the whole take; your voice only changes its pace and size."
            )

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(ListeningOrb.allCases) { orb in
                    choice(orb)
                }
            }

            HStack {
                SettingsRowLabel("size", explanation: "how big the orb is drawn while you talk.")
                Spacer(minLength: 8)
                Picker("size", selection: $settings.orbSize) {
                    ForEach(OrbSizeChoice.allCases) { size in
                        Text(size.displayName).tag(size)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
            }

            SettingsToggleRow(
                "background",
                explanation: "a small dark chip behind the orb, so it reads over any window.",
                isOn: $settings.orbBackground
            )
        }
    }

    private func choice(_ orb: ListeningOrb) -> some View {
        let selected = settings.listeningOrb == orb
        return Button {
            settings.listeningOrb = orb
        } label: {
            VStack(spacing: 5) {
                ThinkingOrb(
                    state: OrbState(rawValue: orb.rawValue) ?? .composing,
                    theme: .auto,
                    displaySize: 40
                )
                .padding(4)
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
