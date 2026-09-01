import Combine
import Foundation
import MusicKit

/// The app's only playback surface: `ApplicationMusicPlayer.shared`.
///
/// Every method maps to one standard, first-party, user-initiated MusicKit
/// control. Nothing here alters playback behaviour, substitutes content, or
/// works around licensing — that is the brief's compliance requirement, and it
/// is why the method list stays closed.
///
/// `@MainActor` because `ApplicationMusicPlayer.shared` is main-actor-bound.
/// Its `state` and `queue` are `ObservableObject`s rather than `@Observable`,
/// so they cannot be handed upward; this class subscribes to them and
/// republishes `Sendable` `PlaybackSnapshot`s instead (ARCHITECTURE §3.1).
@MainActor
final class ApplicationMusicPlayerAdapter: PlaybackService {

    nonisolated let snapshots: AsyncStream<PlaybackSnapshot>
    private let continuation: AsyncStream<PlaybackSnapshot>.Continuation

    private let player = ApplicationMusicPlayer.shared

    /// Hum's mirror of the queue. The *player* owns playback order and timing;
    /// this owns the identities the UI lists, because `Entry` carries no
    /// `HumTrack` and the Queue screen needs one per row.
    private var queue = QueueState()

    /// MusicKit songs backing the entries currently cued, keyed by `HumTrack.id`.
    /// Pruned to the live queue after every change: this is request-shaped
    /// metadata for what is playing right now, not a content cache — Hum
    /// downloads and stores nothing (compliance rule (c)).
    private var songs: [String: Song] = [:]

    /// True between a play intent and the player accepting it. MusicKit has no
    /// "loading" playback status, but the UI needs one or the play button sits
    /// visibly dead through a network round trip.
    private var isPreparing = false
    private var failure: HumError?

    private var cancellables: Set<AnyCancellable> = []
    private var ticker: Task<Void, Never>?

    init() {
        (snapshots, continuation) = AsyncStream.makeStream()

        // `objectWillChange` fires *before* the value settles, so the republish
        // is deferred by one main-actor hop rather than read inline.
        for publisher in [player.state.objectWillChange, player.queue.objectWillChange] {
            publisher
                .sink { [weak self] _ in
                    Task { @MainActor in self?.publish() }
                }
                .store(in: &cancellables)
        }
    }

    // No `deinit` teardown: under Swift 6 a `@MainActor` class's `deinit` is
    // nonisolated and cannot touch these properties. This adapter is owned by
    // `AppEnvironment` and lives for the process, so there is nothing to
    // reclaim — the same reasoning `PlayerViewModel` records.

    // MARK: - Transport

    func play(_ tracks: [HumTrack], startingAt index: Int) async throws {
        failure = nil
        isPreparing = true
        publish()
        defer { isPreparing = false }

        do {
            let cued = try await resolve(tracks)
            guard !cued.isEmpty else {
                throw HumError.playbackFailed("None of those tracks are available.")
            }

            // The requested track may itself have failed to resolve; falling
            // back to the head of the queue beats refusing to play anything.
            let requestedID = tracks[safe: index]?.id
            let start = cued.firstIndex { $0.track.id == requestedID } ?? 0

            player.queue = ApplicationMusicPlayer.Queue(
                for: cued.map(\.song),
                startingAt: cued[start].song
            )
            queue = QueueReducer.reduce(queue, .setQueue(cued.map(\.track), startingAt: start))
            applyModes()

            try await Transport.prepare()
            try await Transport.play()
            publish()
        } catch {
            failure = .playbackFailed(error.localizedDescription)
            publish()
            throw error
        }
    }

    func resume() async throws {
        guard queue.currentTrack != nil else { return }
        failure = nil
        try await Transport.play()
        publish()
    }

    func pause() async {
        player.pause()
        publish()
    }

    func skipToNext() async throws {
        // The reducer decides whether a next entry exists — the same tested
        // function the Queue screen uses — so end-of-queue is a stop, not a
        // thrown MusicKit error surfaced to the listener as "playback failed".
        guard QueueReducer.reduce(queue, .next).currentIndex != nil else {
            player.stop()
            queue.currentIndex = nil
            publish()
            return
        }
        try await Transport.skipToNext()
        publish()
    }

    func skipToPrevious() async throws {
        let retreated = QueueReducer.reduce(queue, .previous)
        // Past the first few seconds, "previous" restarts the current track
        // rather than stepping back — matching the prototype. The reducer
        // returning the same index means there is nothing to step back to.
        if player.playbackTime > Self.restartThreshold
            || retreated.currentIndex == queue.currentIndex {
            player.playbackTime = 0
        } else {
            try await Transport.skipToPrevious()
        }
        publish()
    }

    func seek(to time: TimeInterval) async {
        player.playbackTime = max(0, min(time, queue.currentTrack?.duration ?? time))
        publish()
    }

    private static let restartThreshold: TimeInterval = 4

    /// MusicKit's asynchronous transport methods are `nonisolated async`, so
    /// calling them on a stored player reference from the main actor reads to
    /// the compiler as *sending* a non-Sendable value across isolation.
    /// Reaching for the shared singleton inside the nonisolated call keeps the
    /// reference inside one region — the same player either way, and the only
    /// place these four controls are invoked.
    private enum Transport {
        static func prepare() async throws { try await ApplicationMusicPlayer.shared.prepareToPlay() }
        static func play() async throws { try await ApplicationMusicPlayer.shared.play() }
        static func skipToNext() async throws { try await ApplicationMusicPlayer.shared.skipToNextEntry() }
        static func skipToPrevious() async throws { try await ApplicationMusicPlayer.shared.skipToPreviousEntry() }
    }

    // MARK: - Queue

    func applyQueue(_ newQueue: QueueState) async throws {
        let previousTrackID = queue.currentTrack?.id
        queue = newQueue
        applyModes()

        guard let current = newQueue.currentTrack else {
            // The queue ran out, or every entry was removed. Stop rather than
            // leave the player holding a cursor into nothing.
            player.stop()
            player.queue = ApplicationMusicPlayer.Queue()
            songs.removeAll()
            publish()
            return
        }

        if current.id == previousTrackID {
            // Membership or order changed *around* the playing track — a
            // reorder, a removal, a clear. Mutating the entries in place is
            // what keeps the audio from restarting.
            try await mirrorEntries(newQueue)
        } else {
            // The cursor moved to a different track: a jump, or the playing
            // entry was the one removed. That is a new play intent.
            try await play(newQueue.entries, startingAt: newQueue.currentIndex ?? 0)
        }
        publish()
    }

    private func mirrorEntries(_ state: QueueState) async throws {
        let cued = try await resolve(state.entries)
        let playing = player.queue.currentEntry

        // `Entries` is MusicKit's own range-replaceable collection, not an
        // Array — assigning through its initializer replaces the queue's
        // contents without tearing down the queue object itself.
        player.queue.entries = ApplicationMusicPlayer.Queue.Entries(
            cued.map { entry in
                // Reuse the live entry object for the track that is sounding
                // right now; a replacement entry would restart playback.
                if let playing, playing.item?.id.rawValue == entry.track.id { return playing }
                return ApplicationMusicPlayer.Queue.Entry(entry.song)
            }
        )
    }

    /// Shuffle and repeat are the *player's* modes, not a reordering Hum
    /// performs — `QueueReducer` deliberately moves only the flags.
    private func applyModes() {
        player.state.shuffleMode = queue.shuffleEnabled ? .songs : .off
        player.state.repeatMode = switch queue.repeatMode {
        case .off: MusicPlayer.RepeatMode.none
        case .all: .all
        case .one: .one
        }
    }

    // MARK: - Resolution

    private struct CuedTrack {
        let track: HumTrack
        let song: Song
    }

    /// Turns Hum's provider-neutral tracks back into the MusicKit songs the
    /// player needs, in the order given. Anything that cannot be resolved is
    /// dropped rather than cued as a hole that would stall playback.
    private func resolve(_ tracks: [HumTrack]) async throws -> [CuedTrack] {
        let unknown = tracks.filter { songs[$0.id] == nil }
        let catalogIDs = unknown.filter { $0.source == .catalog }.map { MusicItemID($0.id) }
        let libraryIDs = unknown.filter { $0.source == .library }.map { MusicItemID($0.id) }

        if !catalogIDs.isEmpty {
            let request = MusicCatalogResourceRequest<Song>(matching: \.id, memberOf: catalogIDs)
            for song in try await request.response().items { songs[song.id.rawValue] = song }
        }
        if !libraryIDs.isEmpty {
            var request = MusicLibraryRequest<Song>()
            request.filter(matching: \.id, memberOf: libraryIDs)
            for song in try await request.response().items { songs[song.id.rawValue] = song }
        }

        let cued = tracks.compactMap { track in
            songs[track.id].map { CuedTrack(track: track, song: $0) }
        }
        // Keep only what is still cued.
        let live = Set(cued.map(\.track.id))
        songs = songs.filter { live.contains($0.key) }
        return cued
    }

    // MARK: - Publishing

    private func publish() {
        syncCursor()
        updateTicker()

        let track = queue.currentTrack
        let state: PlaybackState
        if let failure {
            state = .failed(failure)
        } else if isPreparing {
            state = .loading
        } else {
            state = switch (track, player.state.playbackStatus) {
            case (nil, _): .idle
            case (let track?, .playing), (let track?, .seekingForward),
                 (let track?, .seekingBackward): .playing(track)
            case (let track?, _): .paused(track)
            }
        }

        continuation.yield(
            PlaybackSnapshot(
                state: state,
                elapsed: player.playbackTime,
                // The player reports no duration of its own; the track carries
                // the one MusicKit already gave us.
                duration: track?.duration ?? 0,
                queue: queue
            )
        )
    }

    /// Follows the player when it advances on its own — at the end of a track,
    /// or from the lock screen and Dynamic Island, which drive the same shared
    /// player Hum does.
    private func syncCursor() {
        guard let playingID = player.queue.currentEntry?.item?.id.rawValue else { return }
        guard let index = queue.entries.firstIndex(where: { $0.id == playingID }),
              index != queue.currentIndex
        else { return }
        queue.currentIndex = index
    }

    /// `playbackTime` has no change notification, so progress is polled.
    /// 4 Hz is smooth for a progress bar at a fraction of the cost of 60
    /// (ARCHITECTURE §3.2). The ticker only runs while sound is coming out.
    private func updateTicker() {
        let shouldTick = player.state.playbackStatus == .playing
        if shouldTick, ticker == nil {
            ticker = Task { [weak self] in
                while !Task.isCancelled {
                    try? await Task.sleep(for: .milliseconds(250))
                    guard let self else { return }
                    self.emitProgress()
                }
            }
        } else if !shouldTick {
            ticker?.cancel()
            ticker = nil
        }
    }

    /// The tick path. Deliberately *not* `publish()` — that would recurse
    /// through `updateTicker()` four times a second for no reason.
    private func emitProgress() {
        guard let track = queue.currentTrack else { return }
        continuation.yield(
            PlaybackSnapshot(
                state: player.state.playbackStatus == .playing ? .playing(track) : .paused(track),
                elapsed: player.playbackTime,
                duration: track.duration,
                queue: queue
            )
        )
    }
}
