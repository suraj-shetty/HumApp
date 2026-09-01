/// Apple Music catalog reads: search, and the Home screen's shelves.
protocol MusicCatalogService: Sendable {
    func search(_ term: String) async throws -> [HumTrack]
    /// `MusicRecentlyPlayedContainerRequest` — empty for a new account, which
    /// is why Home needs a designed empty state (DECISIONS M-12).
    func recentlyPlayed() async throws -> [HumCollection]
    /// `MusicPersonalRecommendationsRequest`.
    func recommendations() async throws -> [HumTrack]
    func tracks(in collection: HumCollection) async throws -> [HumTrack]
}
