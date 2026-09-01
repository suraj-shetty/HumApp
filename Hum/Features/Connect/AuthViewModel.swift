import Observation

/// Owns authorization state for the app shell.
///
/// It holds no logic of its own worth the name: every transition goes through
/// `AuthReducer`, which is pure and already covers the brief's first named test
/// criterion. What lives here is the I/O the reducer refuses to do — asking the
/// service for a status, awaiting the system prompt — and nothing else.
@MainActor
@Observable
final class AuthViewModel {

    private(set) var state: AuthState = .notDetermined

    private let service: MusicAuthorizationService

    init(environment: AppEnvironment) {
        self.service = environment.authorization
    }

    // MARK: - Derived

    /// `nil` once authorized — the gate opens and the tabs take over.
    var screen: ConnectScreen? { AuthReducer.screen(for: state) }

    /// `nil` means *render no button*. Under `.restricted` that is the whole
    /// point: a Settings link there is a dead end.
    var primaryAction: ConnectPrimaryAction? {
        screen.flatMap(AuthReducer.primaryAction(for:))
    }

    var isAuthorized: Bool { state == .authorized }

    // MARK: - Intents

    /// Reads the current status without prompting.
    ///
    /// Called on launch and again whenever the app returns to the foreground,
    /// because access can be revoked in Settings while Hum is backgrounded —
    /// the reducer's `.statusResolved` guard is what makes the second call safe
    /// to fire mid-prompt.
    func refresh() async {
        let resolved = await service.current
        state = AuthReducer.reduce(state, .statusResolved(resolved))
    }

    /// The listener tapped "Connect Apple Music".
    ///
    /// iOS shows its prompt once per install; from any settled status this is
    /// inert by the reducer's own guard rather than by a check here.
    func connect() async {
        let requesting = AuthReducer.reduce(state, .connectTapped)
        guard requesting != state else { return }
        state = requesting

        let result = await service.request()
        state = AuthReducer.reduce(state, .requestCompleted(result))
    }
}
