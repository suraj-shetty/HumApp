import SwiftUI

/// The design's bottom tab bar: a 288pt glass capsule holding two pills, with
/// the search control as its own 64pt circular island beside it.
///
/// **Search expands in place.** Tapping the island collapses the two pills and
/// grows it into a full-width field with a Cancel beside it — the iOS 26 search
/// -tab behaviour `DESIGN_SYSTEM.md` specified via `Tab(role: .search)`, which
/// D-10 gave up when this bar was hand-built. The design board draws its search
/// field at the top of the Search screen instead (screens 12–14, 33), so this
/// is a departure from the board and a return to the documented behaviour.
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
    @Binding var searchText: String
    /// Where Cancel goes back to. The bar cannot work this out itself — the
    /// two pills are gone by the time there is anything to cancel.
    var onCancelSearch: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// The selected pill is one moving view, not a fill that appears and
    /// disappears on two — that is what makes it travel between tabs instead
    /// of blinking from one to the other.
    @Namespace private var pillNamespace
    @FocusState private var isFieldFocused: Bool

    private var isSearching: Bool { selection == .search }

    var body: some View {
        HStack(spacing: Metrics.chromeGap) {
            // The pills leave and the island takes the width they vacate. One
            // `if` drives both halves, so they cannot disagree about which
            // state the bar is in mid-animation.
            if !isSearching {
                capsule
                    .transition(
                        .opacity.combined(with: .scale(scale: 0.9, anchor: .leading))
                    )
            }

            searchControl

            if isSearching {
                cancelButton
                    .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .trailing)))
            }
        }
        .frame(maxWidth: .infinity)
        .animation(Motion.reduced(Motion.tabSelection, when: reduceMotion), value: isSearching)
        // Focus follows the state rather than the tap, so arriving at Search
        // any other way — a restored selection, a programmatic jump — still
        // opens the keyboard.
        .onChange(of: isSearching) { _, searching in
            isFieldFocused = searching
        }
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
        // Material first, then the design's amber tint over it. Both must name
        // the same shape or the tint clips against a different edge than the
        // material refracts along.
        .chromeGlass(
            in: RoundedRectangle(cornerRadius: Metrics.tabCapsuleRadius, style: .continuous),
            tint: nil
        )
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

    /// The island, and the field it becomes.
    ///
    /// One view across both states rather than two swapped views: the glass has
    /// to be continuous through the morph, and a `Capsule` at 64 × 64 already
    /// draws the circle the collapsed state wants, so the shape never changes —
    /// only the width it is asked to fill.
    ///
    /// It is deliberately not a `Button`. A `TextField` inside a button label
    /// never sees the tap that should put the caret in it.
    private var searchControl: some View {
        HStack(spacing: 10) {
            Image(systemName: HumIcon.search)
                .font(.system(size: 23, weight: .regular))
                .foregroundStyle(isSearching ? Palette.honeyAmber : Palette.textPrimary)
                .accessibilityHidden(true)

            if isSearching {
                TextField("Songs, albums, artists", text: $searchText)
                    .focused($isFieldFocused)
                    .humFont(16)
                    .foregroundStyle(Palette.textPrimary)
                    .tint(Palette.honeyAmber)
                    .submitLabel(.search)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .accessibilityLabel("Search Apple Music")
                    .transition(.opacity)

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                        isFieldFocused = true
                    } label: {
                        Image(systemName: HumIcon.clearField)
                            .font(.system(size: 16, weight: .regular))
                            .foregroundStyle(Palette.textMuted)
                            .frame(width: Metrics.tapTarget, height: Metrics.tapTarget)
                            .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear search")
                    .transition(.opacity)
                }
            }
        }
        .padding(.horizontal, isSearching ? 18 : 0)
        .frame(maxWidth: isSearching ? .infinity : Metrics.searchIsland)
        .frame(height: Metrics.searchIsland)
        .chromeGlass(in: Capsule(style: .continuous), tint: nil)
        .amberGlass(in: Capsule(style: .continuous), shadow: false)
        .contentShape(Capsule(style: .continuous))
        .onTapGesture {
            if isSearching {
                isFieldFocused = true
            } else {
                withAnimation(Motion.reduced(Motion.tabSelection, when: reduceMotion)) {
                    selection = .search
                }
            }
        }
        // Only the collapsed island is a button. Once it is a field, UIKit's
        // own text-field semantics are the correct ones and replacing them
        // with "Search, button" would be a downgrade.
        .accessibilityElement(children: isSearching ? .contain : .ignore)
        .accessibilityLabel(isSearching ? "" : "Search")
        .accessibilityAddTraits(isSearching ? [] : .isButton)
    }

    private var cancelButton: some View {
        Button {
            isFieldFocused = false
            withAnimation(Motion.reduced(Motion.tabSelection, when: reduceMotion)) {
                onCancelSearch()
            }
        } label: {
            Text("Cancel")
                .humFont(16)
                .foregroundStyle(Palette.honeyAmber)
                .fixedSize()
                .frame(minWidth: 44, minHeight: Metrics.tapTarget)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}
