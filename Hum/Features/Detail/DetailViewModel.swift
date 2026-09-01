import Observation

@MainActor
@Observable
final class DetailViewModel {
    let collection: HumCollection
    private(set) var tracks: LoadState<[HumTrack]> = .idle

    private let catalog: MusicCatalogService

    init(collection: HumCollection, environment: AppEnvironment) {
        self.collection = collection
        self.catalog = environment.catalog
    }

    func load() async {
        guard case .idle = tracks else { return }
        tracks = .loading
        do {
            tracks = .loaded(try await catalog.tracks(in: collection))
        } catch {
            tracks = .failed("Couldn't load these tracks.")
        }
    }

    /// Album rows show a track number; playlist and artist rows show artwork,
    /// because their tracks come from different albums and a running index
    /// would be meaningless.
    var usesTrackNumbers: Bool {
        collection.kind == .album
    }

    var showsShuffle: Bool {
        collection.kind != .artist
    }
}
