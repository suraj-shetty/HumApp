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
    private let subscriptionStore: SubscriptionStateStore
    private var subscriptionChangeToken: UUID?
    /// Set whenever `load()` resolves a browse outcome, so the observer
    /// below can tell a genuine change from the shared store's `onChange`
    /// replaying the current value to a new registrant.
    private var lastKnownSubscriptionOutcome: SubscriptionReducer.BrowseOutcome?

    init(environment: AppEnvironment) {
        self.catalog = environment.catalog
        self.library = environment.library
        self.subscriptionStore = environment.subscriptionStore
    }

    /// Keeps `needsSubscription` in sync with subscription changes that
    /// happen while Home is visible (e.g. subscribing through Now Playing's
    /// offer sheet). Without this, `needsSubscription` is a one-time snapshot
    /// taken in `load()` — `PlayerViewModel.subscription` updates immediately
    /// from the same shared store, so the two could disagree until the
    /// listener manually pulled to refresh. Routed through the shared
    /// `SubscriptionStateStore` rather than this view model's own live
    /// MusicKit subscription — see the store's own doc comment.
    func startObservingSubscriptionChanges() {
        guard subscriptionChangeToken == nil else { return }
        subscriptionStore.start()
        subscriptionChangeToken = subscriptionStore.onChange { [weak self] state in
            guard let self else { return }
            let outcome = SubscriptionReducer.resolveBrowse(in: state)
            // The store replays its current value to a new registrant
            // immediately, so the very first call here is routinely just
            // confirming what `load()` already fetched — reloading for it
            // would double every Home appearance's network calls for no
            // actual change.
            guard outcome != self.lastKnownSubscriptionOutcome else { return }
            self.lastKnownSubscriptionOutcome = outcome
            Task { await self.reload() }
        }
    }

    func stopObservingSubscriptionChanges() {
        if let subscriptionChangeToken {
            subscriptionStore.removeOnChange(subscriptionChangeToken)
            self.subscriptionChangeToken = nil
        }
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
        // Refreshed rather than just reading `subscriptionStore.current`:
        // that cache is only as fresh as the store's own background fetch,
        // which may not have resolved yet on a fast cold launch — this keeps
        // `load()`'s own subscription check as live as it always was, while
        // still funneling through the shared store so every other reader
        // sees the same result.
        await subscriptionStore.refresh()
        let outcome = SubscriptionReducer.resolveBrowse(in: subscriptionStore.current)
        lastKnownSubscriptionOutcome = outcome
        switch outcome {
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
        recommendations = .idle
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
