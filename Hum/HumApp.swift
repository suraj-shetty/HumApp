import SwiftUI

/// Composition root.
///
/// The app roots at `RootGateView`, which shows `ConnectView` until MusicKit
/// authorization is granted and `RootTabView` after — decided by `AuthReducer`.
///
/// Authorization and subscription come from the live MusicKit adapters, proven
/// on device in Phase 1. Catalog, library, and playback are still the in-memory
/// preview services: their adapters are Phase 5. Swapping each one in is a line
/// here and touches no other file — the entire point of the protocol boundary.
@main
struct HumApp: App {
    private let environment: AppEnvironment
    @State private var player: PlayerViewModel

    init() {
        let environment = AppEnvironment.live()
        self.environment = environment
        _player = State(initialValue: PlayerViewModel(environment: environment))
    }

    var body: some Scene {
        WindowGroup {
            RootGateView()
                .environment(\.appEnvironment, environment)
                .environment(player)
                .preferredColorScheme(.dark)
                .tint(Palette.honeyAmber)
                .task { player.start() }
        }
    }
}
