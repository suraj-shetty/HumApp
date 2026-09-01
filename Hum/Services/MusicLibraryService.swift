/// The listener's own library.
protocol MusicLibraryService: Sendable {
    func albums() async throws -> [HumCollection]
    func playlists() async throws -> [HumCollection]
    /// `MusicLibrary.shared.add(_:)`.
    ///
    /// This backs the Now Playing action the prototype draws as a heart.
    /// MusicKit exposes no love/favorite API, so the affordance is "Add to
    /// Library" — a real capability — rather than a heart that means nothing
    /// to the listener's Apple Music account (DECISIONS M-04).
    func add(_ track: HumTrack) async throws
    func contains(_ track: HumTrack) async throws -> Bool
}
