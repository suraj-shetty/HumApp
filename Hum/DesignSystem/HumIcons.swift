import SwiftUI

/// SF Symbol names for the prototype's hand-drawn SVG icons.
///
/// Using system symbols rather than shipping the SVGs is a deliberate trade:
/// symbols carry Dynamic Type scaling, optical alignment, and localized
/// accessibility descriptions for free, and the prototype's glyphs are all
/// standard shapes with exact system equivalents.
enum HumIcon {
    // Tabs
    static let home = "house"
    static let homeFilled = "house.fill"
    static let search = "magnifyingglass"
    static let library = "music.note.list"
    static let libraryFilled = "music.note.list"

    // Transport
    static let play = "play.fill"
    static let pause = "pause.fill"
    static let next = "forward.fill"
    static let previous = "backward.fill"
    static let shuffle = "shuffle"
    static let repeatAll = "repeat"
    static let repeatOne = "repeat.1"

    // Now Playing
    static let collapse = "chevron.down"
    static let back = "chevron.left"
    static let queue = "list.bullet.indent"
    static let airplay = "airplayaudio"
    /// The design flanks the volume slider with a silent speaker and a
    /// one-wave speaker — measured 16pt left, 18pt right.
    static let volumeLow = "speaker.fill"
    static let volumeHigh = "speaker.wave.1.fill"
    static let share = "square.and.arrow.up"
    static let overflow = "ellipsis"

    /// The prototype draws a heart here. MusicKit exposes no love/favorite
    /// API, so the real affordance is "Add to Library" (DECISIONS M-04) and
    /// the glyph follows the action rather than the mockup.
    static let addToLibrary = "plus.circle"
    static let inLibrary = "checkmark.circle.fill"

    // Queue
    static let dragHandle = "line.3.horizontal"
    static let remove = "xmark"
    /// The track context menu's "Play Next" / "Add to Queue" (screen 31) —
    /// the same pair of symbols Apple's own Music app uses for the same two
    /// actions.
    static let playNext = "text.line.first.and.arrowtriangle.forward"
    static let addToQueue = "text.line.last.and.arrowtriangle.forward"

    // Search
    /// Clears the search field. Filled rather than bare, matching the design's
    /// ✕-on-a-disc clear chip — a bare glyph reads as decoration at this size.
    static let clearField = "xmark.circle.fill"

    // States
    static let musicNote = "music.note"
    static let person = "person.crop.circle"
    static let settings = "gearshape"
    static let warning = "exclamationmark.triangle"
}
