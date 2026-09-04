import MusicKit

/// Real Apple Music catalog reads.
///
/// An `actor`: every call is a network round trip and belongs off the main
/// actor. Nothing MusicKit-shaped leaves a method — results are mapped inside
/// the function that received them (ARCHITECTURE §3).
actor MusicKitCatalogAdapter: MusicCatalogService {

    /// One screenful. Search is debounced upstream, so a larger page would
    /// mostly buy rows nobody scrolls to.
    private static let searchLimit = 25

    func search(_ term: String) async throws -> [HumTrack] {
        let query = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return [] }

        var request = MusicCatalogSearchRequest(term: query, types: [Song.self])
        request.limit = Self.searchLimit
        return try await request.response().songs.map {
            MusicKitMapping.track($0, source: .catalog)
        }
    }

    func recentlyPlayed() async throws -> [HumCollection] {
        var request = MusicRecentlyPlayedContainerRequest()
        request.limit = 12
        return try await request.response().items.compactMap { item in
            switch item {
            case .album(let album): MusicKitMapping.collection(album, source: .catalog)
            case .playlist(let playlist): MusicKitMapping.collection(playlist, source: .catalog)
            // Stations have no fixed track list to browse and Hum has no
            // station screen, so they are dropped rather than shown as a row
            // that cannot open.
            default: nil
            }
        }
    }

    func recommendations() async throws -> [HumTrack] {
        var request = MusicPersonalRecommendationsRequest()
        request.limit = 5
        let recommendations = try await request.response().recommendations

        // MusicKit's personal recommendations are *containers* — playlists,
        // albums, stations — while the Home shelf lists tracks. So take the
        // first recommendation Hum can actually open and show what is inside
        // it, rather than inventing a shelf MusicKit does not offer.
        for recommendation in recommendations {
            if let playlist = recommendation.playlists.first,
               let tracks = try await playlist.with([.tracks]).tracks, !tracks.isEmpty {
                return tracks.map { MusicKitMapping.track($0, source: .catalog) }
            }
            if let album = recommendation.albums.first,
               let tracks = try await album.with([.tracks]).tracks, !tracks.isEmpty {
                return tracks.map { MusicKitMapping.track($0, source: .catalog) }
            }
        }
        // Empty is a real answer for a new account — Home draws an empty state
        // for exactly this (DECISIONS M-12).
        return []
    }

    /// Detail screens read through this service for library collections too,
    /// so the source decides which request runs.
    func tracks(in collection: HumCollection) async throws -> [HumTrack] {
        switch collection.source {
        case .catalog: try await catalogTracks(in: collection)
        case .library: try await libraryTracks(in: collection)
        }
    }

    // MARK: - Catalog

    private func catalogTracks(in collection: HumCollection) async throws -> [HumTrack] {
        let id = MusicItemID(collection.id)

        switch collection.kind {
        case .album:
            var request = MusicCatalogResourceRequest<Album>(matching: \.id, equalTo: id)
            request.properties = [.tracks]
            guard let album = try await request.response().items.first else { return [] }
            return (album.tracks ?? []).map { MusicKitMapping.track($0, source: .catalog) }

        case .playlist:
            var request = MusicCatalogResourceRequest<Playlist>(matching: \.id, equalTo: id)
            request.properties = [.tracks]
            guard let playlist = try await request.response().items.first else { return [] }
            return (playlist.tracks ?? []).map { MusicKitMapping.track($0, source: .catalog) }

        case .artist:
            // An artist has no track list of its own; the prototype's artist
            // screen lists top songs, which is what MusicKit calls them too.
            var request = MusicCatalogResourceRequest<Artist>(matching: \.id, equalTo: id)
            request.properties = [.topSongs]
            guard let artist = try await request.response().items.first else { return [] }
            return (artist.topSongs ?? []).map { MusicKitMapping.track($0, source: .catalog) }
        }
    }

    // MARK: - Artist / album lookup

    func artist(for track: HumTrack) async throws -> HumCollection? {
        guard track.source == .catalog else { return nil }
        var request = MusicCatalogResourceRequest<Song>(matching: \.id, equalTo: MusicItemID(track.id))
        request.properties = [.artists]
        guard let song = try await request.response().items.first,
              let artist = song.artists?.first
        else { return nil }
        return MusicKitMapping.collection(artist, source: .catalog)
    }

    func album(for track: HumTrack) async throws -> HumCollection? {
        guard track.source == .catalog else { return nil }
        var request = MusicCatalogResourceRequest<Song>(matching: \.id, equalTo: MusicItemID(track.id))
        request.properties = [.albums]
        guard let song = try await request.response().items.first,
              let album = song.albums?.first
        else { return nil }
        return MusicKitMapping.collection(album, source: .catalog)
    }

    // MARK: - Library

    private func libraryTracks(in collection: HumCollection) async throws -> [HumTrack] {
        let id = MusicItemID(collection.id)

        switch collection.kind {
        case .album:
            var request = MusicLibraryRequest<Album>()
            request.filter(matching: \.id, equalTo: id)
            guard let album = try await request.response().items.first else { return [] }
            let tracks = try await album.with([.tracks]).tracks ?? []
            return tracks.map { MusicKitMapping.track($0, source: .library) }

        case .playlist:
            var request = MusicLibraryRequest<Playlist>()
            request.filter(matching: \.id, equalTo: id)
            guard let playlist = try await request.response().items.first else { return [] }
            let tracks = try await playlist.with([.tracks]).tracks ?? []
            return tracks.map { MusicKitMapping.track($0, source: .library) }

        case .artist:
            // Unreachable: Library lists albums and playlists only, so no
            // library artist collection is ever constructed to navigate to.
            return []
        }
    }
}
