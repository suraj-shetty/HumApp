import Foundation

/// A track, in Hum's own vocabulary.
///
/// Deliberately provider-neutral: nothing MusicKit-shaped appears here, so the
/// entire app above `Services/Adapters/` compiles and runs without MusicKit —
/// which is what makes Simulator development possible at all (DECISIONS M-09).
struct HumTrack: Sendable, Identifiable, Equatable, Codable {
    /// `MusicItemID.rawValue` in the live adapter.
    let id: String
    let title: String
    let artist: String
    let albumTitle: String?
    let duration: TimeInterval
    let artworkURL: URL?
    let source: ContentSource

    init(
        id: String,
        title: String,
        artist: String,
        albumTitle: String? = nil,
        duration: TimeInterval = 0,
        artworkURL: URL? = nil,
        source: ContentSource = .catalog
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.albumTitle = albumTitle
        self.duration = duration
        self.artworkURL = artworkURL
        self.source = source
    }
}
