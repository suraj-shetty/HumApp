import SwiftUI

/// The composition root. The one place concrete services are chosen.
///
/// Nothing above this line knows whether it is talking to MusicKit or to the
/// in-memory preview services — which is what lets every screen build and run
/// in the Simulator (DECISIONS M-09) and what will let the MusicKit adapters
/// drop in during Phase 1 without touching a single ViewModel.
struct AppEnvironment: Sendable {
    let authorization: MusicAuthorizationService
    let subscription: SubscriptionService
    let catalog: MusicCatalogService
    let library: MusicLibraryService
    let playback: PlaybackService
    /// The single shared, live-updating read of `subscription` — see its own
    /// doc comment for why this exists instead of each screen independently
    /// observing `subscription.updates`.
    let subscriptionStore: SubscriptionStateStore

    /// The shipping wiring: MusicKit end to end.
    ///
    /// `@MainActor` because two of the adapters are — `MusicAuthorization`
    /// presents system UI and `ApplicationMusicPlayer.shared` is main-actor
    /// bound. The app's composition root already runs there.
    @MainActor
    static func live() -> AppEnvironment {
        let subscription = MusicKitSubscriptionAdapter()
        return AppEnvironment(
            authorization: MusicKitAuthorizationAdapter(),
            subscription: subscription,
            catalog: MusicKitCatalogAdapter(),
            library: MusicKitLibraryAdapter(),
            playback: ApplicationMusicPlayerAdapter(),
            subscriptionStore: SubscriptionStateStore(service: subscription)
        )
    }

    /// In-memory services. Backs SwiftUI previews and the Simulator, where
    /// MusicKit does not function (DECISIONS M-09).
    static func preview(
        auth: AuthState = .authorized,
        subscription: SubscriptionState = .active
    ) -> AppEnvironment {
        let subscriptionService = PreviewSubscriptionService(state: subscription)
        return AppEnvironment(
            authorization: PreviewAuthorizationService(status: auth),
            subscription: subscriptionService,
            catalog: PreviewCatalogService(),
            library: PreviewLibraryService(),
            playback: PreviewPlaybackService(),
            subscriptionStore: SubscriptionStateStore(service: subscriptionService)
        )
    }
}

/// Single, shared source of truth for the listener's Apple Music subscription
/// state.
///
/// Before this, `PlayerViewModel`, `HomeViewModel`, and `SettingsViewModel`
/// each independently called `SubscriptionService.current`/`.updates` — three
/// live MusicKit subscriptions to the same underlying state, each reacting on
/// its own schedule, able to disagree with each other for the span of a
/// network call, and a fourth screen (iPad's "Made for you" destination)
/// simply never observed changes at all. This owns the one live observation;
/// everyone else reads `current` or registers `onChange`.
@MainActor
@Observable
final class SubscriptionStateStore {
    private(set) var current: SubscriptionState = .unknown

    private let service: SubscriptionService
    private var observation: Task<Void, Never>?
    private var onChangeHandlers: [UUID: (SubscriptionState) -> Void] = [:]

    // `nonisolated` so `AppEnvironmentKey.defaultValue` (an `EnvironmentKey`
    // requirement, which cannot itself be actor-isolated) can construct one
    // without crossing into main-actor code at that point — everything this
    // initializer touches is either a `Sendable` parameter or a stored
    // property with its own inline default.
    nonisolated init(service: SubscriptionService) {
        self.service = service
    }

    /// Idempotent — every consumer that needs live subscription state calls
    /// this from its own `init`/`.task`; only the first call actually starts
    /// the underlying observation.
    func start() {
        guard observation == nil else { return }
        observation = Task { [weak self, service] in
            guard let self else { return }
            self.update(await service.current)
            for await state in service.updates {
                guard !Task.isCancelled else { return }
                self.update(state)
            }
        }
    }

    /// Backs `PlayerViewModel.retrySubscriptionCheck()` — re-runs the check
    /// after a failure rather than waiting for MusicKit to emit on its own.
    func refresh() async {
        update(await service.current)
    }

    private func update(_ state: SubscriptionState) {
        guard state != current else { return }
        current = state
        for handler in onChangeHandlers.values { handler(state) }
    }

    /// Registers `handler` for every subsequent change, and — matching
    /// `SubscriptionService.updates`' own behavior of replaying the current
    /// value to a new subscriber — calls it once immediately with whatever
    /// `current` already is. Returns a token to pass to `removeOnChange(_:)`.
    @discardableResult
    func onChange(_ handler: @escaping (SubscriptionState) -> Void) -> UUID {
        let token = UUID()
        onChangeHandlers[token] = handler
        handler(current)
        return token
    }

    func removeOnChange(_ token: UUID) {
        onChangeHandlers[token] = nil
    }
}

private struct AppEnvironmentKey: EnvironmentKey {
    static let defaultValue: AppEnvironment = .preview()
}

extension EnvironmentValues {
    var appEnvironment: AppEnvironment {
        get { self[AppEnvironmentKey.self] }
        set { self[AppEnvironmentKey.self] = newValue }
    }
}
