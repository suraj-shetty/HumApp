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

    /// Both Home shelves are *personalized catalog* endpoints, so both need an
    /// active subscription. Without one they cannot answer — and reporting
    /// that as "couldn't load" twice blames the network for a subscription
    /// gap, which is what this screen did on a real non-subscriber account.
    private(set) var needsSubscription = false

    private let catalog: MusicCatalogService
    private let subscription: SubscriptionService

    init(environment: AppEnvironment) {
        self.catalog = environment.catalog
        self.subscription = environment.subscription
    }

    /// Loads both shelves concurrently — they are independent requests, and
    /// running them in series would double the time to first paint.
    func load() async {
        guard case .idle = recentlyPlayed else { return }
        recentlyPlayed = .loading
        recommendations = .loading

        // Asked before the requests, not after they fail: a confirmed gap is
        // an answer, so there is no reason to make two doomed round trips and
        // then guess at why they came back empty.
        guard case .active = await subscription.current else {
            needsSubscription = true
            recentlyPlayed = .loaded([])
            recommendations = .loaded([])
            return
        }
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
    }

    func reload() async {
        recentlyPlayed = .idle
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
