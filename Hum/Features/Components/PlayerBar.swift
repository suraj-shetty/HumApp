import SwiftUI

/// The mini player. **Chrome — glass.**
///
/// The material is requested explicitly, via `GlassSurface`. It used to come
/// from `TabView`'s `tabViewBottomAccessory` slot, and this file's doc said so
/// for a while after that stopped being true: when the bar moved out of the
/// accessory into `RootTabView`'s hand-built `safeAreaInset` (D-10), the slot's
/// material went with it and nothing replaced it. The bar rendered as an amber
/// tint over bare content — list rows read straight through it.
///
/// So the order below is load-bearing: `chromeGlass` supplies the material,
/// `amberGlass` lays the design's tint over it. The tint alone is not glass.
///
/// `RootTabView` wraps this and the tab bar in one `GlassEffectContainer`,
/// which is what keeps two adjacent glass surfaces from refracting each other.
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
        // Material, then the design's amber tint over it. No shadow here — the
        // container casts one for the whole chrome stack.
        .chromeGlass(in: Capsule(style: .continuous), tint: nil)
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
///
/// Three variants, design screen 30: **success** (amber, the default — a
/// confirmation needs no icon or action), **error** (terracotta, a
/// `#E29070` warning glyph, and an optional `Retry`), and **neutral** (white,
/// no icon). A playback failure and a library confirmation used to render
/// identically; this is what tells them apart (finding M-9).
struct ToastView: View {
    let toast: ToastMessage

    var body: some View {
        HStack(spacing: 10) {
            if toast.kind == .error {
                Image(systemName: HumIcon.warning)
                    .humFont(14, weight: .regular)
                    .foregroundStyle(Palette.terracottaLift)
                    .accessibilityHidden(true)
            }
            Text(toast.text)
                .humFont(14.5)
                .foregroundStyle(Palette.textPrimary)
            if toast.kind == .error, let onRetry = toast.onRetry {
                Button("Retry", action: onRetry)
                    .buttonStyle(.plain)
                    .humFont(14.5, weight: .medium)
                    .foregroundStyle(Palette.terracottaLift)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 13)
        .chromeGlassCapsule(tint: nil)
        .glassTint(in: Capsule(style: .continuous), tint)
        // A Retry button must stay its own element — combining it into the
        // toast would swallow its tap target from VoiceOver. Only the
        // button-less variants collapse to one static-text element.
        .accessibilityElement(children: (toast.kind == .error && toast.onRetry != nil) ? .contain : .combine)
    }

    private var tint: LinearGradient {
        switch toast.kind {
        case .success: Palette.amberGlassTint
        case .error: Palette.terracottaGlassTint
        case .neutral: Palette.neutralGlassTint
        }
    }
}
