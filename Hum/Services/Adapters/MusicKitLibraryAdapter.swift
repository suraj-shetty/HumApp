import MusicKit

/// The listener's own library. Requires no Apple Music subscription — which is
/// the whole reason `ContentSource` exists.
actor MusicKitLibraryAdapter: MusicLibraryService {

    private static let pageLimit = 100

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

    /// Backs the action the prototype draws as a heart. MusicKit has no
    /// love/favorite API, so this adds to the library — a real capability
    /// (DECISIONS M-04).
    func add(_ track: HumTrack) async throws {
        guard let song = try await song(for: track) else {
            throw HumError.requestFailed("That track is no longer available.")
        }
        try await MusicLibrary.shared.add(song)
    }

    func contains(_ track: HumTrack) async throws -> Bool {
        // A library track is in the library by definition.
        guard track.source == .catalog else { return true }

        // For a catalog track there is no direct query: the library copy is a
        // different item with a different identifier, and MusicKit exposes no
        // catalog-to-library lookup. Matching on title and artist is what the
        // listener can see for themselves, so a wrong answer here is at least
        // a legible one.
        var request = MusicLibraryRequest<Song>()
        request.filter(matching: \.title, equalTo: track.title)
        return try await request.response().items.contains { $0.artistName == track.artist }
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
