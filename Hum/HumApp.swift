import SwiftUI

/// Composition root.
///
/// The app roots at `LaunchFlowView` — splash, then onboarding once ever,
/// then `RootGateView`, which shows `ConnectView` until MusicKit
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
/// now.
///
/// Two more flags, only meaningful alongside the one above, force the two
/// states that flag alone cannot reach — Connect's four screens and the
/// subscription gap both need a specific `AuthState` / `SubscriptionState`,
/// not just "some preview data":
///
/// - `-HumPreviewAuthState <case>` — `notDetermined`, `requesting`,
///   `denied`, or `restricted`. Unset stays `.authorized`, `.preview()`'s own
///   default, so the flag above still behaves exactly as before this existed.
/// - `-HumPreviewSubscriptionState <case>` — `gap` or `unavailable`. Unset
///   stays `.active`. `.gap(canBecomeSubscriber: true)` is deliberately not
///   offered: it routes straight to Apple's own offer sheet and was never
///   `SubscriptionGapView`'s to reach.
///
/// A fourth, unrelated to the three above: `-HumForceOffline YES` forces
/// `NetworkMonitor.isOffline`, for the same reason — the Simulator shares the
/// host Mac's own network, which there is no way to actually disconnect from
/// here, so Home's offline banner and downloaded-only shelf (design screen
/// 11) need a forced path to be reachable at all.
///
/// `#if DEBUG` keeps all four out of Release builds entirely: they cannot be
/// triggered by anything short of a debug install under Xcode or `simctl`,
/// never a real user's device.
@main
struct HumApp: App {
    private let environment: AppEnvironment
    @State private var player: PlayerViewModel
    /// Board 03, Section 03 — relays playback to a paired Apple Watch.
    /// Kept alive here for the same reason `player` is: it's a
    /// `WCSessionDelegate`, so nothing may deallocate it for the app's
    /// lifetime. No-ops on iPad (`WCSession.isSupported()` is `false` there).
    @State private var watchRelay: WatchConnectivityRelayService?

    init() {
        let environment = Self.resolveEnvironment()
        self.environment = environment
        let player = PlayerViewModel(environment: environment)
        _player = State(initialValue: player)
        _watchRelay = State(initialValue: WatchConnectivityRelayService(player: player))
    }

    @MainActor
    private static func resolveEnvironment() -> AppEnvironment {
        #if DEBUG
        let defaults = UserDefaults.standard
        if defaults.bool(forKey: "HumUsePreviewServices") {
            return .preview(
                auth: previewAuthState(defaults),
                subscription: previewSubscriptionState(defaults)
            )
        }
        #endif
        return .live()
    }

    #if DEBUG
    private static func previewAuthState(_ defaults: UserDefaults) -> AuthState {
        switch defaults.string(forKey: "HumPreviewAuthState") {
        case "notDetermined": .notDetermined
        case "requesting": .requesting
        case "denied": .denied
        case "restricted": .restricted
        default: .authorized
        }
    }

    private static func previewSubscriptionState(_ defaults: UserDefaults) -> SubscriptionState {
        switch defaults.string(forKey: "HumPreviewSubscriptionState") {
        case "gap": .gap(canBecomeSubscriber: false)
        case "unavailable": .unavailable(reason: "Forced via -HumPreviewSubscriptionState")
        default: .active
        }
    }
    #endif

    var body: some Scene {
        WindowGroup {
            LaunchFlowView()
                .environment(\.appEnvironment, environment)
                .environment(player)
                .preferredColorScheme(.dark)
                .tint(Palette.honeyAmber)
                .task { player.start() }
        }
    }
}
