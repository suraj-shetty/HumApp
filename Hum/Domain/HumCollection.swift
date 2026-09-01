import Foundation

/// An album, playlist, or artist — one shape for all three.
///
/// The three detail screens differ in their header copy and their track-list
/// semantics, not in their data. One type keeps `DetailView` single, which is
/// the whole reason the brief's three detail screens are one phase item.
struct HumCollection: Sendable, Identifiable, Equatable {
    enum Kind: Sendable, Equatable, CaseIterable {
        case album
        case playlist
        case artist
    }

    let id: String
    let kind: Kind
    let title: String
    /// Artist name for an album, curator for a playlist, empty for an artist.
    let subtitle: String
    /// The uppercase overline, e.g. "Album · 2025 · 6 tracks".
    let metaLine: String
    let artworkURL: URL?
    let source: ContentSource
}
