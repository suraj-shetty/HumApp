/// Wraps `MusicSubscription`. The live adapter is an `actor` — the underlying
/// calls are `async throws` and belong off the UI.
protocol SubscriptionService: Sendable {
    var current: SubscriptionState { get async }
    /// Backed by `MusicSubscription.subscriptionUpdates`, so a subscription
    /// started in the Music app (or through our offer sheet) lands without a
    /// relaunch.
    var updates: AsyncStream<SubscriptionState> { get }
}
