import SwiftUI

/// The composition root. The one place concrete services are chosen.
///
/// Nothing above this line knows whether it is talking to MusicKit or to the
/// in-memory preview services — which is what lets every screen build and run
/// in the Simulator (DECISIONS M-09) and what will let the MusicKit adapters
/// drop in during Phase 1 without touching a single ViewModel.
struct AppEnvironment: Sendable {
    let authorization: MusicAuthorizationService
    let subscription: SubscriptionService
    let catalog: MusicCatalogService
    let library: MusicLibraryService
    let playback: PlaybackService

    /// In-memory services. The only wiring available until the MusicKit
    /// adapters land in Phase 1.
    static func preview(
        auth: AuthState = .authorized,
        subscription: SubscriptionState = .active
    ) -> AppEnvironment {
        AppEnvironment(
            authorization: PreviewAuthorizationService(status: auth),
            subscription: PreviewSubscriptionService(state: subscription),
            catalog: PreviewCatalogService(),
            library: PreviewLibraryService(),
            playback: PreviewPlaybackService()
        )
    }
}

private struct AppEnvironmentKey: EnvironmentKey {
    static let defaultValue: AppEnvironment = .preview()
}

extension EnvironmentValues {
    var appEnvironment: AppEnvironment {
        get { self[AppEnvironmentKey.self] }
        set { self[AppEnvironmentKey.self] = newValue }
    }
}
