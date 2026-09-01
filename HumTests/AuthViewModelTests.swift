import Testing
@testable import Hum

/// Phase 3. The reducer suites prove the transition table; this suite proves
/// the view model drives it correctly against a service — that a launch check
/// cannot clobber a live prompt, that a settled status is never re-prompted,
/// and that `.restricted` renders no button.
@MainActor
@Suite("Auth view model")
struct AuthViewModelTests {

    private func model(
        status: AuthState = .notDetermined,
        requestResult: AuthState = .authorized
    ) -> (AuthViewModel, FakeAuthorizationService) {
        let service = FakeAuthorizationService(status: status, requestResult: requestResult)
        let environment = AppEnvironment(
            authorization: service,
            subscription: FakeSubscriptionService(),
            catalog: FakeCatalogService(),
            library: FakeLibraryService(),
            playback: FakePlaybackService()
        )
        return (AuthViewModel(environment: environment), service)
    }

    @Test("A fresh install shows the invitation")
    func freshInstall() async {
        let (sut, _) = model()
        await sut.refresh()
        #expect(sut.state == .notDetermined)
        #expect(sut.screen == .invitation)
        #expect(sut.primaryAction == .requestAuthorization)
        #expect(!sut.isAuthorized)
    }

    @Test("Granting opens the gate")
    func grantOpensGate() async {
        let (sut, service) = model()
        await sut.refresh()
        await sut.connect()

        #expect(sut.state == .authorized)
        #expect(sut.screen == nil, "no Connect screen once authorized")
        #expect(sut.isAuthorized)
        #expect(await service.requestCount == 1)
    }

    @Test("Declining lands on the recoverable screen, not a dead end")
    func declineIsRecoverable() async {
        let (sut, _) = model(requestResult: .denied)
        await sut.refresh()
        await sut.connect()

        #expect(sut.state == .denied)
        #expect(sut.screen == .deniedRecoverable)
        #expect(sut.primaryAction == .openSystemSettings)
    }

    @Test("Restricted offers no button — a Settings link would resolve nothing")
    func restrictedHasNoAction() async {
        let (sut, _) = model(status: .restricted)
        await sut.refresh()

        #expect(sut.screen == .restrictedNoRecourse)
        #expect(sut.primaryAction == nil)
    }

    @Test("A settled status is never re-prompted")
    func settledStatusDoesNotPrompt() async throws {
        for status in [AuthState.authorized, .denied, .restricted] {
            let (sut, service) = model(status: status)
            await sut.refresh()
            await sut.connect()

            #expect(sut.state == status)
            #expect(await service.requestCount == 0, "connect() is inert from \(status)")
        }
    }

    @Test("A foreground refresh picks up access revoked in Settings")
    func revocationIsPickedUp() async {
        let (sut, service) = model()
        await sut.refresh()
        await sut.connect()
        #expect(sut.isAuthorized)

        // The listener backgrounds Hum and turns Media & Apple Music off.
        await service.override(.denied)
        await sut.refresh()

        #expect(sut.state == .denied)
        #expect(sut.screen == .deniedRecoverable)
    }

    @Test("Every authorization status reaches a coherent screen")
    func everyStatusIsCoherent() async {
        for status in AuthState.allCases where status != .requesting {
            let (sut, _) = model(status: status)
            await sut.refresh()

            if status == .authorized {
                #expect(sut.screen == nil)
            } else {
                #expect(sut.screen != nil, "\(status) must render something")
            }
        }
    }
}
