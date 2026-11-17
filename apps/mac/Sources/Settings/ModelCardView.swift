import SwiftUI

/// one card in a model picker: the radio, the short name, the tradeoff, the
/// size and what choosing it does.
///
/// the picker is the list (ADR 0039) and each job picks its own model from
/// the same cards (ADR 0040) — so the card is handed strings and a closure
/// and knows nothing about dictation or meetings. what a card cannot do is
/// hide the consequence: `trait` and `state` are not optional.
struct ModelCardView<Footer: View>: View {
    let name: String
    /// a word beside the name for a model that is new or unproven, so the
    /// card says so before you pick it rather than after.
    let badge: String?
    let trait: String
    /// on disk if it is there, the estimate if it isn't.
    let size: String
    /// what choosing this card does, said before you do it.
    let state: String
    let isChosen: Bool
    /// the one actually doing the job. gets the pill.
    let isActive: Bool
    /// 0…1 while this model is downloading, nil the rest of the time.
    let progress: Double?
    /// what VoiceOver reads — the long name, not the card's short one.
    let accessibilityName: String
    let choose: () -> Void
    let footer: () -> Footer

    init(
        name: String,
        badge: String? = nil,
        trait: String,
        size: String,
        state: String,
        isChosen: Bool,
        isActive: Bool,
        progress: Double?,
        accessibilityName: String,
        choose: @escaping () -> Void,
        @ViewBuilder footer: @escaping () -> Footer
    ) {
        self.name = name
        self.badge = badge
        self.trait = trait
        self.size = size
        self.state = state
        self.isChosen = isChosen
        self.isActive = isActive
        self.progress = progress
        self.accessibilityName = accessibilityName
        self.choose = choose
        self.footer = footer
    }

    /// one radio row in a grouped form: the choice, why you'd make it,
    /// and what choosing it does, said before you do it.
    var body: some View {
        Button(action: choose) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Image(systemName: isChosen ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(isChosen ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                    .imageScale(.medium)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(name.capitalizedFirst)
                        if let badge {
                            Text(badge.capitalizedFirst)
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .overlay(Capsule().strokeBorder(.quaternary))
                        }
                    }
                    Text(trait.capitalizedFirst)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    footer()
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 6) {
                        if isActive {
                            Text("Active")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.tint)
                        }
                        Text("\(size) · \(state.capitalizedFirst)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    if let progress {
                        ProgressView(value: progress)
                            .frame(width: 120)
                    }
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(badge.map { "\(accessibilityName), \($0)" } ?? accessibilityName)
        .accessibilityAddTraits(isChosen ? .isSelected : [])
    }
}

extension ModelCardView where Footer == EmptyView {
    init(
        name: String,
        badge: String? = nil,
        trait: String,
        size: String,
        state: String,
        isChosen: Bool,
        isActive: Bool,
        progress: Double?,
        accessibilityName: String,
        choose: @escaping () -> Void
    ) {
        self.init(
            name: name,
            badge: badge,
            trait: trait,
            size: size,
            state: state,
            isChosen: isChosen,
            isActive: isActive,
            progress: progress,
            accessibilityName: accessibilityName,
            choose: choose,
            footer: { EmptyView() }
        )
    }
}

/// the model choices as rows of the form section they sit in: each card
/// is its own row, so the form draws the separators.
struct ModelCardGrid<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
    }
}
