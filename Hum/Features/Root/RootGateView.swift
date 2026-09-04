import SwiftUI

/// The authorization gate. Connect until MusicKit says yes, tabs after.
///
/// It is a gate on *authorization only*. A missing subscription never lands
/// here: the app runs, the library plays, and the gap is raised at the point a
/// catalog track is actually asked for. Blocking the whole app on a
/// subscription would be both hostile and the "broken player" the brief names.
struct RootGateView: View {
    @Environment(\.appEnvironment) private var environment
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var auth: AuthViewModel?

    /// Board 03 is a genuinely different layout, not the phone screen
    /// stretched (`docs/v1-musickit/DEVELOPMENT_PLAN.md` Phase 8's own
    /// framing) — regular width on an iPad idiom is the only place this app
    /// currently makes that call, matching the one other size-class check in
    /// the codebase (`NowPlayingView`'s landscape check).
    private var isIPadLayout: Bool {
        UIDevice.current.userInterfaceIdiom == .pad && horizontalSizeClass == .regular
    }

    var body: some View {
        ZStack {
            Palette.deepOnyx.ignoresSafeArea()

            if let auth {
                if let screen = auth.screen {
                    if isIPadLayout {
                        IPadConnectView(onConnect: { Task { await auth.connect() } })
                            .transition(.opacity)
                    } else {
                        ConnectView(
                            screen: screen,
                            onPrimaryAction: { Task { await auth.connect() } },
                            onRefresh: { Task { await auth.refresh() } }
                        )
                        .transition(.opacity)
                    }
                } else if isIPadLayout {
                    RootSplitView()
                        .transition(.opacity)
                } else {
                    RootTabView()
                        .transition(.opacity)
                }
            }
        }
        .animation(Motion.rise, value: auth?.screen)
        .task {
            let model = auth ?? AuthViewModel(environment: environment)
            auth = model
            await model.refresh()
        }
        // Access can be revoked in Settings while Hum is backgrounded — the
        // brief's "revoke and relaunch lands on the right state", without the
        // relaunch. `.statusResolved` is guarded in the reducer, so this
        // cannot clobber a prompt that is still on screen.
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active, let auth else { return }
            Task { await auth.refresh() }
        }
    }
}
