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
    static let scrollBottomInset: CGFloat = 190

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
    static let artRow: CGFloat = 52
    static let artPlayerBar: CGFloat = 46

    // MARK: - Radii

    static let radiusArtLarge: CGFloat = 14
    static let radiusArtMedium: CGFloat = 12
    static let radiusArtShelf: CGFloat = 10
    static let radiusArtSmall: CGFloat = 8
    static let radiusRowThumb: CGFloat = 7
}
