import SwiftUI

@main
struct HumWatchApp: App {
    @State private var player = WatchPlayerViewModel()

    var body: some Scene {
        WindowGroup {
            WatchRootView()
                .environment(player)
                .tint(Palette.honeyAmber)
        }
    }
}

/// Board 03, Section 03. Now Playing is the only screen — Library was a
/// second page here, but the relay this app is built on (see
/// `WatchConnectivityRelayService`'s own doc comment) only ever carries
/// playback state and Up Next, not a browsable library, so its four rows had
/// nothing to route to. Removed rather than shipped non-interactive, per
/// Board 03 revision item 12's own "flag, don't guess" rule applied to
/// itself: a placeholder with no path forward is worse than one screen done
/// well. Up Next is reached from this screen's own toolbar.
private struct WatchRootView: View {
    var body: some View {
        NowPlayingWatchView()
            .background(WatchPalette.ground)
    }
}
