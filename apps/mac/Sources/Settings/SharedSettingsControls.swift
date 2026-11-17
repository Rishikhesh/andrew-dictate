import SwiftUI

/// the leading half of a settings row whose control isn't a toggle: a title
/// with its explanation under it, in the system's own type.
struct SettingsRowLabel: View {
    let title: String
    let explanation: String

    init(_ title: String, explanation: String) {
        self.title = title
        self.explanation = explanation
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.capitalizedFirst)
            Text(explanation.capitalizedFirst)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// a switch with its title and explanation, as a grouped form lays one out.
struct SettingsToggleRow: View {
    let title: String
    let explanation: String
    @Binding var isOn: Bool

    init(
        _ title: String,
        explanation: String,
        isOn: Binding<Bool>
    ) {
        self.title = title
        self.explanation = explanation
        _isOn = isOn
    }

    var body: some View {
        Toggle(isOn: $isOn) {
            Text(title.capitalizedFirst)
            Text(explanation.capitalizedFirst)
        }
        .toggleStyle(.switch)
    }
}
