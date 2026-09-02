import CoreGraphics

/// Layout constants extracted from the prototype. See DESIGN_SYSTEM.md §3.
enum Metrics {

    // MARK: - Gutters

    /// Universal screen gutter.
    static let gutter: CGFloat = 24
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

    // MARK: - Rows

    static let rowSpacing: CGFloat = 14
    static let rowSpacingWide: CGFloat = 16
    static let rowPaddingCompact: CGFloat = 11
    static let rowPadding: CGFloat = 12
    static let rowPaddingRelaxed: CGFloat = 13

    // MARK: - Tap targets
    //
    // The brief's 44pt floor. The prototype already respects it everywhere,
    // so this is carried through verbatim rather than retrofitted.

    static let tapTarget: CGFloat = 44
    static let transportSecondary: CGFloat = 52
    static let transportPrimary: CGFloat = 76
    static let transportPrimaryCompact: CGFloat = 66

    // MARK: - Artwork

    static let artShelf: CGFloat = 148
    static let artDetailHero: CGFloat = 342
    static let artNowPlaying: CGFloat = 322
    static let artQueueHeader: CGFloat = 56
    static let artRow: CGFloat = 56
    static let artPlayerBar: CGFloat = 40

    // MARK: - Radii

    /// **One** art radius, at every size. The design's radius scale is
    /// "46 device · 24 sheet · 18 card · 10 art · 22 pill" — a single value for
    /// art. The build had invented four, which is why a shelf card and a row
    /// thumb never quite looked like the same family.
    static let radiusArt: CGFloat = 10
    /// Cards — shelf tiles and grid cells.
    static let radiusCard: CGFloat = 18
}
