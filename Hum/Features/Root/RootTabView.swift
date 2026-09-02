import SwiftUI

/// The app shell: three tabs, the floating player bar, and the Now Playing
/// presentation.
///
/// **Chrome-only glass.** The tab bar is the native `TabView` — not a
/// hand-built capsule — and Search uses `Tab(role: .search)` so iOS 26 renders
/// it as its own element with the correct accessibility semantics and
/// scroll-minimize behaviour.
///
/// The player bar occupies `tabViewBottomAccessory`, iOS 26's own mini-player
/// slot. That is what keeps it *above* the tab bar rather than on top of it,
/// and it means the two adjacent glass surfaces share the system's container
/// automatically — hand-rolling a second capsule would put two glass elements
/// outside a shared container, the specific failure Apple's guidance names.
private extension View {
    /// Attaches the mini player to `TabView`'s bottom accessory slot.
    ///
    /// The modifier is applied **unconditionally** and hidden via
    /// `isEnabled:`, and that matters far more than it looks. Wrapping the
    /// modifier in an `if/else` gives the two branches different view types,
    /// so the moment the first track arrives the `TabView`'s structural
    /// identity changes and SwiftUI tears down every tab beneath it: open
    /// detail screens pop to root and every `.task` re-runs. On device that
    /// read as "tap play, get thrown back to the library, watch it reload".
    ///
    /// `isEnabled:` is what makes the stable form possible. The accessory
    /// container draws its own glass capsule, so an empty content body still
    /// leaves a blank pill floating above the tab bar — verified in the
    /// Simulator, and the reason the conditional was reached for originally.
    @ViewBuilder
    func playerAccessory<C: View>(
        track: HumTrack?,
        @ViewBuilder content: (HumTrack) -> C
    ) -> some View {
        // `#available` is resolved once for the life of the process, so
        // unlike a `track != nil` conditional it never flips a branch and
        // never re-identifies the `TabView`.
        if #available(iOS 26.1, *) {
            tabViewBottomAccessory(isEnabled: track != nil) {
                if let track { content(track) }
            }
        } else {
            // 26.0 has no `isEnabled:`. Keep the stable shape and accept the
            // blank pill before the first track: a cosmetic blemish on one
            // point release beats tearing the tabs down on every listener.
            tabViewBottomAccessory {
                if let track { content(track) }
            }
        }
    }
}

struct RootTabView: View {
    @Environment(PlayerViewModel.self) private var player
    @State private var selection: HumTab = .home
    @State private var isShowingNowPlaying = false

    enum HumTab: Hashable {
        case home, search, library
    }

    var body: some View {
        @Bindable var bindable = player

        return TabView(selection: $selection) {
            Tab("Home", systemImage: HumIcon.home, value: HumTab.home) {
                HomeView()
            }

            Tab("Library", systemImage: HumIcon.library, value: HumTab.library) {
                LibraryView()
            }

            // `role: .search` is load-bearing — it is what makes iOS render
            // Search as a separate element rather than a fourth item in the
            // capsule, matching the design without hand-building anything.
            Tab(value: HumTab.search, role: .search) {
                SearchView()
            }
        }
        .tint(Palette.honeyAmber)
        .playerAccessory(track: player.currentTrack) { track in
            PlayerBar(
                track: track,
                isPlaying: player.isPlaying,
                onTap: { isShowingNowPlaying = true },
                onPlayPause: player.togglePlayPause,
                onNext: player.skipToNext
            )
        }
        .fullScreenCover(isPresented: $isShowingNowPlaying) {
            NowPlayingView()
        }
        // Apple's own trial-membership entry point, bridged from
        // Services/Adapters because this file may not import MusicKit. It is
        // presented only when the tested subscription gate turns back a play
        // intent *and* Apple can actually offer this account a membership;
        // dismissing it returns to a working app.
        .subscriptionOffer(
            isPresented: $bindable.isPresentingSubscriptionOffer,
            onFailure: { reason in player.subscriptionOfferFailed(reason) }
        )
        // The gap an offer cannot close: account can't subscribe, or the check
        // failed. Explains instead of dangling a sheet that would fail.
        .sheet(isPresented: $bindable.isPresentingSubscriptionGap) {
            SubscriptionGapView(state: player.subscription, onRetry: retryAction)
        }
        .overlay(alignment: .bottom) {
            if let toast = player.toast {
                ToastView(message: toast)
                    .padding(.bottom, Metrics.chromeClearance)
                    .transition(.opacity.combined(with: .offset(y: 8)))
            }
        }
        .animation(.easeOut(duration: 0.2), value: player.toast)
    }

    /// A retry is only honest when the check *failed*. A confirmed "no
    /// subscription" is an answer, and offering to re-ask it would be theatre.
    private var retryAction: (() -> Void)? {
        guard player.subscription.isUnavailable else { return nil }
        return { player.retrySubscriptionCheck() }
    }
}
