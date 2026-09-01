/// Failures Hum can surface. Deliberately small — most MusicKit errors are not
/// actionable by the listener, and collapsing them into a single
/// `.requestFailed` keeps the UI from inventing distinctions it cannot explain.
enum HumError: Error, Sendable, Equatable {
    case authorizationDenied
    case authorizationRestricted
    /// Catalog playback attempted without an active subscription. Should be
    /// unreachable — `SubscriptionReducer` gates play intents before they get
    /// here — so reaching it indicates a gap in the gate, not a user error.
    case subscriptionRequired
    case playbackFailed(String)
    case requestFailed(String)
}
