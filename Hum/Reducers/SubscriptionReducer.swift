/// What Hum does when the listener asks to play something.
enum PlayIntentOutcome: Sendable, Equatable {
    /// Hand it to `ApplicationMusicPlayer`.
    case play
    /// Present Apple's own `MusicSubscriptionOffer` sheet.
    ///
    /// Not a paywall: Hum charges nothing, unlocks nothing, and gates none of
    /// its own features behind it. It is Apple's trial entry point, shown at
    /// the point of need. That distinction is what keeps this inside the DPLA
    /// rule against monetizing access to Apple Music.
    case presentSubscriptionOffer
    /// No subscription and Apple cannot offer one to this account. Explain;
    /// do not dangle an offer that would fail.
    case explainNoSubscription
    /// Status not yet known. Resolve it before deciding — never guess, and
    /// never let a slow check read as "you have no subscription".
    case awaitSubscriptionCheck
}

/// Pure. Covers the brief's second named test criterion — subscription-status
/// detection — and enforces the invariant that a subscription gap can never
/// reach the player.
struct SubscriptionReducer: Sendable {

    /// Maps the raw `MusicSubscription` flags to Hum's state.
    static func reduce(_ snapshot: SubscriptionSnapshot) -> SubscriptionState {
        if snapshot.canPlayCatalogContent {
            return .active
        }
        return .gap(canBecomeSubscriber: snapshot.canBecomeSubscriber)
    }

    /// The check itself failed — network, account, or a MusicKit error.
    /// Deliberately **not** `.gap`: a failed check is not evidence of absence,
    /// and rendering it as one would push a paying subscriber at an offer sheet.
    static func reduce(failure reason: String) -> SubscriptionState {
        .unavailable(reason: reason)
    }

    /// The gate. Every play intent in the app passes through here.
    ///
    /// The invariant under test: `.play` is reachable for `.catalog` content
    /// **only** from `.active`. `ApplicationMusicPlayer.play()` throws for a
    /// non-subscriber rather than falling back to a preview (DECISIONS M-02),
    /// so any other path reaching the player is a broken player by definition.
    static func resolve(
        _ source: ContentSource,
        in state: SubscriptionState
    ) -> PlayIntentOutcome {
        // Library content — purchased, matched, or uploaded — needs no
        // subscription, whatever the catalog situation is.
        guard source == .catalog else { return .play }

        switch state {
        case .active:
            return .play
        case .gap(let canBecomeSubscriber):
            return canBecomeSubscriber ? .presentSubscriptionOffer : .explainNoSubscription
        case .unknown:
            return .awaitSubscriptionCheck
        case .unavailable:
            // Degrade, don't block: library still plays, catalog explains itself.
            return .explainNoSubscription
        }
    }

    /// What a personalized-catalog *browse* screen (Home's shelves) should
    /// show for a given subscription state — a different question from
    /// `resolve(_:in:)`'s play-intent gate, but answered from the same
    /// `SubscriptionState`, so it belongs here rather than reimplemented
    /// ad hoc per screen.
    enum BrowseOutcome: Sendable, Equatable {
        /// Fetch and show the personalized shelves.
        case browse
        /// A confirmed non-subscriber. Not an error — explain plainly.
        case needsSubscription
        /// The check itself failed (or hasn't resolved). Not evidence the
        /// listener lacks a subscription — reporting it as
        /// `.needsSubscription` would tell a paying subscriber to sign up.
        /// `SubscriptionState.unavailable`'s own `reason` is an internal
        /// debug string (see its call sites), not user-facing text, so it
        /// isn't threaded through here either — same as `SubscriptionGapView`
        /// and `SettingsView`, which both show their own fixed copy for it.
        case checkFailed
    }

    static func resolveBrowse(in state: SubscriptionState) -> BrowseOutcome {
        switch state {
        case .active:
            return .browse
        case .gap:
            return .needsSubscription
        case .unknown, .unavailable:
            return .checkFailed
        }
    }
}
