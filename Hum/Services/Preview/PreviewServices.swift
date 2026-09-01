import Foundation

/// In-memory service implementations used until the MusicKit adapters land.
///
/// These exist because MusicKit does not function in the Simulator at all — no
/// account, no playback stack (DECISIONS M-09). Without them the entire UI
/// phase would be blocked on a provisioned device. They are the second reason
/// the protocol boundary exists in a single-provider app.
///
/// Fixture data is lifted verbatim from `designs/Hum Prototype.html`, so the
/// screens render with the content they were designed against.
enum PreviewFixtures {

    static let tracks: [HumTrack] = [
        .init(id: "t0", title: "Slow Water",      artist: "Ana Roele", albumTitle: "Longer Evenings", duration: 222),
        .init(id: "t1", title: "Paper Lanterns",  artist: "Ana Roele", albumTitle: "Longer Evenings", duration: 258),
        .init(id: "t2", title: "Held Note",       artist: "Ana Roele", albumTitle: "Longer Evenings", duration: 176),
        .init(id: "t3", title: "Low Ceiling",     artist: "Ana Roele", albumTitle: "Longer Evenings", duration: 304),
        .init(id: "t4", title: "Quiet Room, Late", artist: "Ana Roele", albumTitle: "Longer Evenings", duration: 209),
        .init(id: "t5", title: "Hum",             artist: "Ana Roele", albumTitle: "Longer Evenings", duration: 287),
    ]

    static let collections: [HumCollection] = [
        .init(id: "c0", kind: .album, title: "Longer Evenings", subtitle: "Ana Roele",
              metaLine: "Album · 2025 · 6 tracks", artworkURL: nil, source: .catalog),
        .init(id: "c1", kind: .album, title: "Second Floor", subtitle: "Miel Hask",
              metaLine: "Album · 2024 · 9 tracks", artworkURL: nil, source: .catalog),
        .init(id: "c2", kind: .playlist, title: "Tuesday Tape", subtitle: "Hum",
              metaLine: "Playlist · 24 tracks", artworkURL: nil, source: .library),
    ]
}

actor PreviewAuthorizationService: MusicAuthorizationService {
    private var status: AuthState
    init(status: AuthState = .authorized) { self.status = status }

    var current: AuthState { status }

    func request() async -> AuthState {
        guard status == .notDetermined else { return status }
        try? await Task.sleep(for: .milliseconds(1200))  // the prototype's spinner
        status = .authorized
        return status
    }
}

actor PreviewSubscriptionService: SubscriptionService {
    private let state: SubscriptionState
    nonisolated let updates: AsyncStream<SubscriptionState>

    init(state: SubscriptionState = .active) {
        self.state = state
        // No emissions: preview state is fixed. A finished stream lets
        // observers complete cleanly instead of suspending forever.
        updates = AsyncStream { $0.finish() }
    }

    var current: SubscriptionState { state }
}

actor PreviewCatalogService: MusicCatalogService {
    func search(_ term: String) async throws -> [HumTrack] {
        guard !term.trimmingCharacters(in: .whitespaces).isEmpty else { return [] }
        return PreviewFixtures.tracks.filter {
            $0.title.localizedCaseInsensitiveContains(term)
                || $0.artist.localizedCaseInsensitiveContains(term)
        }
    }

    func recentlyPlayed() async throws -> [HumCollection] { PreviewFixtures.collections }
    func recommendations() async throws -> [HumTrack] { PreviewFixtures.tracks }
    func tracks(in collection: HumCollection) async throws -> [HumTrack] {
        PreviewFixtures.tracks
    }
}

actor PreviewLibraryService: MusicLibraryService {
    private var added: Set<String> = []

    func albums() async throws -> [HumCollection] {
        PreviewFixtures.collections.filter { $0.kind == .album }
    }

    func playlists() async throws -> [HumCollection] {
        PreviewFixtures.collections.filter { $0.kind == .playlist }
    }

    func add(_ track: HumTrack) async throws { added.insert(track.id) }
    func contains(_ track: HumTrack) async throws -> Bool { added.contains(track.id) }
}

/// A playback service that actually advances time, so progress bars, the
/// level meter, and track transitions can all be exercised without audio.
actor PreviewPlaybackService: PlaybackService {
    nonisolated let snapshots: AsyncStream<PlaybackSnapshot>
    private let continuation: AsyncStream<PlaybackSnapshot>.Continuation

    private var queue = QueueState()
    private var isPlaying = false
    private var elapsed: TimeInterval = 0
    private var ticker: Task<Void, Never>?

    init() {
        (snapshots, continuation) = AsyncStream.makeStream()
    }

    deinit {
        ticker?.cancel()
        continuation.finish()
    }

    // MARK: - PlaybackService

    func play(_ tracks: [HumTrack], startingAt index: Int) async throws {
        queue = QueueReducer.reduce(queue, .setQueue(tracks, startingAt: index))
        elapsed = 0
        isPlaying = true
        startTicking()
        publish()
    }

    func resume() async throws {
        guard queue.currentTrack != nil else { return }
        isPlaying = true
        startTicking()
        publish()
    }

    func pause() async {
        isPlaying = false
        ticker?.cancel()
        ticker = nil
        publish()
    }

    func skipToNext() async throws {
        queue = QueueReducer.reduce(queue, .next)
        elapsed = 0
        if queue.currentTrack == nil { await pause() } else { publish() }
    }

    func skipToPrevious() async throws {
        // Matches the prototype: past the first few seconds, "previous"
        // restarts the current track rather than stepping back.
        if elapsed > 4 {
            elapsed = 0
        } else {
            queue = QueueReducer.reduce(queue, .previous)
            elapsed = 0
        }
        publish()
    }

    func seek(to time: TimeInterval) async {
        elapsed = max(0, min(time, queue.currentTrack?.duration ?? 0))
        publish()
    }

    func applyQueue(_ newQueue: QueueState) async throws {
        let wasPlaying = queue.currentTrack
        queue = newQueue
        if queue.currentTrack?.id != wasPlaying?.id { elapsed = 0 }
        if queue.currentTrack == nil { await pause() } else { publish() }
    }

    // MARK: - Simulated transport

    private func startTicking() {
        ticker?.cancel()
        ticker = Task { [weak self] in
            // 4 Hz: enough for a smooth progress bar, a fraction of the work
            // of a 60 Hz timer. The real adapter uses the same rate because
            // `playbackTime` has no change notification (ARCHITECTURE §3).
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(250))
                await self?.tick(0.25)
            }
        }
    }

    private func tick(_ delta: TimeInterval) {
        guard isPlaying, let track = queue.currentTrack else { return }
        elapsed += delta
        if elapsed >= track.duration {
            queue = QueueReducer.reduce(queue, .next)
            elapsed = 0
            if queue.currentTrack == nil {
                isPlaying = false
                ticker?.cancel()
                ticker = nil
            }
        }
        publish()
    }

    private func publish() {
        let track = queue.currentTrack
        let state: PlaybackState = switch (track, isPlaying) {
        case (nil, _): .idle
        case (let t?, true): .playing(t)
        case (let t?, false): .paused(t)
        }
        continuation.yield(
            PlaybackSnapshot(
                state: state,
                elapsed: elapsed,
                duration: track?.duration ?? 0,
                queue: queue
            )
        )
    }
}
