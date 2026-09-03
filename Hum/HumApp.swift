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
///
/// **Debug builds only:** launching with `-HumUsePreviewServices YES` picks
/// `.preview()` instead of `.live()` — the in-memory fixtures every screen was
/// designed against. MusicKit does not function in the Simulator at all
/// (DECISIONS M-09), so this is how a design audit sees populated screens —
/// `xcrun simctl launch <device> <bundle-id> -HumUsePreviewServices YES` —
/// without hand-editing this file for every screenshot and reverting it
/// afterward, which is what every capture in `design-audit/` required until
/// now. `#if DEBUG` keeps the flag out of Release builds entirely: it cannot
/// be triggered by anything short of a debug install under Xcode or
/// `simctl`, never a real user's device.
@main
struct HumApp: App {
    private let environment: AppEnvironment
    @State private var player: PlayerViewModel

    init() {
        let environment = Self.resolveEnvironment()
        self.environment = environment
        _player = State(initialValue: PlayerViewModel(environment: environment))
    }

    @MainActor
    private static func resolveEnvironment() -> AppEnvironment {
        #if DEBUG
        if UserDefaults.standard.bool(forKey: "HumUsePreviewServices") {
            return .preview()
        }
        #endif
        return .live()
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
