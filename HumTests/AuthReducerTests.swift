import Testing
@testable import Hum

/// Acceptance criterion: "MusicKit authorization flow handles all four
/// `MusicAuthorization.Status` cases correctly."
@Suite("Authorization")
struct AuthReducerTests {

    // MARK: - All four MusicKit statuses reach the right screen

    @Test("Every MusicKit status maps to a screen", arguments: [
        (AuthState.notDetermined, ConnectScreen.invitation),
        (AuthState.denied,        ConnectScreen.deniedRecoverable),
        (AuthState.restricted,    ConnectScreen.restrictedNoRecourse),
    ])
    func statusMapsToScreen(status: AuthState, expected: ConnectScreen) {
        #expect(AuthReducer.screen(for: status) == expected)
    }

    @Test("Authorized shows no Connect screen at all")
    func authorizedDismissesConnect() {
        #expect(AuthReducer.screen(for: .authorized) == nil)
    }

    @Test("Every state is accounted for — no case falls through")
    func everyStateHasADefinedScreen() {
        for state in AuthState.allCases {
            let screen = AuthReducer.screen(for: state)
            if state == .authorized {
                #expect(screen == nil)
            } else {
                #expect(screen != nil, "\(state) has no screen")
            }
        }
    }

    // MARK: - The denied / restricted split

    @Test("Denied offers Settings — the listener can undo their own no")
    func deniedOffersSettings() {
        #expect(AuthReducer.primaryAction(for: .deniedRecoverable) == .openSystemSettings)
    }

    @Test("Restricted offers NO action — a Settings link there is a dead end")
    func restrictedOffersNothing() {
        // The distinction this whole suite exists for. Screen Time / MDM
        // restrictions are not user-recoverable, so a button that "fixes" it
        // would send the listener to a switch they cannot move.
        #expect(AuthReducer.primaryAction(for: .restrictedNoRecourse) == nil)
    }

    @Test("Denied and restricted never render the same affordance")
    func deniedAndRestrictedDiffer() {
        #expect(
            AuthReducer.primaryAction(for: .deniedRecoverable)
            != AuthReducer.primaryAction(for: .restrictedNoRecourse)
        )
    }

    @Test("Invitation prompts; connecting offers nothing while in flight")
    func invitationAndConnecting() {
        #expect(AuthReducer.primaryAction(for: .invitation) == .requestAuthorization)
        #expect(AuthReducer.primaryAction(for: .connecting) == nil)
    }

    // MARK: - Transitions

    @Test("Connect tap moves the invitation into the spinner")
    func connectTapStartsRequest() {
        #expect(AuthReducer.reduce(.notDetermined, .connectTapped) == .requesting)
    }

    @Test("Connect tap is inert where no button exists", arguments: [
        AuthState.authorized, .denied, .restricted, .requesting,
    ])
    func connectTapInertElsewhere(state: AuthState) {
        #expect(AuthReducer.reduce(state, .connectTapped) == state)
    }

    @Test("A completed request adopts its result", arguments: [
        AuthState.authorized, .denied, .restricted,
    ])
    func requestCompletes(result: AuthState) {
        #expect(AuthReducer.reduce(.requesting, .requestCompleted(result)) == result)
    }

    @Test("A completion with no request in flight is ignored", arguments: [
        AuthState.notDetermined, .authorized, .denied, .restricted,
    ])
    func strayCompletionIgnored(state: AuthState) {
        // Guards duplicate callbacks and cancelled retries from resurrecting
        // a stale result over a settled state.
        #expect(AuthReducer.reduce(state, .requestCompleted(.authorized)) == state)
    }

    @Test("A slow launch status check cannot clobber a live request")
    func statusCheckDoesNotClobberInFlightRequest() {
        // The regression this guards: `currentStatus` resolves as
        // `.notDetermined` *after* the listener already tapped Connect,
        // dropping the spinner back to the invitation mid-prompt.
        #expect(AuthReducer.reduce(.requesting, .statusResolved(.notDetermined)) == .requesting)
    }

    @Test("Launch status is adopted from any settled state", arguments: [
        AuthState.notDetermined, .authorized, .denied, .restricted,
    ])
    func statusResolvedAdopted(resolved: AuthState) {
        #expect(AuthReducer.reduce(.notDetermined, .statusResolved(resolved)) == resolved)
    }

    @Test("`.requesting` is never adopted as a resolved status")
    func requestingIsNotAStatus() {
        // `.requesting` is Hum's own in-flight state, not a MusicKit status,
        // so it can never be the *result* of reading one. Without this, a
        // malformed adapter could strand the UI on a spinner forever.
        #expect(AuthReducer.reduce(.denied, .statusResolved(.requesting)) == .denied)
        #expect(AuthReducer.reduce(.requesting, .requestCompleted(.requesting)) == .requesting)
    }
}
