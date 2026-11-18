import SwiftUI

/// what listens while you talk: which orb, how big, and on what.
struct ListeningPane: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        Form {
            Section {} header: {
                SectionHero(.listening)
            }

            Section {
                OrbGrid(settings: settings)
            } header: {
                Text("Orb")
            } footer: {
                Text("One orb for the whole take. Your voice only changes its pace and size.")
            }

            Section("Look") {
                Picker("Size", selection: $settings.orbSize) {
                    ForEach(OrbSizeChoice.allCases) { size in
                        Text(size.displayName).tag(size)
                    }
                }
                .pickerStyle(.segmented)

                Toggle(isOn: $settings.orbBackground) {
                    Text("Background")
                    Text("A small dark chip behind the orb, so it reads over any window.")
                }
                .toggleStyle(.switch)
            }
        }
        .settingsForm()
    }
}
