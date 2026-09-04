import Foundation

/// The relay's wire format between iPhone and Watch — `Codable`, compiled
/// into both targets (see `project.yml`'s `HumWatch` target `sources:`).
/// Deliberately its own type rather than sending `PlaybackSnapshot` itself:
/// the watch only ever reads state, so it gets a flat, already-derived shape
/// (`isPlaying`, not the state machine `PlayerViewModel` derives it from)
/// instead of re-deriving `PlayerViewModel`'s own computed properties a
/// second time on watchOS.
struct WatchPlaybackPayload: Sendable, Codable, Equatable {
    var currentTrack: HumTrack?
    var isPlaying: Bool
    var isBuffering: Bool
    var elapsed: TimeInterval
    var duration: TimeInterval
    var audioVariantLabel: String?
    var upNext: [HumTrack]
    var isInLibrary: Bool

    static let idle = WatchPlaybackPayload(
        currentTrack: nil, isPlaying: false, isBuffering: false,
        elapsed: 0, duration: 0, audioVariantLabel: nil, upNext: [], isInLibrary: false
    )
}

/// Watch → iPhone. The watch never mutates playback itself (Board 03's relay
/// decision) — every one of these just calls the matching, already-existing
/// `PlayerViewModel` method.
enum WatchTransportCommand: Sendable, Codable {
    case togglePlayPause
    case skipToNext
    case skipToPrevious
    /// Up Next's tap-to-jump. The index is relative to the same
    /// `QueueState.entries` the phone holds — the watch only ever displays
    /// `upNext`, so it re-derives the absolute index the same way
    /// `QueueView`'s own `upNextRows` does before sending it.
    case jump(Int)
}
