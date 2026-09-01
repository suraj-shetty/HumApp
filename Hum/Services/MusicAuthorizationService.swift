/// Wraps `MusicAuthorization`. The live adapter is `@MainActor` because
/// `MusicAuthorization.request()` is.
protocol MusicAuthorizationService: Sendable {
    /// The current status, without prompting.
    var current: AuthState { get async }
    /// Prompts if and only if the status is `.notDetermined`; otherwise returns
    /// the existing status unchanged. iOS shows the system prompt once per
    /// install — asking twice does nothing.
    func request() async -> AuthState
}
