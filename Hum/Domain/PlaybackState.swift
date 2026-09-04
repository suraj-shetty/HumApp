import Foundation

enum PlaybackState: Sendable, Equatable, Codable {
    case idle
    case loading
    case playing(HumTrack)
    case paused(HumTrack)
    case failed(HumError)

    var track: HumTrack? {
        switch self {
        case .playing(let t), .paused(let t): t
        case .idle, .loading, .failed: nil
        }
    }

    var isPlaying: Bool {
        if case .playing = self { true } else { false }
    }
}

/// An immutable, `Sendable` view of the player, republished by the adapter.
///
/// This type exists because `ApplicationMusicPlayer.State` is an
/// `ObservableObject`, not `@Observable`, and will not participate in
/// `@Observable` tracking. The adapter bridges it into a stream of these
/// instead of leaking a MusicKit type upward. See ARCHITECTURE.md §3.
struct PlaybackSnapshot: Sendable, Equatable, Codable {
    let state: PlaybackState
    let elapsed: TimeInterval
    let duration: TimeInterval
    let queue: QueueState
    /// `ApplicationMusicPlayer.state.audioVariant` — read-only, real, and
    /// only meaningful while something is actually playing. `nil` idle,
    /// paused, or before MusicKit has reported one yet.
    var audioVariant: HumAudioVariant? = nil

    static let idle = PlaybackSnapshot(
        state: .idle,
        elapsed: 0,
        duration: 0,
        queue: QueueState()
    )
}
