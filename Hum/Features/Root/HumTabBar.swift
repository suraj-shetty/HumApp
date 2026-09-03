import SwiftUI

/// The design's bottom tab bar: a 288pt glass capsule holding two pills, with
/// the search control as its own 64pt circular island beside it.
///
/// **Hand-built, deliberately.** The native `TabView` bar was used until the
/// design was measured properly, and two of its behaviours cannot be reached
/// through it at all:
///
/// - The design labels **only the selected tab**; unselected tabs are icon-only.
///   `TabView` always labels every item.
/// - The capsule is a fixed 288pt, left-aligned, and stays that width when the
///   player bar appears above it. The system container expands the native bar
///   to match its accessory — the divergence reported from device (D-10).
///
/// The cost is real and worth naming: this gives up the system's glass morph
/// between the accessory and the tab bar, and the tab bar half of acceptance
/// criterion 4 ("native glass"). That trade was made explicitly, with design
/// match as the stated priority.
///
/// Glass still comes from `GlassSurface` — the containment script keeps
/// `glassEffect(` in that one file, so this stays inside the architecture.
struct HumTabBar: View {
    @Binding var selection: RootTabView.HumTab
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// The selected pill is one moving view, not a fill that appears and
    /// disappears on two — that is what makes it travel between tabs instead
    /// of blinking from one to the other.
    @Namespace private var pillNamespace

    var body: some View {
        HStack(spacing: Metrics.chromeGap) {
            capsule
            searchIsland
        }
        .frame(maxWidth: .infinity)
    }

    private var capsule: some View {
        HStack(spacing: Metrics.tabPillSpacing) {
            pill(.home, icon: HumIcon.home, filled: HumIcon.homeFilled, label: "Home")
            pill(.library, icon: HumIcon.library, filled: HumIcon.libraryFilled, label: "Library")
        }
        .padding(Metrics.tabCapsulePadding)
        // Width flexes rather than being pinned to the design's 288. The
        // design's rule is the *alignment* — the player capsule and the tab
        // row share both edges — and 390 − 28 − 10 − 64 reproduces 288 exactly
        // on the artboard while staying right on a wider phone.
        .frame(maxWidth: .infinity)
        .frame(height: Metrics.chromeHeight)
        .amberGlass(
            in: RoundedRectangle(cornerRadius: Metrics.tabCapsuleRadius, style: .continuous),
            shadow: false
        )
    }

    private func pill(
        _ tab: RootTabView.HumTab,
        icon: String,
        filled: String,
        label: String
    ) -> some View {
        let isSelected = selection == tab
        return Button {
            withAnimation(Motion.reduced(Motion.tabSelection, when: reduceMotion)) {
                selection = tab
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: isSelected ? filled : icon)
                    .font(.system(size: isSelected ? 21 : 22, weight: .regular))
                    .contentTransition(.symbolEffect(.replace))
                // Only the selected tab carries its label — the design's own
                // rule, and what makes the two pills read as one control.
                if isSelected {
                    Text(label)
                        .humFont(HumTextStyle(size: 13.5, weight: .medium, relativeTo: .caption))
                        .fixedSize()
                        .transition(.opacity.combined(with: .scale(scale: 0.86, anchor: .leading)))
                }
            }
            .foregroundStyle(isSelected ? Palette.honeyAmber : Palette.tabIconInactive)
            .frame(maxWidth: .infinity)
            .frame(height: Metrics.tabPillHeight)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: Metrics.tabPillRadius, style: .continuous)
                        .fill(Palette.tabSelection)
                        .matchedGeometryEffect(id: "tabPill", in: pillNamespace)
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        // One element per tab, with the label spoken whether or not it is
        // drawn — an icon-only unselected tab is still "Library" to VoiceOver.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private var searchIsland: some View {
        Button {
            selection = .search
        } label: {
            Image(systemName: HumIcon.search)
                .font(.system(size: 23, weight: .regular))
                .foregroundStyle(
                    selection == .search ? Palette.honeyAmber : Palette.textPrimary
                )
                .frame(width: Metrics.searchIsland, height: Metrics.searchIsland)
                .amberGlass(in: Circle(), shadow: false)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Search")
        .accessibilityAddTraits(selection == .search ? [.isButton, .isSelected] : .isButton)
    }
}
