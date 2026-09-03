import CoreGraphics

/// Layout constants extracted from the prototype. See DESIGN_SYSTEM.md §3.
enum Metrics {

    // MARK: - Gutters

    /// Universal screen gutter. Measured from the design's track row, which is
    /// full-width with 20pt of internal padding, so content sits 20 from the
    /// edge — not 24.
    static let gutter: CGFloat = 20
    /// Hero content — detail artwork, Now Playing.
    static let heroGutter: CGFloat = 34
    /// Nav rows sit wider than body content.
    static let navGutter: CGFloat = 18

    // MARK: - Chrome

    static let tabBarHeight: CGFloat = 92
    static let playerBarHeight: CGFloat = 64
    static let playerBarRadius: CGFloat = 32
    static let playerBarInset: CGFloat = 20
    /// Clears the tab bar; the player bar floats above it.
    static let playerBarBottomOffset: CGFloat = 104
    /// Bottom padding for every scroll view, so content clears both chrome
    /// elements rather than sliding under them.
    /// Clearance for a toast floating above the tab bar and its accessory.
    ///
    /// **Not** for scroll content: `TabView`'s bottom accessory and the tab
    /// bar both contribute to the safe area, and SwiftUI already insets
    /// scrolling content for them. Adding this on top stacked two clearances
    /// and left a screen-deep dead gap under the last row of every list.
    static let chromeClearance: CGFloat = 190

    // MARK: - Bottom chrome
    //
    // Measured off the design's Home screen. The three surfaces are laid out
    // as one column so the player capsule and the tab row line up on both
    // edges: 288 + 10 + 64 = 362, the player capsule's exact width.

    /// Both chrome capsules inset 14pt from each edge — the handoff's "safe
    /// inset 14pt". 390 − 28 = 362.
    static let chromeInset: CGFloat = 14
    static let chromeWidth: CGFloat = 362
    static let chromeHeight: CGFloat = 64
    /// Between the player capsule and the tab row, and between the tab capsule
    /// and the search island.
    static let chromeGap: CGFloat = 10
    /// Below the tab row. Handoff: "dock bottom 22pt".
    static let chromeBottom: CGFloat = 22

    static let playerCapsuleRadius: CGFloat = 26
    static let tabCapsuleWidth: CGFloat = 288
    static let tabCapsuleRadius: CGFloat = 28
    static let tabPillWidth: CGFloat = 135
    static let tabPillHeight: CGFloat = 50
    static let tabPillRadius: CGFloat = 25
    static let tabPillSpacing: CGFloat = 4
    static let tabCapsulePadding: CGFloat = 7
    static let searchIsland: CGFloat = 64

    /// Library filter chips and the grid they sit above, measured off screen 16.
    static let chipHeight: CGFloat = 38
    static let chipRadius: CGFloat = 19
    static let chipSpacing: CGFloat = 8
    static let libraryGridSpacing: CGFloat = 22

    // MARK: - Rows

    static let rowSpacing: CGFloat = 14
    static let rowSpacingWide: CGFloat = 16
    static let rowPaddingCompact: CGFloat = 9
    static let rowPadding: CGFloat = 12
    static let rowPaddingRelaxed: CGFloat = 13

    // MARK: - Tap targets
    //
    // The brief's 44pt floor. The prototype already respects it everywhere,
    // so this is carried through verbatim rather than retrofitted.

    static let tapTarget: CGFloat = 44
    static let transportSecondary: CGFloat = 52
    static let transportPrimary: CGFloat = 78
    static let transportPrimaryCompact: CGFloat = 66

    // MARK: - Artwork

    static let artShelf: CGFloat = 160
    static let artDetailHero: CGFloat = 342
    /// The Now Playing hero. Measured off the design: a 262pt artwork **disc**
    /// centred inside a 304pt progress ring, both inside a 322pt box that
    /// leaves room for the ring's 13pt knob to overhang.
    static let artNowPlaying: CGFloat = 322
    static let artNowPlayingRing: CGFloat = 304
    static let artNowPlayingDisc: CGFloat = 262
    static let progressRingWidth: CGFloat = 3
    static let progressKnob: CGFloat = 13
    static let artQueueHeader: CGFloat = 56
    static let artRow: CGFloat = 56
    static let artPlayerBar: CGFloat = 40

    // MARK: - Radii

    /// **One** art radius, at every size. The design's radius scale is
    /// "46 device · 24 sheet · 18 card · 10 art · 22 pill" — a single value for
    /// art. The build had invented four, which is why a shelf card and a row
    /// thumb never quite looked like the same family.
    static let radiusArt: CGFloat = 10
    /// Row thumbnails measure 8, not 10. The design's "one art radius" law and
    /// its own rendering disagree; the rendering wins for visual values, as
    /// settled in DESIGN_AUDIT §9.
    static let radiusArtRow: CGFloat = 8
    /// Cards — shelf tiles and grid cells.
    static let radiusCard: CGFloat = 18
}
