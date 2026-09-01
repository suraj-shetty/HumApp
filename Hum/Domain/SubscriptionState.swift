/// The raw flags `MusicSubscription` reports, captured at the adapter boundary.
struct SubscriptionSnapshot: Sendable, Equatable {
    /// `MusicSubscription.canPlayCatalogContent`
    let canPlayCatalogContent: Bool
    /// `MusicSubscription.canBecomeSubscriber` — true when Apple can offer this
    /// account a trial or a subscription right now.
    let canBecomeSubscriber: Bool
}

/// What the subscription situation means for Hum.
enum SubscriptionState: Sendable, Equatable {
    /// Not checked yet. Distinct from `.gap` on purpose — "we don't know" must
    /// not render as "you have no subscription".
    case unknown
    case active
    /// No active subscription. `canBecomeSubscriber` decides whether we can
    /// offer Apple's trial, or can only explain the situation.
    case gap(canBecomeSubscriber: Bool)
    /// The check itself failed. Degrade to library-only; never block the app.
    case unavailable(reason: String)
}
