import SwiftUI

/// The app shell: three tabs, the floating player bar, and the Now Playing
/// presentation.
///
/// **The bottom chrome is hand-built** — see `HumTabBar` for why, and for what
/// that trade costs. `TabView` is kept underneath with its own bar hidden,
/// rather than replaced with a switch over three views, because it is what
/// preserves each tab's navigation stack and `.task` state across selection
/// changes. Swapping it for a conditional would reintroduce the tear-down that
/// once read on device as "tap play, get thrown back to the library".
///
/// The player bar no longer uses `tabViewBottomAccessory`. That slot draws its
/// own capsule at its own width, which is exactly the divergence reported from
/// device: the tab bar widening to match the accessory above it. Placing both
/// surfaces here is what lets the design's 362 / 288 + 64 geometry hold.
///
/// **Chrome-only glass** still holds: every glass surface below comes from
/// `GlassSurface`, which the containment script keeps as the single file
/// allowed to call `glassEffect(`.

struct RootTabView: View {
    @Environment(PlayerViewModel.self) private var player
    @State private var selection: HumTab = .home
    @State private var isShowingNowPlaying = false
    /// The query lives here, not in `SearchView`, because the field that edits
    /// it is in the chrome and the results that answer it are in the tab. The
    /// one place both can see is their parent.
    @State private var searchQuery = ""
    /// Where Cancel returns to. Search is entered from whichever tab you were
    /// on, and dumping you back on Home from Library would lose your place.
    @State private var tabBeforeSearch: HumTab = .home

    enum HumTab: Hashable {
        case home, search, library
    }

    var body: some View {
        @Bindable var bindable = player

        return TabView(selection: $selection) {
            Tab(value: HumTab.home) {
                HomeView().toolbar(.hidden, for: .tabBar)
            }

            Tab(value: HumTab.library) {
                LibraryView().toolbar(.hidden, for: .tabBar)
            }

            Tab(value: HumTab.search) {
                SearchView(query: $searchQuery).toolbar(.hidden, for: .tabBar)
            }
        }
        .tint(Palette.honeyAmber)
        .onChange(of: selection) { old, new in
            if old != .search { tabBeforeSearch = old }
        }
        // `safeAreaInset` rather than an overlay: the chrome must push the
        // scroll content up, or track rows sit behind the glass.
        .safeAreaInset(edge: .bottom, spacing: 0) {
            bottomChrome
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
                ToastView(toast: toast)
                    .padding(.bottom, Metrics.chromeClearance)
                    .transition(.opacity.combined(with: .offset(y: 8)))
            }
        }
        .animation(.easeOut(duration: 0.2), value: player.toast)
    }

    /// The design's bottom chrome: the player capsule, then the tab row, as a
    /// single column so both align on the same 362pt edges.
    private var bottomChrome: some View {
        // One container for both surfaces: adjacent glass has to share one, or
        // the player capsule and the tab row refract each other along the gap
        // between them.
        ChromeGlassContainer(spacing: Metrics.chromeGap) {
            VStack(spacing: Metrics.chromeGap) {
                if let track = player.currentTrack {
                    PlayerBar(
                        track: track,
                        isPlaying: player.isPlaying,
                        onTap: { isShowingNowPlaying = true },
                        onPlayPause: player.togglePlayPause,
                        onNext: player.skipToNext
                    )
                    .frame(height: Metrics.chromeHeight)
                    .transition(.opacity.combined(with: .offset(y: 10)))
                }

                HumTabBar(
                    selection: $selection,
                    searchText: $searchQuery,
                    onCancelSearch: {
                        searchQuery = ""
                        selection = tabBeforeSearch
                    }
                )
            }
        }
        .padding(.horizontal, Metrics.chromeInset)
        .padding(.bottom, Metrics.chromeBottom)
        .animation(.easeOut(duration: 0.22), value: player.currentTrack?.id)
    }

    /// A retry is only honest when the check *failed*. A confirmed "no
    /// subscription" is an answer, and offering to re-ask it would be theatre.
    private var retryAction: (() -> Void)? {
        guard player.subscription.isUnavailable else { return nil }
        return { player.retrySubscriptionCheck() }
    }
}
