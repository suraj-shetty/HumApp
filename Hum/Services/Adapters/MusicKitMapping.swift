import Foundation
import MusicKit

/// MusicKit → Domain. The entire type-erasure boundary lives in one file.
///
/// Every mapping takes an explicit `ContentSource` rather than inferring one.
/// Only the adapter that issued the request knows whether it asked the catalog
/// or the library, and the subscription gate is only correct if that answer is
/// (see `ContentSource`). Guessing here would either block a listener from
/// music they own or push them at an offer sheet they don't need.
enum MusicKitMapping {

    /// Sized for the largest place art appears — the Now Playing hero, roughly
    /// 340pt at 3× — and no larger. One URL per track serves every screen, so
    /// this is the ceiling, not the typical case: a 1536px master decoded into
    /// a 40pt player-bar thumb costs real time on every load, and a slow load
    /// is a visible one.
    static let artworkPixels = 1024

    // MARK: - Tracks

    static func track(_ song: Song, source: ContentSource) -> HumTrack {
        HumTrack(
            id: song.id.rawValue,
            title: song.title,
            artist: song.artistName,
            albumTitle: song.albumTitle,
            duration: song.duration ?? 0,
            artworkURL: url(song.artwork),
            source: source
        )
    }

    /// `Track` is MusicKit's song-or-music-video union. Hum plays both through
    /// the same row, so the union's own shared properties are enough — no need
    /// to switch on a case the UI does not distinguish.
    static func track(_ track: Track, source: ContentSource) -> HumTrack {
        HumTrack(
            id: track.id.rawValue,
            title: track.title,
            artist: track.artistName,
            albumTitle: track.albumTitle,
            duration: track.duration ?? 0,
            artworkURL: url(track.artwork),
            source: source
        )
    }

    // MARK: - Collections

    static func collection(_ album: Album, source: ContentSource) -> HumCollection {
        HumCollection(
            id: album.id.rawValue,
            kind: .album,
            title: album.title,
            subtitle: album.artistName,
            metaLine: metaLine("Album", year(album.releaseDate), count(album.trackCount, "track")),
            artworkURL: url(album.artwork),
            source: source
        )
    }

    static func collection(_ playlist: Playlist, source: ContentSource) -> HumCollection {
        HumCollection(
            id: playlist.id.rawValue,
            kind: .playlist,
            title: playlist.name,
            // Apple's own playlists carry a curator; a listener's own do not.
            subtitle: playlist.curatorName ?? "",
            metaLine: "Playlist",
            artworkURL: url(playlist.artwork),
            source: source
        )
    }

    static func collection(_ artist: Artist, source: ContentSource) -> HumCollection {
        HumCollection(
            id: artist.id.rawValue,
            kind: .artist,
            title: artist.name,
            subtitle: "",
            metaLine: "Artist",
            artworkURL: url(artist.artwork),
            source: source
        )
    }

    // MARK: - Helpers

    static func url(_ artwork: Artwork?) -> URL? {
        artwork?.url(width: artworkPixels, height: artworkPixels)
    }

    /// "Album · 2025 · 6 tracks", skipping anything the request didn't return.
    private static func metaLine(_ parts: String?...) -> String {
        parts.compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
    }

    private static func year(_ date: Date?) -> String? {
        date.map { String(Calendar.current.component(.year, from: $0)) }
    }

    private static func count(_ value: Int, _ noun: String) -> String? {
        guard value > 0 else { return nil }
        return "\(value) \(noun)\(value == 1 ? "" : "s")"
    }
}
