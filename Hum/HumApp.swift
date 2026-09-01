import SwiftUI

/// Composition root.
///
/// The authorization gate is **Phase 3** — until then the app roots directly at
/// `RootTabView`. Phase 3 wraps this in `ConnectView` driven by `AuthReducer`,
/// which is already written and tested.
///
/// Services come from `AppEnvironment.preview()` because the MusicKit adapters
/// do not exist yet: the Phase 1 spike that would validate them is blocked on a
/// bundle ID and a subscribed device (DECISIONS M-09, M-10). Swapping in the
/// live adapters is a one-line change here and touches no other file — which is
/// the entire point of the protocol boundary.
@main
struct HumApp: App {
    private let environment: AppEnvironment
    @State private var player: PlayerViewModel

    init() {
        let environment = AppEnvironment.preview()
        self.environment = environment
        _player = State(initialValue: PlayerViewModel(environment: environment))
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environment(\.appEnvironment, environment)
                .environment(player)
                .preferredColorScheme(.dark)
                .tint(Palette.honeyAmber)
                .task { player.start() }
        }
    }
}
