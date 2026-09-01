import Testing
@testable import Hum

/// Phase 3. `SubscriptionReducerTests` proves the decision table; this suite
/// proves the *app* honours it — that a subscription gap reaches Apple's offer
/// sheet rather than the player, and that a gap closing mid-session resumes
/// what the listener originally asked for.
///
/// This is the brief's "subscription-gap shows a trial prompt, not a broken
/// player" criterion, asserted rather than asserted-about.
@MainActor
@Suite("Subscription gate")
struct SubscriptionGateTests {

    private func model(
        subscription: SubscriptionState
    ) -> (PlayerViewModel, FakeSubscriptionService, FakePlaybackService) {
        let subscriptionService = FakeSubscriptionService(state: subscription)
        let playback = FakePlaybackService()
        let environment = AppEnvironment(
            authorization: FakeAuthorizationService(status: .authorized),
            subscription: subscriptionService,
            catalog: FakeCatalogService(),
            library: FakeLibraryService(),
            playback: playback
        )
        return (PlayerViewModel(environment: environment), subscriptionService, playback)
    }

    private let catalogTrack = HumTrack(
        id: "cat-1",
        title: "Let Down",
        artist: "Radiohead",
        albumTitle: "OK Computer",
        duration: 299,
        artworkURL: nil,
        source: .catalog
    )

    private let libraryTrack = HumTrack(
        id: "lib-1",
        title: "Longer Evenings",
        artist: "Ana Roele",
        albumTitle: "Longer Evenings",
        duration: 214,
        artworkURL: nil,
        source: .library
    )

    @Test("A subscriber plays catalog content")
    func subscriberPlays() async throws {
        let (sut, _, playback) = model(subscription: .active)
        sut.start()
        try await Task.sleep(for: .milliseconds(50))

        sut.play([catalogTrack], source: "Album")
        try await Task.sleep(for: .milliseconds(50))

        #expect(await playback.calls == [.play(trackIDs: ["cat-1"], startingAt: 0)])
        #expect(!sut.isPresentingSubscriptionOffer)
        #expect(!sut.isPresentingSubscriptionGap)
    }

    @Test("A gap Apple can close presents the offer, and never the player")
    func gapPresentsOffer() async throws {
        let (sut, _, playback) = model(subscription: .gap(canBecomeSubscriber: true))
        sut.start()
        try await Task.sleep(for: .milliseconds(50))

        sut.play([catalogTrack], source: "Album")
        try await Task.sleep(for: .milliseconds(50))

        #expect(sut.isPresentingSubscriptionOffer)
        #expect(!sut.isPresentingSubscriptionGap)
        #expect(await playback.calls.isEmpty, "the player must never be handed a gap")
    }

    @Test("A gap Apple cannot close explains instead of dangling an offer")
    func unofferableGapExplains() async throws {
        let (sut, _, playback) = model(subscription: .gap(canBecomeSubscriber: false))
        sut.start()
        try await Task.sleep(for: .milliseconds(50))

        sut.play([catalogTrack], source: "Album")
        try await Task.sleep(for: .milliseconds(50))

        #expect(sut.isPresentingSubscriptionGap)
        #expect(!sut.isPresentingSubscriptionOffer)
        #expect(await playback.calls.isEmpty)
    }

    @Test("A failed check degrades to library-only rather than blocking")
    func failedCheckStillPlaysLibrary() async throws {
        let (sut, _, playback) = model(subscription: .unavailable(reason: "offline"))
        sut.start()
        try await Task.sleep(for: .milliseconds(50))

        sut.play([libraryTrack], source: "Library")
        try await Task.sleep(for: .milliseconds(50))

        #expect(await playback.calls == [.play(trackIDs: ["lib-1"], startingAt: 0)])
        #expect(!sut.isPresentingSubscriptionGap, "the listener's own music needs no explanation")
    }

    @Test("Subscribing mid-session resumes the track that was turned back")
    func subscribingResumesDeferredIntent() async throws {
        let (sut, subscriptionService, playback) = model(
            subscription: .gap(canBecomeSubscriber: true)
        )
        sut.start()
        try await Task.sleep(for: .milliseconds(50))

        sut.play([catalogTrack], source: "Album")
        try await Task.sleep(for: .milliseconds(50))
        #expect(sut.isPresentingSubscriptionOffer)

        // The listener subscribes — through the offer sheet, or in the Music
        // app while Hum is open. `MusicSubscription.subscriptionUpdates` fires.
        await subscriptionService.emit(.active)
        try await Task.sleep(for: .milliseconds(100))

        #expect(sut.subscription == .active)
        #expect(!sut.isPresentingSubscriptionOffer, "the offer must close itself")
        #expect(await playback.calls == [.play(trackIDs: ["cat-1"], startingAt: 0)])

        sut.stop()
    }
}
