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
    /// Attaches the mini player to `TabView`'s bottom accessory slot, and
    /// attaches *nothing* when there is no track.
    ///
    /// The conditional has to wrap the modifier rather than its content: the
    /// accessory container draws its own glass capsule, so returning an empty
    /// body from inside still leaves an empty pill floating above the tab bar.
    @ViewBuilder
    func playerAccessory<C: View>(
        track: HumTrack?,
        @ViewBuilder content: (HumTrack) -> C
    ) -> some View {
        if let track {
            self.tabViewBottomAccessory { content(track) }
        } else {
            self
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
        TabView(selection: $selection) {
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
        .overlay(alignment: .bottom) {
            if let toast = player.toast {
                ToastView(message: toast)
                    .padding(.bottom, Metrics.scrollBottomInset)
                    .transition(.opacity.combined(with: .offset(y: 8)))
            }
        }
        .animation(.easeOut(duration: 0.2), value: player.toast)
        // NOTE — Phase 3 attaches `.musicSubscriptionOffer(isPresented:)` here,
        // Apple's own trial-membership entry point. It is deliberately absent
        // now for two reasons: it is a MusicKit symbol, and this file is not
        // permitted to import MusicKit (it will be bridged from
        // Services/Adapters); and presenting it cannot be verified without a
        // device. `PlayerViewModel.isPresentingSubscriptionOffer` is already
        // driven by the tested subscription gate and is waiting for it.
    }
}
