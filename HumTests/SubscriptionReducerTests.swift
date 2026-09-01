import Testing
@testable import Hum

/// Acceptance criterion: "Subscription-gap state (no active Apple Music
/// subscription) shows the trial-membership prompt, not a broken player."
@Suite("Subscription")
struct SubscriptionReducerTests {

    // MARK: - Flags → state

    @Test("An entitled account is active regardless of offer eligibility",
          arguments: [true, false])
    func canPlayMeansActive(canBecomeSubscriber: Bool) {
        let snapshot = SubscriptionSnapshot(
            canPlayCatalogContent: true,
            canBecomeSubscriber: canBecomeSubscriber
        )
        #expect(SubscriptionReducer.reduce(snapshot) == .active)
    }

    @Test("No entitlement is a gap, carrying whether Apple can offer a trial",
          arguments: [true, false])
    func noEntitlementIsGap(canBecomeSubscriber: Bool) {
        let snapshot = SubscriptionSnapshot(
            canPlayCatalogContent: false,
            canBecomeSubscriber: canBecomeSubscriber
        )
        #expect(
            SubscriptionReducer.reduce(snapshot)
            == .gap(canBecomeSubscriber: canBecomeSubscriber)
        )
    }

    @Test("A failed check is unavailable, never a gap")
    func failureIsNotAGap() {
        // A failed check is not evidence of absence. Rendering it as `.gap`
        // would push a paying subscriber at an offer sheet because their
        // network blipped.
        let state = SubscriptionReducer.reduce(failure: "offline")
        #expect(state == .unavailable(reason: "offline"))
        if case .gap = state { Issue.record("a failed check must not read as a gap") }
    }

    // MARK: - The gate

    @Test("An active subscriber plays catalog content")
    func activePlaysCatalog() {
        #expect(SubscriptionReducer.resolve(.catalog, in: .active) == .play)
    }

    @Test("A gap with a trial available presents Apple's offer")
    func gapPresentsOffer() {
        // The acceptance criterion, precisely: the trial-membership prompt.
        #expect(
            SubscriptionReducer.resolve(.catalog, in: .gap(canBecomeSubscriber: true))
            == .presentSubscriptionOffer
        )
    }

    @Test("A gap with no trial available explains instead of dangling an offer")
    func gapWithoutOfferExplains() {
        #expect(
            SubscriptionReducer.resolve(.catalog, in: .gap(canBecomeSubscriber: false))
            == .explainNoSubscription
        )
    }

    @Test("An unknown status waits for the check rather than guessing")
    func unknownAwaitsCheck() {
        // "We don't know yet" must not render as "you have no subscription".
        #expect(SubscriptionReducer.resolve(.catalog, in: .unknown) == .awaitSubscriptionCheck)
    }

    @Test("A failed check degrades to an explanation, and never blocks the app")
    func unavailableDegrades() {
        #expect(
            SubscriptionReducer.resolve(.catalog, in: .unavailable(reason: "offline"))
            == .explainNoSubscription
        )
    }

    // MARK: - Library content is never gated

    @Test("Library content plays in every subscription state", arguments: [
        SubscriptionState.active,
        .gap(canBecomeSubscriber: true),
        .gap(canBecomeSubscriber: false),
        .unknown,
        .unavailable(reason: "offline"),
    ])
    func libraryAlwaysPlays(state: SubscriptionState) {
        // Purchased, matched, and uploaded music needs no subscription.
        // Gating it would block someone from music they already own.
        #expect(SubscriptionReducer.resolve(.library, in: state) == .play)
    }

    // MARK: - The load-bearing invariant

    @Test("Catalog playback is reachable ONLY from an active subscription",
          arguments: [
            SubscriptionState.gap(canBecomeSubscriber: true),
            .gap(canBecomeSubscriber: false),
            .unknown,
            .unavailable(reason: "offline"),
          ])
    func catalogNeverPlaysWithoutSubscription(state: SubscriptionState) {
        // This is what "not a broken player" means mechanically.
        // `ApplicationMusicPlayer.play()` throws for a non-subscriber rather
        // than falling back to a 30-second preview (DECISIONS M-02), so any
        // non-active state reaching `.play` is a broken player by definition.
        #expect(SubscriptionReducer.resolve(.catalog, in: state) != .play)
    }

    @Test("Exhaustive sweep: no state/source pair is unhandled")
    func exhaustiveSweep() {
        let states: [SubscriptionState] = [
            .active, .unknown,
            .gap(canBecomeSubscriber: true), .gap(canBecomeSubscriber: false),
            .unavailable(reason: "x"),
        ]
        for state in states {
            for source in ContentSource.allCases {
                let outcome = SubscriptionReducer.resolve(source, in: state)
                if source == .catalog && state != .active {
                    #expect(outcome != .play, "\(state) leaked catalog playback")
                }
                if source == .library {
                    #expect(outcome == .play, "\(state) wrongly gated library content")
                }
            }
        }
    }
}
