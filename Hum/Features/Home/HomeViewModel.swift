import Foundation
import Observation

/// Loading state shared by every content screen.
///
/// A single generic enum rather than the usual `isLoading` + `items` + `error`
/// triple: those three booleans permit states that cannot exist (loading *and*
/// failed), and every screen then re-invents the same precedence rules.
enum LoadState<Value: Sendable>: Sendable {
    case idle
    case loading
    case loaded(Value)
    case failed(String)

    var value: Value? {
        if case .loaded(let value) = self { return value }
        return nil
    }

    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }
}

@MainActor
@Observable
final class HomeViewModel {
    private(set) var recentlyPlayed: LoadState<[HumCollection]> = .idle
    private(set) var recommendations: LoadState<[HumTrack]> = .idle
    /// Design screen 11's "Downloaded" shelf — only ever populated when
    /// `isOffline` is set before `load()` runs.
    private(set) var downloads: LoadState<[HumCollection]> = .idle

    /// Both Home shelves are *personalized catalog* endpoints, so both need an
    /// active subscription. Without one they cannot answer — and reporting
    /// that as "couldn't load" twice blames the network for a subscription
    /// gap, which is what this screen did on a real non-subscriber account.
    private(set) var needsSubscription = false

    /// Set by `HomeView` from `NetworkMonitor` before `load()`/`reload()`
    /// runs — this view model has no reachability opinion of its own, only
    /// what it's told.
    var isOffline = false

    private let catalog: MusicCatalogService
    private let library: MusicLibraryService
    private let subscription: SubscriptionService

    init(environment: AppEnvironment) {
        self.catalog = environment.catalog
        self.library = environment.library
        self.subscription = environment.subscription
    }

    /// Loads both shelves concurrently — they are independent requests, and
    /// running them in series would double the time to first paint.
    func load() async {
        guard case .idle = recentlyPlayed else { return }
        recentlyPlayed = .loading
        recommendations = .loading

        // Offline is asked first and answered without ever touching the
        // catalog: those two requests would just fail, and reporting a
        // confirmed-offline state as two generic "couldn't load" rows blames
        // the network for something this app already knows for certain
        // (design screen 11) — the same reasoning `needsSubscription`
        // already applies to a missing subscription below.
        guard !isOffline else {
            needsSubscription = false
            recentlyPlayed = .loaded([])
            recommendations = .failed("Recommendations need a connection.")
            downloads = .loading
            do {
                downloads = .loaded(try await library.downloads())
            } catch {
                downloads = .failed("Couldn't load your downloads.")
            }
            return
        }

        // Asked before the requests, not after they fail: a confirmed gap is
        // an answer, so there is no reason to make two doomed round trips and
        // then guess at why they came back empty. Routed through the same
        // reducer `PlayerViewModel` uses for play intents rather than a raw
        // `case .active` check, so a failed subscription check can't collapse
        // into "needs subscription" here the way it can't on the play path.
        switch SubscriptionReducer.resolveBrowse(in: await subscription.current) {
        case .browse:
            needsSubscription = false

            async let recent = catalog.recentlyPlayed()
            async let recommended = catalog.recommendations()

            do {
                recentlyPlayed = .loaded(try await recent)
            } catch {
                recentlyPlayed = .failed("Couldn't load recently played.")
            }
            do {
                recommendations = .loaded(try await recommended)
            } catch {
                recommendations = .failed("Couldn't load recommendations.")
            }

        case .needsSubscription:
            needsSubscription = true
            recentlyPlayed = .loaded([])
            recommendations = .loaded([])

        case .checkFailed:
            needsSubscription = false
            recentlyPlayed = .failed("Couldn't check your Apple Music subscription.")
            recommendations = .failed("Couldn't check your Apple Music subscription.")
        }
    }

    func reload() async {
        recentlyPlayed = .idle
        downloads = .idle
        await load()
    }

    /// "Evening" — the Home title.
    ///
    /// The design's Home header is this one word at 32/200, and nothing else
    /// besides the profile control. It carried a weekday and rendered as a
    /// tracked uppercase overline under the wordmark, which was three
    /// divergences in one header.
    var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        return switch hour {
        case 5..<12: "Morning"
        case 12..<17: "Afternoon"
        case 17..<22: "Evening"
        default: "Night"
        }
    }
}
