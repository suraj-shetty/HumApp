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

/// Board 03, Section 03. Now Playing is the default screen; Library is one
/// page swipe away — the same "one decision per screen" the board asks for,
/// rather than a tab bar watchOS has no room to draw. Up Next is reached
/// from Now Playing's own toolbar, matching "the capsule at the bottom
/// returns to playback" from Library's own side of that relationship.
private struct WatchRootView: View {
    var body: some View {
        TabView {
            NowPlayingWatchView()
            LibraryWatchView()
        }
        .tabViewStyle(.verticalPage)
        .background(WatchPalette.ground)
    }
}
