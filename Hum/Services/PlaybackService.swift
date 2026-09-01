import Foundation

/// Wraps `ApplicationMusicPlayer.shared` — the app's only playback surface.
///
/// The method list is deliberately closed. Every entry maps to a standard,
/// first-party, user-initiated MusicKit control, which is the brief's
/// compliance requirement. Nothing here alters playback behaviour, skips
/// content, or works around licensing.
protocol PlaybackService: AnyObject, Sendable {
    /// Republished `ApplicationMusicPlayer.State`. See `PlaybackSnapshot` for
    /// why a stream rather than the MusicKit type itself.
    var snapshots: AsyncStream<PlaybackSnapshot> { get }

    func play(_ tracks: [HumTrack], startingAt index: Int) async throws
    func resume() async throws
    func pause() async
    func skipToNext() async throws
    func skipToPrevious() async throws
    /// `ApplicationMusicPlayer.playbackTime`. A standard first-party control
    /// and user-initiated, so it sits inside the compliance rule even though
    /// the brief's shorthand names only play/pause/skip (DECISIONS M-08).
    func seek(to time: TimeInterval) async
    /// Mirrors a `QueueReducer` result onto the player's own queue.
    func applyQueue(_ queue: QueueState) async throws
}
