import MusicKit

/// Real `MusicAuthorization` wrapper. One of the few files permitted to
/// `import MusicKit` (ARCHITECTURE §1).
///
/// `@MainActor` because `MusicAuthorization.request()` presents system UI.
@MainActor
final class MusicKitAuthorizationAdapter: MusicAuthorizationService {

    var current: AuthState {
        Self.map(MusicAuthorization.currentStatus)
    }

    func request() async -> AuthState {
        // iOS presents the prompt only once per install; for any settled
        // status this returns it unchanged rather than re-prompting.
        Self.map(await MusicAuthorization.request())
    }

    /// The whole reason this adapter exists: MusicKit's status never travels
    /// past this line. Everything above works in `AuthState`.
    ///
    /// `nonisolated` — a pure mapping with no UI, so callers should not have to
    /// hop to the main actor just to translate a value.
    nonisolated static func map(_ status: MusicAuthorization.Status) -> AuthState {
        switch status {
        case .notDetermined: .notDetermined
        case .denied: .denied
        case .restricted: .restricted
        case .authorized: .authorized
        @unknown default: .denied
        }
    }
}
