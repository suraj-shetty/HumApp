/// Intents and results that can move authorization state.
enum AuthAction: Sendable, Equatable {
    /// The status MusicKit reports on launch, without prompting.
    case statusResolved(AuthState)
    /// The listener tapped "Connect Apple Music".
    case connectTapped
    /// `MusicAuthorization.request()` came back.
    case requestCompleted(AuthState)
}

/// What the Connect screen shows. Semantic, not copy — the view owns wording.
enum ConnectScreen: Sendable, Equatable {
    /// First run. Explain what access buys, offer the prompt.
    case invitation
    /// Request in flight — the prototype's spinner.
    case connecting
    /// The listener declined. Recoverable in Settings.
    case deniedRecoverable
    /// Screen Time / MDM / parental controls declined. **Not** recoverable.
    case restrictedNoRecourse
}

enum ConnectPrimaryAction: Sendable, Equatable {
    case requestAuthorization
    case openSystemSettings
}

/// Pure. No I/O, no MusicKit, no async. Covers the brief's first named test
/// criterion: "handles all four `MusicAuthorization.Status` cases correctly".
struct AuthReducer: Sendable {

    static func reduce(_ state: AuthState, _ action: AuthAction) -> AuthState {
        switch action {
        case .statusResolved(let resolved):
            // A launch-time status check must not clobber a request already in
            // flight — the check is a snapshot of the past, the request is the
            // present. Without this guard a slow `currentStatus` read can drop
            // the spinner back to the invitation mid-prompt.
            guard state != .requesting else { return state }
            // `.requesting` is Hum's own state, not a MusicKit status; it can
            // never be the *result* of a status read.
            return resolved == .requesting ? state : resolved

        case .connectTapped:
            // Only meaningful from the invitation. From `.denied`, `.restricted`
            // or `.authorized` there is no such button, so the action is inert
            // rather than a state corruption.
            guard state == .notDetermined else { return state }
            return .requesting

        case .requestCompleted(let result):
            // Only a request in flight can complete. A stray completion — a
            // duplicate callback, a cancelled retry — is ignored.
            guard state == .requesting else { return state }
            return result == .requesting ? state : result
        }
    }

    /// `nil` once authorized: the Connect screen is gone and the tabs are up.
    static func screen(for state: AuthState) -> ConnectScreen? {
        switch state {
        case .authorized: nil
        case .notDetermined: .invitation
        case .requesting: .connecting
        case .denied: .deniedRecoverable
        case .restricted: .restrictedNoRecourse
        }
    }

    /// `nil` means *render no button*.
    ///
    /// `.restrictedNoRecourse` returning `nil` is the point of this function.
    /// A Settings deep-link there is a dead end, and a button that resolves
    /// nothing is worse than no button at all.
    static func primaryAction(for screen: ConnectScreen) -> ConnectPrimaryAction? {
        switch screen {
        case .invitation: .requestAuthorization
        case .connecting: nil
        case .deniedRecoverable: .openSystemSettings
        case .restrictedNoRecourse: nil
        }
    }
}
