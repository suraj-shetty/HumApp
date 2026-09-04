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
    /// All three chrome surfaces — player capsule, tab capsule, search
    /// island — measure 62pt tall (island 62×62; capsule = 6+50+6). Was 64
    /// (m-4).
    static let chromeHeight: CGFloat = 62
    /// Vertically, between the player capsule and the tab row.
    static let chromeGap: CGFloat = 10
    /// Horizontally, between the tab capsule and the search island — the
    /// design's own value, 2pt wider than the vertical `chromeGap` the two
    /// used to share (m-6).
    static let chromeGapHorizontal: CGFloat = 12
    /// Below the tab row. Handoff: "dock bottom 22pt".
    static let chromeBottom: CGFloat = 22

    /// The player capsule's own corner radius — not `Capsule()`'s automatic
    /// height/2, which no longer lands on this value now that `chromeHeight`
    /// isn't 52 (m-7).
    static let playerCapsuleRadius: CGFloat = 26
    static let tabCapsuleRadius: CGFloat = 28
    static let tabPillHeight: CGFloat = 50
    static let tabPillRadius: CGFloat = 25
    static let tabPillSpacing: CGFloat = 4
    /// Was 7 (m-5); 6+50+6 is what makes the capsule's content land on the
    /// shared `chromeHeight` (62) without an explicit override.
    static let tabCapsulePadding: CGFloat = 6
    static let searchIsland: CGFloat = 62

    /// Library filter chips and the grid they sit above, measured off screen 16.
    static let chipHeight: CGFloat = 38
    static let chipRadius: CGFloat = 19
    static let chipSpacing: CGFloat = 8
    /// Row gap. Column gap is `libraryGridColumnSpacing` — the design runs
    /// the two at different values (22 vs 14), which one shared constant
    /// couldn't represent (m-13).
    static let libraryGridSpacing: CGFloat = 22
    static let libraryGridColumnSpacing: CGFloat = 14

    /// Search's Browse genre grid — two columns, measured off screen 12.
    static let browseGridSpacing: CGFloat = 12
    static let browseTileHeight: CGFloat = 96
    static let browseTileRadius: CGFloat = 12

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
    /// The detail hero — playlist and album alike. Measured 206 square, inset
    /// and centred inside the block's 24pt padding. It was 342 here and drawn
    /// full-bleed in the view, so neither the constant nor the screen matched
    /// the design; both are corrected together.
    ///
    /// Artist detail is the one hero the design *does* run edge to edge, as a
    /// 330pt band. That screen isn't built yet.
    static let artDetailHero: CGFloat = 206
    /// The Now Playing hero. Measured off the design: a 262pt artwork **disc**
    /// centred inside a 304pt progress ring, both inside a 322pt box that
    /// leaves room for the ring's 13pt knob to overhang.
    static let artNowPlaying: CGFloat = 322
    static let artNowPlayingRing: CGFloat = 304
    static let artNowPlayingDisc: CGFloat = 262
    static let progressRingWidth: CGFloat = 3
    static let progressKnob: CGFloat = 13
    /// Screen 26 measures this at 52, radius 8 — its own corner radius
    /// (queried at the call site, not `Metrics.radiusArt`'s shared 10, which
    /// every other art frame in the app reads) (Q-3).
    static let artQueueHeader: CGFloat = 52
    static let radiusArtQueueHeader: CGFloat = 8
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
    /// The detail hero measures 14 — the same law losing to the same rendering,
    /// one size up. Kept as its own name rather than rounded to `radiusArt` so
    /// the divergence stays visible instead of being quietly averaged away.
    static let radiusArtHero: CGFloat = 14

    // MARK: - iPad three-column layout
    //
    // Board 03, measured against its 1194×834 iPad Pro 11″ frame.

    static let iPadSidebarWidth: CGFloat = 260
    static let iPadPlayerColumnWidth: CGFloat = 340
    static let iPadFocusRingWidth: CGFloat = 2
    static let iPadFocusRingOffset: CGFloat = 2
}
