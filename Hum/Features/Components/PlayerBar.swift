import SwiftUI

/// The mini player. **Chrome — glass.**
///
/// The glass is supplied by `TabView`'s `tabViewBottomAccessory` slot, which is
/// the system's own mini-player placement on iOS 26. Nothing here calls
/// `.glassEffect()`, and that is deliberate on two counts: the design system
/// says the tab bar's material is native and must not be hand-built, and
/// applying our own glass *inside* a slot that already provides it would stack
/// glass on glass — the exact failure the boundary rules exist to prevent.
///
/// The system also owns the collapse/expand geometry between this accessory and
/// the tab bar, so no explicit `glassEffectID` is needed here.
struct PlayerBar: View {
    let track: HumTrack
    let isPlaying: Bool
    let onTap: () -> Void
    let onPlayPause: () -> Void
    let onNext: () -> Void

    var body: some View {
        // Measured from the design: 40pt art at radius 10 — a rounded square,
        // not a circle; title 13.5/Medium; artist 11.5 in amber at 85%; 11pt
        // gap. The app had a 46pt circle, a 14.5 title and a grey artist.
        HStack(spacing: 11) {
            ArtworkView(
                url: track.artworkURL,
                size: Metrics.artPlayerBar,
                cornerRadius: Metrics.radiusArt,
                warm: true
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(track.title)
                    .humFont(13.5, weight: .medium)
                    .foregroundStyle(Palette.textPrimary)
                    .lineLimit(1)
                Text(track.artist)
                    .humFont(11.5)
                    .foregroundStyle(Palette.honeyAmber.opacity(0.85))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            // The label is one tap target that opens Now Playing; the two
            // buttons beside it must not inherit that gesture.
            .contentShape(.rect)
            .onTapGesture(perform: onTap)

            IconButton(
                systemName: isPlaying ? HumIcon.pause : HumIcon.play,
                size: 17,
                weight: .regular,
                tint: Palette.textPrimary,
                label: isPlaying ? "Pause" : "Play",
                action: onPlayPause
            )

            IconButton(
                systemName: HumIcon.next,
                size: 17,
                weight: .regular,
                tint: Palette.textPrimary,
                label: "Next track",
                action: onNext
            )
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 9)
        // The accessory slot supplies the material; this is the design's amber
        // tint laid over it. No shadow — the slot casts its own.
        .amberGlass(in: Capsule(style: .continuous), shadow: false)
        .contentShape(.rect)
        .onTapGesture(perform: onTap)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Now playing: \(track.title) by \(track.artist)")
        .accessibilityHint("Opens the full player")
    }
}

/// A transient message. **Chrome — glass**, per the brief's list
/// ("Player Bar, Tab Bar, toolbars, Toasts, sheets").
struct ToastView: View {
    let message: String

    var body: some View {
        Text(message)
            .humFont(14)
            .foregroundStyle(Palette.textPrimary)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .chromeGlassCapsule(tint: nil)
            .amberGlass(in: Capsule(style: .continuous))
            .accessibilityAddTraits(.isStaticText)
    }
}
