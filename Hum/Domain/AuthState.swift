/// Hum's mirror of `MusicAuthorization.Status`, plus the in-flight `.requesting`
/// case MusicKit does not model but the Connect screen needs (the prototype
/// draws a spinner state).
///
/// The `.denied` / `.restricted` split is the part worth being careful about.
/// They look identical in a status enum and are completely different for the
/// person holding the phone:
///
/// - `.denied` — *they* said no. Recoverable: Settings → Hum → Media & Apple Music.
/// - `.restricted` — Screen Time, MDM, or a parental control said no. **Not**
///   recoverable by the user. Offering them a Settings button leads to a screen
///   where the switch they need either isn't there or won't move.
enum AuthState: Sendable, Equatable, CaseIterable {
    case notDetermined
    case requesting
    case authorized
    case denied
    case restricted
}
