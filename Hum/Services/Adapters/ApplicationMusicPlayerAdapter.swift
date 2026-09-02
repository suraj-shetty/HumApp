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

    /// The last snapshot emitted, so identical ones can be dropped.
    private var last: PlaybackSnapshot?

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

        // Reuse the `Entry` objects the player already holds, matched by item
        // and by repeat. This is the difference between a reorder being a
        // permutation of entries MusicKit has already prepared and it being a
        // brand new queue: constructing fresh entries makes the player re-cue
        // everything, on the main actor, in the middle of a drag — which read
        // on device first as a second-long stall and then as a hang.
        var pool: [String: [ApplicationMusicPlayer.Queue.Entry]] = [:]
        for entry in player.queue.entries {
            guard let id = entry.item?.id.rawValue else { continue }
            pool[id, default: []].append(entry)
        }

        let entries = cued.map { cued -> ApplicationMusicPlayer.Queue.Entry in
            if var existing = pool[cued.track.id], !existing.isEmpty {
                let entry = existing.removeFirst()
                pool[cued.track.id] = existing
                return entry
            }
            // Genuinely new to the queue, so it has to be built.
            return ApplicationMusicPlayer.Queue.Entry(cued.song)
        }

        // `Entries` is MusicKit's own range-replaceable collection, not an
        // Array — assigning through its initializer replaces the queue's
        // contents without tearing down the queue object itself.
        player.queue.entries = ApplicationMusicPlayer.Queue.Entries(entries)
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
        if !unknown.isEmpty {
            let fetched = try await Self.fetchSongs(
                catalog: unknown.filter { $0.source == .catalog }.map { MusicItemID($0.id) },
                library: unknown.filter { $0.source == .library }.map { MusicItemID($0.id) }
            )
            for song in fetched { songs[song.id.rawValue] = song }
        }

        let cued = tracks.compactMap { track in
            songs[track.id].map { CuedTrack(track: track, song: $0) }
        }
        // Keep only what is still cued.
        let live = Set(cued.map(\.track.id))
        songs = songs.filter { live.contains($0.key) }
        return cued
    }

    /// `nonisolated` on purpose: these are network round trips, and running
    /// them on the main actor blocks the UI for as long as they take. A
    /// reorder of already-cued tracks resolves entirely from `songs` and never
    /// reaches this at all.
    private nonisolated static func fetchSongs(
        catalog: [MusicItemID],
        library: [MusicItemID]
    ) async throws -> [Song] {
        var songs: [Song] = []

        if !catalog.isEmpty {
            let request = MusicCatalogResourceRequest<Song>(matching: \.id, memberOf: catalog)
            songs += Array(try await request.response().items)
        }
        if !library.isEmpty {
            var request = MusicLibraryRequest<Song>()
            request.filter(matching: \.id, memberOf: library)
            songs += Array(try await request.response().items)
        }
        return songs
    }

    // MARK: - Publishing

    private func publish() {
        syncCursor()
        updateTicker()
        yield()
    }

    /// The single emit path. Both the change notification and the progress
    /// ticker come through here, so the two can never disagree about what the
    /// player is doing on the same frame — which is what made the play/pause
    /// glyph flicker: one emitter said playing while the other said paused.
    private func yield() {
        let snapshot = PlaybackSnapshot(
            state: currentState,
            elapsed: player.playbackTime,
            // The player reports no duration of its own; the track carries
            // the one MusicKit already gave us.
            duration: queue.currentTrack?.duration ?? 0,
            queue: queue
        )
        // `objectWillChange` fires far more often than anything visible
        // changes. Dropping identical snapshots keeps that churn off the UI.
        guard snapshot != last else { return }
        last = snapshot
        continuation.yield(snapshot)
    }

    /// One derivation of playback state, in precedence order.
    private var currentState: PlaybackState {
        guard let track = queue.currentTrack else {
            return failure.map(PlaybackState.failed) ?? .idle
        }
        switch player.state.playbackStatus {
        case .playing, .seekingForward, .seekingBackward:
            // Sound is coming out, so nothing older than that is still true.
            // Without this, a stale failure outranked the live status forever.
            failure = nil
            return .playing(track)
        default:
            break
        }
        if let failure { return .failed(failure) }
        // MusicKit has no "loading" status, but the play button would
        // otherwise sit visibly dead through a network round trip.
        if isPreparing { return .loading }
        return .paused(track)
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

    /// The tick path. Deliberately *not* `publish()` — that would re-run the
    /// cursor sync and the ticker bookkeeping four times a second for no
    /// reason. The state derivation is shared either way.
    private func emitProgress() {
        guard queue.currentTrack != nil else { return }
        yield()
    }
}
