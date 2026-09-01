import MusicKit

/// Real `MusicSubscription` wrapper.
///
/// An `actor`: the underlying calls are `async throws` and belong off the UI.
actor MusicKitSubscriptionAdapter: SubscriptionService {

    var current: SubscriptionState {
        get async {
            do {
                return SubscriptionReducer.reduce(Self.snapshot(from: try await MusicSubscription.current))
            } catch {
                // Deliberately `.unavailable`, never `.gap` — a failed check is
                // not evidence of absence, and treating it as one would push a
                // paying subscriber at an offer sheet (SubscriptionReducer).
                return SubscriptionReducer.reduce(failure: error.localizedDescription)
            }
        }
    }

    /// Backed by `MusicSubscription.subscriptionUpdates`, so a subscription
    /// started in the Music app lands without relaunching Hum.
    nonisolated var updates: AsyncStream<SubscriptionState> {
        AsyncStream { continuation in
            // `subscriptionUpdates` is a non-throwing sequence: once the
            // initial read succeeds, later updates cannot fail. Errors are
            // only possible on `current`, above.
            let task = Task {
                for await subscription in MusicSubscription.subscriptionUpdates {
                    continuation.yield(
                        SubscriptionReducer.reduce(Self.snapshot(from: subscription))
                    )
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    static func snapshot(from subscription: MusicSubscription) -> SubscriptionSnapshot {
        SubscriptionSnapshot(
            canPlayCatalogContent: subscription.canPlayCatalogContent,
            canBecomeSubscriber: subscription.canBecomeSubscriber
        )
    }
}
