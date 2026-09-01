import MusicKit
import SwiftUI

/// Bridges Apple's `MusicSubscriptionOffer` sheet into the app shell.
///
/// It lives here for one structural reason: `.musicSubscriptionOffer` is a
/// MusicKit symbol, and `Scripts/check-containment.sh` fails the build on an
/// `import MusicKit` outside `Services/Adapters/`. `RootTabView` calls
/// `.subscriptionOffer(isPresented:)` and stays MusicKit-free, which is what
/// keeps the whole UI layer buildable and runnable in the Simulator where
/// MusicKit does not function (DECISIONS M-09).
///
/// **This is not a paywall.** Hum charges nothing, unlocks nothing of its own,
/// and gates none of its features behind a subscription — the library plays
/// either way. This is Apple's own trial-membership entry point, shown at the
/// point of need because `ApplicationMusicPlayer.play()` throws for a
/// non-subscriber rather than falling back to a preview (M-02, confirmed on
/// device in Phase 1). Presenting it is the difference between the brief's
/// "trial prompt" and its "broken player".
private struct SubscriptionOfferModifier: ViewModifier {
    @Binding var isPresented: Bool
    let onFailure: @MainActor (String) -> Void

    func body(content: Content) -> some View {
        content.musicSubscriptionOffer(
            isPresented: $isPresented,
            options: options,
            onLoadCompletion: { error in
                // The sheet failed to load — offline, or an account Apple
                // cannot offer a membership to. Say so; do not leave a tap
                // that visibly does nothing.
                guard let error else { return }
                isPresented = false
                onFailure(error.localizedDescription)
            }
        )
    }

    private var options: MusicSubscriptionOffer.Options {
        var options = MusicSubscriptionOffer.Options.default
        // Every presentation in Hum is triggered by a play intent that the
        // subscription gate turned back, so this is always the accurate
        // message. No affiliate or campaign token is set: Hum takes no
        // commission on an Apple Music signup, which is the cleanest possible
        // answer to the DPLA rule against indirectly monetizing access.
        options.messageIdentifier = .playMusic
        return options
    }
}

extension View {
    /// Presents Apple's subscription offer. Dismissing it returns to a working
    /// app — the library still plays, and nothing stays blocked behind it.
    func subscriptionOffer(
        isPresented: Binding<Bool>,
        onFailure: @escaping @MainActor (String) -> Void
    ) -> some View {
        modifier(SubscriptionOfferModifier(isPresented: isPresented, onFailure: onFailure))
    }
}
