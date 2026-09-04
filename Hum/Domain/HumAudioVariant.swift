import Foundation

/// What's actually coming out of the speaker right now — mirrors MusicKit's
/// own `AudioVariant`, read-only, since that's all the framework exposes.
/// There is no settable "preferred quality" anywhere in MusicKit for a
/// third-party app to offer (checked against the real
/// `MusicKit.swiftinterface`, not assumed) — that stays a system Settings
/// control. This is the honest, read-only alternative: a badge naming
/// what's playing, not a picker choosing it.
enum HumAudioVariant: Sendable, Equatable, Codable {
    case dolbyAtmos
    case dolbyAudio
    case lossless
    case highResolutionLossless
    case lossyStereo
    case spatialAudio

    /// `nil` for `.lossyStereo` — that's the ordinary, expected case, and a
    /// badge reading "Lossy Stereo" on every other track would read as an
    /// apology for something that isn't a problem. The others are all a step
    /// up from that baseline, which is worth naming.
    var badgeLabel: String? {
        switch self {
        case .dolbyAtmos: "Dolby Atmos"
        case .dolbyAudio: "Dolby Audio"
        case .lossless: "Lossless"
        case .highResolutionLossless: "Hi-Res Lossless"
        case .lossyStereo: nil
        case .spatialAudio: "Spatial Audio"
        }
    }
}
