import SwiftUI

/// Now Playing. **Entirely opaque content** — the ambient amber glow is a
/// radial gradient on Deep Onyx, not a material.
///
/// The morph in from the player bar is owned by the system: the bar lives in
/// `TabView`'s `tabViewBottomAccessory`, which animates its own expansion. This
/// content crossfades independently, so no opaque content is ever dragged
/// through a glass transition (ARCHITECTURE §6).
///
/// Landscape is a genuinely different layout, not a stretched portrait — the
/// prototype draws both.
struct NowPlayingView: View {
    @Environment(PlayerViewModel.self) private var player
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @State private var isShowingQueue = false

    private var isLandscape: Bool { verticalSizeClass == .compact }

    var body: some View {
        ZStack {
            background

            if let track = player.currentTrack {
                Group {
                    if isLandscape {
                        NowPlayingLandscapeLayout(
                            track: track,
                            onClose: { dismiss() },
                            onQueue: { isShowingQueue = true }
                        )
                    } else {
                        NowPlayingPortraitLayout(
                            track: track,
                            onClose: { dismiss() },
                            onQueue: { isShowingQueue = true }
                        )
                    }
                }
                .transition(.opacity)
            } else {
                EmptyStateView(
                    icon: HumIcon.musicNote,
                    headline: "Nothing playing",
                    message: "Pick something from your library or search the catalog.",
                    actionTitle: "Close",
                    action: { dismiss() }
                )
            }
        }
        .animation(.easeInOut(duration: 0.2), value: player.currentTrack?.id)
        .sheet(isPresented: $isShowingQueue) {
            QueueView()
        }
    }

    private var background: some View {
        ZStack {
            Palette.deepOnyx
            Palette.ambientWash(center: UnitPoint(x: 0.5, y: 0.26))
        }
        .ignoresSafeArea()
    }
}

// MARK: - Portrait

private struct NowPlayingPortraitLayout: View {
    let track: HumTrack
    let onClose: () -> Void
    let onQueue: () -> Void

    @Environment(PlayerViewModel.self) private var player

    var body: some View {
        VStack(spacing: 0) {
            NowPlayingBar(onClose: onClose, onQueue: onQueue)

            Spacer(minLength: 12)

            ArtworkView(
                url: track.artworkURL,
                size: Metrics.artNowPlaying,
                cornerRadius: Metrics.radiusArt,
                label: track.albumTitle ?? track.title
            )
            .shadow(color: .black.opacity(0.6), radius: 30, y: 26)

            Spacer(minLength: 20)

            // Progress sits *above* the title in the design, not below it.
            VStack(spacing: 24) {
                ProgressScrubber()
                titleRow
                TransportControls(size: Metrics.transportPrimary)
                VolumeSlider()
            }
            .padding(.horizontal, Metrics.heroGutter)

            Spacer(minLength: 16)

            footer
        }
        .padding(.bottom, 8)
    }

    private var titleRow: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 7) {
                Text(track.title)
                    .humFont(HumTextStyle(size: 23, weight: .regular, relativeTo: .title, tracking: -0.3))
                    .foregroundStyle(Palette.textPrimary)
                    .lineLimit(1)
                Text(track.artist)
                    .humFont(17)
                    .foregroundStyle(Palette.honeyAmber)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            AddToLibraryButton(track: track)
        }
    }

    private var footer: some View {
        // The design's utility row. Two changes beyond styling:
        //
        // - AirPlay was a decorative glyph with `accessibilityHidden(true)` and
        //   no action — a control that looked tappable and was not. It is now
        //   the system route picker.
        // - The share glyph is gone. It did nothing, and sharing MusicKit
        //   content is a compliance line Hum does not cross (DESIGN_AUDIT §3).
        HStack {
            Spacer()

            Button(action: onQueue) {
                Text("Up next · \(player.upNext.count)")
                    .humFont(HumTextStyle(size: 13, relativeTo: .caption2, tracking: 1.4, uppercase: true))
                    .foregroundStyle(Palette.textSecondary.opacity(0.9))
                    .frame(height: Metrics.tapTarget)
                    .padding(.horizontal, 12)
                    .contentShape(.rect)
            }
            .buttonStyle(.pressable)

            Spacer()

            RoutePickerButton()
                .frame(width: Metrics.tapTarget, height: Metrics.tapTarget)

            Spacer()
        }
        .padding(.horizontal, Metrics.heroGutter)
    }
}

// MARK: - Landscape

private struct NowPlayingLandscapeLayout: View {
    let track: HumTrack
    let onClose: () -> Void
    let onQueue: () -> Void

    @Environment(PlayerViewModel.self) private var player

    var body: some View {
        HStack(spacing: 0) {
            rail

            ArtworkView(
                url: track.artworkURL,
                size: Metrics.artNowPlaying,
                cornerRadius: Metrics.radiusArt,
                label: track.albumTitle ?? track.title
            )
            .shadow(color: .black.opacity(0.6), radius: 26, y: 18)
            .padding(.vertical, 34)

            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 9) {
                    Text(player.sourceLabel.isEmpty ? "Now playing" : "Playing from \(player.sourceLabel)")
                        .humFont(HumTextStyle(size: 11.5, relativeTo: .caption2, tracking: 1.6, uppercase: true))
                        .foregroundStyle(Palette.textQuaternary)
                    Text(track.title)
                        .humFont(HumTextStyle(size: 27, weight: .light, relativeTo: .title, tracking: -0.4))
                        .foregroundStyle(Palette.textPrimary)
                        .lineLimit(1)
                    Text(track.artist)
                        .humFont(16)
                        .foregroundStyle(Palette.honeyAmber)
                        .lineLimit(1)
                }

                ProgressScrubber()

                TransportControls(size: Metrics.transportPrimaryCompact, alignment: .leading)
            }
            .padding(.leading, 36)
            .padding(.trailing, Metrics.transportSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var rail: some View {
        VStack {
            IconButton(
                systemName: HumIcon.back,
                size: 21,
                tint: Palette.textSecondary,
                label: "Close player",
                action: onClose
            )
            Spacer()
            IconButton(
                systemName: HumIcon.queue,
                size: 20,
                tint: Palette.textSecondary,
                label: "Show queue",
                action: onQueue
            )
        }
        .padding(.vertical, 22)
        .frame(width: 56)
    }
}

// MARK: - Shared pieces

private struct NowPlayingBar: View {
    let onClose: () -> Void
    let onQueue: () -> Void

    @Environment(PlayerViewModel.self) private var player

    var body: some View {
        HStack {
            IconButton(
                systemName: HumIcon.collapse,
                size: 22,
                weight: .regular,
                tint: Palette.textSecondary,
                label: "Close player",
                action: onClose
            )
            Spacer()
            Text(player.sourceLabel)
                .humFont(HumTextStyle(size: 11.5, relativeTo: .caption2, tracking: 1.6, uppercase: true))
                .foregroundStyle(Palette.textTertiary)
                .lineLimit(1)
            Spacer()
            IconButton(
                systemName: HumIcon.queue,
                size: 21,
                tint: Palette.textSecondary,
                label: "Show queue",
                action: onQueue
            )
        }
        .padding(.horizontal, Metrics.navGutter)
    }
}

/// The progress bar. **Opaque.**
///
/// Seeking is a standard first-party MusicKit control
/// (`ApplicationMusicPlayer.playbackTime`) and is user-initiated, so it sits
/// inside the compliance rule even though the brief's shorthand names only
/// play/pause/skip (DECISIONS M-08).
private struct ProgressScrubber: View {
    @Environment(PlayerViewModel.self) private var player
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dragFraction: Double?

    private var fraction: Double { dragFraction ?? player.progress }

    var body: some View {
        VStack(spacing: 9) {
            GeometryReader { proxy in
                let width = proxy.size.width
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.14))
                    Capsule()
                        .fill(Palette.honeyAmber)
                        .frame(width: max(0, width * fraction))
                        // Animate the fill *only*. Applying this to the whole
                        // stack animates the timestamp labels too, which
                        // cross-fades their digits and renders them doubled.
                        .animation(reduceMotion ? nil : .linear(duration: 0.25), value: fraction)
                }
                .frame(height: 5)
                .frame(maxHeight: .infinity)
                .contentShape(.rect)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            dragFraction = min(max(value.location.x / max(width, 1), 0), 1)
                        }
                        .onEnded { value in
                            let target = min(max(value.location.x / max(width, 1), 0), 1)
                            player.seek(toFraction: target)
                            dragFraction = nil
                        }
                )
            }
            .frame(height: 20)

            HStack {
                Text(player.elapsed.humTimestamp)
                Spacer()
                Text(player.remaining.humRemaining)
            }
            .humFont(HumTextStyle.timecode.size(12))
            .foregroundStyle(Palette.textTertiary)
        }
        // One accessibility element for the whole control, with a real value
        // and an adjustable action — a bare progress bar tells VoiceOver
        // nothing and cannot be operated.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Playback position")
        .accessibilityValue(
            "\(player.elapsed.humSpokenDuration) of \(player.duration.humSpokenDuration)"
        )
        .accessibilityAdjustableAction { direction in
            let step = 0.05
            switch direction {
            case .increment: player.seek(toFraction: min(player.progress + step, 1))
            case .decrement: player.seek(toFraction: max(player.progress - step, 0))
            @unknown default: break
            }
        }
    }
}

/// Transport. **Opaque** — including the primary button (DECISIONS M-07).
private struct TransportControls: View {
    var size: CGFloat
    var alignment: HorizontalAlignment = .center

    @Environment(PlayerViewModel.self) private var player

    var body: some View {
        // Measured from the design: three controls only — previous, play,
        // next — 26pt glyphs either side of a 78pt disc, 34 apart and centred.
        // Shuffle and repeat are not in this row; the design puts shuffle in a
        // secondary utility row below, and `secondaryControls` follows it.
        VStack(spacing: 26) {
            HStack(spacing: alignment == .leading ? 26 : 34) {
                if alignment == .leading { Spacer(minLength: 0) }

                IconButton(
                    systemName: HumIcon.previous,
                    size: 26,
                    tint: Palette.textPrimary,
                    target: Metrics.transportSecondary,
                    pressScale: Motion.pressScaleTransport,
                    label: "Previous track",
                    action: player.skipToPrevious
                )

                playButton

                IconButton(
                    systemName: HumIcon.next,
                    size: 26,
                    tint: Palette.textPrimary,
                    target: Metrics.transportSecondary,
                    pressScale: Motion.pressScaleTransport,
                    label: "Next track",
                    action: player.skipToNext
                )

                if alignment == .leading { Spacer(minLength: 0) }
            }

            secondaryControls
        }
        .frame(maxWidth: alignment == .leading ? nil : .infinity)
    }

    /// Shuffle and repeat, at the design's secondary weight: 21pt glyphs, 56
    /// apart, white at 66% until active, then amber.
    private var secondaryControls: some View {
        HStack(spacing: 56) {
            IconButton(
                systemName: HumIcon.shuffle,
                size: 21,
                tint: player.queue.shuffleEnabled
                    ? Palette.honeyAmber
                    : Palette.textPrimary.opacity(0.66),
                label: player.queue.shuffleEnabled ? "Shuffle on" : "Shuffle off",
                action: player.toggleShuffle
            )

            IconButton(
                systemName: player.queue.repeatMode == .one ? HumIcon.repeatOne : HumIcon.repeatAll,
                size: 21,
                tint: player.queue.repeatMode == .off
                    ? Palette.textPrimary.opacity(0.66)
                    : Palette.honeyAmber,
                label: repeatLabel,
                action: player.cycleRepeat
            )
        }
    }

    private var repeatLabel: String {
        switch player.queue.repeatMode {
        case .off: "Repeat off"
        case .all: "Repeat all"
        case .one: "Repeat one"
        }
    }

    private var playButton: some View {
        Button(action: player.togglePlayPause) {
            Image(systemName: player.isPlaying ? HumIcon.pause : HumIcon.play)
                .humFont(27, weight: .regular)
                .foregroundStyle(Palette.textPrimary)
                .frame(width: size, height: size)
                // Solid Honey Amber with an amber glow, as measured. The build
                // had a translucent 30%→13% wash and a white border, which read
                // as a dimmed button rather than the screen's one bright disc.
                .background(Palette.honeyAmber, in: Circle())
                .shadow(color: Palette.honeyAmber.opacity(0.35), radius: 17, y: 10)
        }
        .buttonStyle(.pressableTransport)
        .accessibilityLabel(player.isPlaying ? "Pause" : "Play")
    }
}

private struct AddToLibraryButton: View {
    let track: HumTrack
    @Environment(PlayerViewModel.self) private var player

    var body: some View {
        let added = player.isInLibrary(track)
        return IconButton(
            systemName: added ? HumIcon.inLibrary : HumIcon.addToLibrary,
            size: 23,
            weight: .light,
            tint: added ? Palette.honeyAmber : Palette.textSecondary,
            label: added ? "In your library" : "Add to library",
            action: { player.addToLibrary(track) }
        )
        .disabled(added)
    }
}
