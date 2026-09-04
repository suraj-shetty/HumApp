import Foundation

/// A catalog search's results, split the way `MusicCatalogSearchRequest`
/// itself returns them — one `MusicItemCollection` per requested type — so
/// Search can head "Top Results" and "Albums" separately (design screen 13,
/// findings M-3/M-4) instead of flattening everything into one track list.
struct HumSearchResults: Sendable, Equatable {
    let tracks: [HumTrack]
    let albums: [HumCollection]

    static let empty = HumSearchResults(tracks: [], albums: [])

    var isEmpty: Bool { tracks.isEmpty && albums.isEmpty }
}
