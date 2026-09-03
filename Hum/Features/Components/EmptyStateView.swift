import SwiftUI

/// The empty/error state, generalised from the one the prototype draws on the
/// Queue screen. **Opaque content.**
///
/// The prototype supplies exactly one of these; Home's two shelves, Search,
/// Library, and every error path need the same shape (DECISIONS M-06, M-12),
/// so it is factored out rather than redrawn per screen.
struct EmptyStateView: View {
    let icon: String
    let headline: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: 14) {
            // A 96×96 amber-35% ring, icon at full strength — measured
            // identically on every empty state this component stands in for
            // except Home's own (screen 10), whose ring runs 112×112; close
            // enough not to fork the component over, far enough to name
            // (finding Q-13). It was missing altogether, and the icon itself
            // was dimmed to 70% where every measured screen draws it solid.
            ZStack {
                Circle()
                    .strokeBorder(Palette.honeyAmber.opacity(0.35), lineWidth: 1)
                    .frame(width: 96, height: 96)
                Image(systemName: icon)
                    .humFont(34, weight: .light)
                    .foregroundStyle(Palette.honeyAmber)
            }
            // Decorative: the headline and message say everything it does.
            .accessibilityHidden(true)

            Text(headline)
                .humFont(HumTextStyle(size: 19, weight: .light, relativeTo: .title))
                .foregroundStyle(Palette.textPrimary)
                .multilineTextAlignment(.center)

            Text(message)
                .humFont(14.5, weight: .light)
                .foregroundStyle(Palette.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .frame(maxWidth: 250)

            if let actionTitle, let action {
                AmberOutlineButton(title: actionTitle, action: action)
                    .padding(.top, 6)
            }
        }
        .padding(.vertical, 56)
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
    }
}

/// A section header — the uppercase wide-tracked overline.
struct SectionHeader: View {
    let title: String
    var trailing: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .humFont(.sectionTitle)
                .foregroundStyle(Palette.textPrimary)
            Spacer(minLength: 8)
            if let trailing {
                Text(trailing)
                    .humFont(.caption)
                    .foregroundStyle(Palette.textMuted)
            }
        }
        .accessibilityAddTraits(.isHeader)
    }
}
