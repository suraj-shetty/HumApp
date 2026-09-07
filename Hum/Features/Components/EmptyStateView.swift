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
    /// Overrides the ring/icon color — `Palette.terracotta` for an error
    /// state (e.g. Detail's failed-to-load), amber (the default) for an
    /// empty-but-not-broken one.
    var tint: Color = Palette.honeyAmber
    /// Overrides the ring diameter — Home's own empty state (screen 10)
    /// measures 112, every other measured screen 96.
    var ringDiameter: CGFloat = 96

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
                    .strokeBorder(tint.opacity(0.35), lineWidth: 1)
                    .frame(width: ringDiameter, height: ringDiameter)
                Image(systemName: icon)
                    .humFont(34, weight: .light)
                    .foregroundStyle(tint)
            }
            // Decorative: the headline and message say everything it does.
            .accessibilityHidden(true)

            // 21px, not 19 — measured identically across every empty/error
            // screen this component stands in for (12, 15, 18, 27), so this
            // is a uniform correction to the shared value, not a per-screen
            // fork (Q-14).
            Text(headline)
                .humFont(HumTextStyle(size: 21, weight: .light, relativeTo: .title))
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
