import MusicKit

/// The listener's own library. Requires no Apple Music subscription — which is
/// the whole reason `ContentSource` exists.
actor MusicKitLibraryAdapter: MusicLibraryService {

    private static let pageLimit = 100

    /// `contains(_:)` for a catalog track has no cheap lookup — every call
    /// issues a library query — so a screen that asks per row (e.g. search
    /// results) re-issued an identical request for the same track on every
    /// check. Cached by track id, and updated (not just invalidated) on
    /// `add(_:)` so a fresh add is reflected immediately rather than
    /// re-querying.
    private var containmentCache: [String: Bool] = [:]

    func albums() async throws -> [HumCollection] {
        var request = MusicLibraryRequest<Album>()
        request.limit = Self.pageLimit
        return try await request.response().items.map {
            MusicKitMapping.collection($0, source: .library)
        }
    }

    func playlists() async throws -> [HumCollection] {
        var request = MusicLibraryRequest<Playlist>()
        request.limit = Self.pageLimit
        return try await request.response().items.map {
            MusicKitMapping.collection($0, source: .library)
        }
    }

    func artists() async throws -> [HumCollection] {
        var request = MusicLibraryRequest<Artist>()
        request.limit = Self.pageLimit
        return try await request.response().items.map {
            MusicKitMapping.collection($0, source: .library)
        }
    }

    /// Backs the action the prototype draws as a heart. MusicKit has no
    /// love/favorite API, so this adds to the library — a real capability
    /// (DECISIONS M-04).
    func add(_ track: HumTrack) async throws {
        guard let song = try await song(for: track) else {
            throw HumError.requestFailed("That track is no longer available.")
        }
        try await MusicLibrary.shared.add(song)
        containmentCache[track.id] = true
    }

    func contains(_ track: HumTrack) async throws -> Bool {
        // A library track is in the library by definition.
        guard track.source == .catalog else { return true }

        if let cached = containmentCache[track.id] { return cached }

        // For a catalog track there is no direct query: the library copy is a
        // different item with a different identifier, and MusicKit exposes no
        // catalog-to-library lookup. Matching on title and artist is what the
        // listener can see for themselves, so a wrong answer here is at least
        // a legible one.
        var request = MusicLibraryRequest<Song>()
        request.filter(matching: \.title, equalTo: track.title)
        // Every sibling query in this file sets this; this one didn't, so it
        // fell back to MusicKit's much smaller default page size — a
        // listener with many library songs sharing this title (a common
        // cover/remix/live-version title) could have the actual
        // artist-matching copy fall outside that first page.
        request.limit = Self.pageLimit
        let result = try await request.response().items.contains { $0.artistName == track.artist }
        containmentCache[track.id] = result
        return result
    }

    func createPlaylist(name: String, description: String) async throws -> HumCollection {
        let playlist = try await MusicLibrary.shared.createPlaylist(name: name, description: description)
        return MusicKitMapping.collection(playlist, source: .library)
    }

    func add(_ track: HumTrack, to playlist: HumCollection) async throws {
        guard let song = try await song(for: track) else {
            throw HumError.requestFailed("That track is no longer available.")
        }
        var request = MusicLibraryRequest<Playlist>()
        request.filter(matching: \.id, equalTo: MusicItemID(playlist.id))
        guard let target = try await request.response().items.first else {
            throw HumError.requestFailed("That playlist is no longer available.")
        }
        try await MusicLibrary.shared.add(song, to: target)
    }

    /// Design screen 11's "Downloaded" shelf. Albums and playlists queried
    /// separately, same as `albums()`/`playlists()` above, then combined —
    /// the design's shelf doesn't distinguish the two kinds, just shows
    /// whatever's actually on the device.
    func downloads() async throws -> [HumCollection] {
        async let downloadedAlbums = downloadedAlbumsResult()
        async let downloadedPlaylists = downloadedPlaylistsResult()
        return try await downloadedAlbums + downloadedPlaylists
    }

    private func downloadedAlbumsResult() async throws -> [HumCollection] {
        var request = MusicLibraryRequest<Album>()
        request.includeOnlyDownloadedContent = true
        request.limit = Self.pageLimit
        return try await request.response().items.map {
            MusicKitMapping.collection($0, source: .library)
        }
    }

    private func downloadedPlaylistsResult() async throws -> [HumCollection] {
        var request = MusicLibraryRequest<Playlist>()
        request.includeOnlyDownloadedContent = true
        request.limit = Self.pageLimit
        return try await request.response().items.map {
            MusicKitMapping.collection($0, source: .library)
        }
    }

    // MARK: - Resolution

    private func song(for track: HumTrack) async throws -> Song? {
        switch track.source {
        case .catalog:
            let request = MusicCatalogResourceRequest<Song>(
                matching: \.id,
                equalTo: MusicItemID(track.id)
            )
            return try await request.response().items.first

        case .library:
            var request = MusicLibraryRequest<Song>()
            request.filter(matching: \.id, equalTo: MusicItemID(track.id))
            return try await request.response().items.first
        }
    }
}
