import Foundation
@testable import Hum

// Test doubles for every service protocol.
//
// They exist for Phase 3 onward, where ViewModels need something to talk to.
// The reducer suites do not use them and do not need to — the reducers are
// pure, which is the point of putting the hard logic there.
//
// All are actors: the protocols are `Sendable`, and an actor gives that for
// free without `@unchecked`.

actor FakeAuthorizationService: MusicAuthorizationService {
    private var status: AuthState
    /// What `request()` resolves to. Defaults to granting.
    private var requestResult: AuthState
    private(set) var requestCount = 0

    init(status: AuthState = .notDetermined, requestResult: AuthState = .authorized) {
        self.status = status
        self.requestResult = requestResult
    }

    var current: AuthState { status }

    /// Stands in for the listener changing the switch in Settings while Hum is
    /// backgrounded.
    func override(_ next: AuthState) { status = next }

    func request() async -> AuthState {
        requestCount += 1
        // Mirrors the real framework: iOS prompts once per install, and asking
        // again just returns the settled status.
        guard status == .notDetermined else { return status }
        status = requestResult
        return status
    }
}

actor FakeSubscriptionService: SubscriptionService {
    private var state: SubscriptionState
    nonisolated let updates: AsyncStream<SubscriptionState>
    private let continuation: AsyncStream<SubscriptionState>.Continuation

    init(state: SubscriptionState = .active) {
        self.state = state
        (updates, continuation) = AsyncStream.makeStream()
    }

    var current: SubscriptionState { state }

    /// Simulates `MusicSubscription.subscriptionUpdates` firing — e.g. the
    /// listener subscribing in the Music app while Hum is open.
    func emit(_ next: SubscriptionState) {
        state = next
        continuation.yield(next)
    }

    func finish() { continuation.finish() }
}

actor FakePlaybackService: PlaybackService {
    enum Call: Sendable, Equatable {
        case play(trackIDs: [String], startingAt: Int)
        case resume, pause, skipToNext, skipToPrevious
        case seek(TimeInterval)
        case applyQueue(trackIDs: [String])
    }

    nonisolated let snapshots: AsyncStream<PlaybackSnapshot>
    private let continuation: AsyncStream<PlaybackSnapshot>.Continuation
    private(set) var calls: [Call] = []
    /// Set to make the next mutating call throw, for failure-path tests.
    var nextError: HumError?

    init() {
        (snapshots, continuation) = AsyncStream.makeStream()
    }

    func setNextError(_ error: HumError?) { nextError = error }

    private func throwIfNeeded() throws {
        if let nextError { self.nextError = nil; throw nextError }
    }

    func play(_ tracks: [HumTrack], startingAt index: Int) async throws {
        calls.append(.play(trackIDs: tracks.map(\.id), startingAt: index))
        try throwIfNeeded()
    }

    func resume() async throws {
        calls.append(.resume)
        try throwIfNeeded()
    }

    func pause() async { calls.append(.pause) }

    func skipToNext() async throws {
        calls.append(.skipToNext)
        try throwIfNeeded()
    }

    func skipToPrevious() async throws {
        calls.append(.skipToPrevious)
        try throwIfNeeded()
    }

    func seek(to time: TimeInterval) async { calls.append(.seek(time)) }

    func applyQueue(_ queue: QueueState) async throws {
        calls.append(.applyQueue(trackIDs: queue.entries.map(\.id)))
        try throwIfNeeded()
    }

    /// Pushes a snapshot to observers, standing in for the real player.
    func emit(_ snapshot: PlaybackSnapshot) { continuation.yield(snapshot) }

    func finish() { continuation.finish() }
}

actor FakeCatalogService: MusicCatalogService {
    var searchResults: [HumTrack] = []
    var searchAlbumResults: [HumCollection] = []
    var recent: [HumCollection] = []
    var recommended: [HumTrack] = []
    var collectionTracks: [HumTrack] = []
    var error: HumError?

    private func throwIfNeeded() throws {
        if let error { throw error }
    }

    func search(_ term: String) async throws -> HumSearchResults {
        try throwIfNeeded()
        guard !term.isEmpty else { return .empty }
        return HumSearchResults(tracks: searchResults, albums: searchAlbumResults)
    }

    func recentlyPlayed() async throws -> [HumCollection] {
        try throwIfNeeded()
        return recent
    }

    func recommendations() async throws -> [HumTrack] {
        try throwIfNeeded()
        return recommended
    }

    func tracks(in collection: HumCollection) async throws -> [HumTrack] {
        try throwIfNeeded()
        return collectionTracks
    }

    var resolvedArtist: HumCollection?
    var resolvedAlbum: HumCollection?

    func artist(for track: HumTrack) async throws -> HumCollection? {
        try throwIfNeeded()
        return resolvedArtist
    }

    func album(for track: HumTrack) async throws -> HumCollection? {
        try throwIfNeeded()
        return resolvedAlbum
    }

    func setError(_ error: HumError?) { self.error = error }
    func setSearchResults(_ tracks: [HumTrack]) { searchResults = tracks }
    func setSearchAlbumResults(_ collections: [HumCollection]) { searchAlbumResults = collections }
    func setRecent(_ collections: [HumCollection]) { recent = collections }
    func setRecommended(_ tracks: [HumTrack]) { recommended = tracks }
    func setCollectionTracks(_ tracks: [HumTrack]) { collectionTracks = tracks }
}

actor FakeLibraryService: MusicLibraryService {
    var storedAlbums: [HumCollection] = []
    var storedPlaylists: [HumCollection] = []
    var storedArtists: [HumCollection] = []
    private(set) var added: Set<String> = []
    var error: HumError?

    private func throwIfNeeded() throws {
        if let error { throw error }
    }

    func albums() async throws -> [HumCollection] {
        try throwIfNeeded()
        return storedAlbums
    }

    func playlists() async throws -> [HumCollection] {
        try throwIfNeeded()
        return storedPlaylists
    }

    func artists() async throws -> [HumCollection] {
        try throwIfNeeded()
        return storedArtists
    }

    func add(_ track: HumTrack) async throws {
        try throwIfNeeded()
        added.insert(track.id)
    }

    func contains(_ track: HumTrack) async throws -> Bool {
        try throwIfNeeded()
        return added.contains(track.id)
    }

    private(set) var createdPlaylistNames: [String] = []
    private(set) var addedToPlaylist: [(track: String, playlist: String)] = []

    func createPlaylist(name: String, description: String) async throws -> HumCollection {
        try throwIfNeeded()
        createdPlaylistNames.append(name)
        return HumCollection(
            id: "fake-playlist-\(createdPlaylistNames.count)", kind: .playlist, title: name,
            subtitle: "", metaLine: "Playlist", artworkURL: nil, source: .library
        )
    }

    func add(_ track: HumTrack, to playlist: HumCollection) async throws {
        try throwIfNeeded()
        addedToPlaylist.append((track.id, playlist.id))
    }

    var storedDownloads: [HumCollection] = []
    func downloads() async throws -> [HumCollection] {
        try throwIfNeeded()
        return storedDownloads
    }

    func setError(_ error: HumError?) { self.error = error }
    func setAlbums(_ collections: [HumCollection]) { storedAlbums = collections }
    func setPlaylists(_ collections: [HumCollection]) { storedPlaylists = collections }
    func setArtists(_ collections: [HumCollection]) { storedArtists = collections }
}
