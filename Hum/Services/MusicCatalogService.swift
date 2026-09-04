/// Apple Music catalog reads: search, and the Home screen's shelves.
protocol MusicCatalogService: Sendable {
    func search(_ term: String) async throws -> [HumTrack]
    /// `MusicRecentlyPlayedContainerRequest` — empty for a new account, which
    /// is why Home needs a designed empty state (DECISIONS M-12).
    func recentlyPlayed() async throws -> [HumCollection]
    /// `MusicPersonalRecommendationsRequest`.
    func recommendations() async throws -> [HumTrack]
    func tracks(in collection: HumCollection) async throws -> [HumTrack]

    /// Resolves a track's artist into a navigable collection — the track
    /// context menu's "Go to Artist" and Detail's own artist-name tap
    /// (design screens 22 and 31). `HumTrack` carries only an artist
    /// *name*, not an id; this looks the real relationship up rather than
    /// guessing from that string.
    ///
    /// `nil` for a library-sourced track: catalog and library items live in
    /// different MusicKit id namespaces, and a catalog lookup against a
    /// library id would either fail or resolve the wrong item.
    func artist(for track: HumTrack) async throws -> HumCollection?

    /// The same resolution for "Go to Album" — `nil` for a library track,
    /// for the same reason.
    func album(for track: HumTrack) async throws -> HumCollection?
}
