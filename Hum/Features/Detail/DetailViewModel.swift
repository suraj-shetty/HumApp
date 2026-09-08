import Observation

@MainActor
@Observable
final class DetailViewModel {
    let collection: HumCollection
    private(set) var tracks: LoadState<[HumTrack]> = .idle
    /// Detail is reached from catalog content too (a Home recommendation, a
    /// Search album result), not just the listener's own library — without
    /// this, a subscription gap on one of those surfaced as the generic
    /// "Couldn't load these tracks.", blaming the network the same way
    /// Home's shelves and Search once did before they were gated.
    private(set) var needsSubscription = false

    private let catalog: MusicCatalogService
    private let subscriptionStore: SubscriptionStateStore

    init(collection: HumCollection, environment: AppEnvironment) {
        self.collection = collection
        self.catalog = environment.catalog
        self.subscriptionStore = environment.subscriptionStore
    }

    func load() async {
        guard case .idle = tracks else { return }
        tracks = .loading

        // A library collection needs no subscription at all — only a catalog
        // one is gated, the same distinction `HumTrack.source` draws
        // elsewhere for the identical reason.
        if collection.source == .catalog {
            await subscriptionStore.refresh()
            switch SubscriptionReducer.resolveBrowse(in: subscriptionStore.current) {
            case .browse:
                needsSubscription = false
            case .needsSubscription:
                needsSubscription = true
                tracks = .loaded([])
                return
            case .checkFailed:
                needsSubscription = false
                tracks = .failed("Couldn't check your Apple Music subscription.")
                return
            }
        }

        do {
            tracks = .loaded(try await catalog.tracks(in: collection))
        } catch {
            tracks = .failed("Couldn't load these tracks.")
        }
    }

    /// Design screen 37's "Reload" — `load()` only ever runs once from
    /// `.idle`, so a retry has to reopen that door itself.
    func retry() async {
        tracks = .idle
        await load()
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
