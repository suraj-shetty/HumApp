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
            NowPlayingBar(track: track, onClose: onClose)

            Spacer(minLength: 12)

            // The design's hero is a circular artwork with the progress track
            // wrapped around it, not a rounded square above a linear bar.
            // Buffering (design screen 24) swaps the position-based arc for a
            // spinner — there's no meaningful progress to show yet, and
            // MusicKit gives no partial-load fraction to draw one from.
            Group {
                if player.isBuffering {
                    BufferingRing {
                        CircularArtworkView(
                            url: track.artworkURL,
                            size: Metrics.artNowPlayingDisc,
                            label: track.albumTitle ?? track.title
                        )
                    }
                } else {
                    ProgressRing {
                        CircularArtworkView(
                            url: track.artworkURL,
                            size: Metrics.artNowPlayingDisc,
                            label: track.albumTitle ?? track.title
                        )
                        // `0 0 68px 6px rgba(232,163,61,.22)` — an amber bloom centred
                        // on the disc, not a drop shadow. This was a black shadow
                        // offset 26pt down, which read as a card sitting on the screen
                        // rather than as a lit disc, and it is the one thing carrying
                        // the warmth on the app's centrepiece.
                        //
                        // CSS blur halves into a SwiftUI radius. The 6px spread has no
                        // SwiftUI equivalent and is left off rather than faked by
                        // inflating the radius, which would spread the glow thinner
                        // instead of denser.
                        .shadow(color: Palette.honeyAmber.opacity(0.22), radius: 34)
                    }
                }
            }

            if player.isBuffering {
                Text("Buffering")
                    .humFont(HumTextStyle(size: 12.5, relativeTo: .caption, tracking: 1.4, uppercase: true))
                    .foregroundStyle(Palette.honeyAmber.opacity(0.85))
                    .padding(.top, 14)
            }

            Spacer(minLength: 20)

            VStack(spacing: 24) {
                TimecodeRow()
                titleRow
                TransportControls(size: Metrics.transportPrimary, showsSecondaryControls: false)
                VolumeRow()
            }
            .padding(.horizontal, Metrics.heroGutter)
            // The design dims title, artist and transport to 55% while
            // buffering — everything below the disc reads as "waiting",
            // not "broken".
            .opacity(player.isBuffering ? 0.55 : 1)
            .disabled(player.isBuffering)

            Spacer(minLength: 16)

            bottomActionRow
        }
        .padding(.bottom, 8)
    }

    // Centred, title and artist alone — as measured (screen 23). It carried
    // a trailing Add to Library button, left-aligned around it; the design
    // draws neither the alignment nor the control here (NP-2). The action
    // moved to the header's overflow menu rather than disappearing.
    private var titleRow: some View {
        VStack(spacing: 7) {
            Text(track.title)
                .humFont(HumTextStyle(size: 27, weight: .light, relativeTo: .title, tracking: -0.4))
                .foregroundStyle(Palette.textPrimary)
                .lineLimit(1)
            Text(track.artist)
                .humFont(16)
                .foregroundStyle(Palette.honeyAmber)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }

    // The design's bottom action row: queue, lyrics, shuffle, 56pt apart
    // (screen 23). Lyrics is screen 34 and unbuilt, so it is left out rather
    // than wired to nothing (NP-7) — a dead button is worse than no button.
    //
    // Repeat and AirPlay are not in the design here, but they are real,
    // tested controls (`cycleRepeat`, the system route picker) that used to
    // live in the transport block and the old footer respectively. Matching
    // the design's placement was the ask, not deleting what it does not
    // draw, so both join this row rather than losing their only home. Four
    // real controls no longer fit the design's fixed 56pt gap, so this
    // distributes them evenly instead (NP-8: two rows below the transport —
    // volume, then this — where the app drew three).
    //
    // "Up next · N" is gone: the queue icon alone is the design's queue
    // affordance, and the count was the app's own addition on top of it.
    private var bottomActionRow: some View {
        HStack {
            Spacer()
            IconButton(
                systemName: HumIcon.queue,
                size: 21,
                tint: Palette.textPrimary.opacity(0.66),
                label: "Show queue",
                action: onQueue
            )
            Spacer()
            ShuffleButton()
            Spacer()
            RepeatButton()
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
                        .foregroundStyle(Palette.textMuted)
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
    let track: HumTrack
    let onClose: () -> Void

    @Environment(PlayerViewModel.self) private var player

    var body: some View {
        HStack {
            IconButton(
                systemName: HumIcon.collapse,
                size: 22,
                weight: .regular,
                // `rgba(255,255,255,.7)` — 4 points brighter than
                // `Palette.textSecondary`'s 66%. One-off rather than a new
                // ramp step for a difference this small (NP-9).
                tint: Color.white.opacity(0.7),
                label: "Close player",
                action: onClose
            )
            Spacer()
            Text(player.sourceLabel)
                .humFont(HumTextStyle(size: 11.5, relativeTo: .caption2, tracking: 1.6, uppercase: true))
                .foregroundStyle(Palette.textMuted)
                .lineLimit(1)
            Spacer()
            // The design's trailing header control is an overflow glyph, not
            // the queue shortcut this used to be — queue now lives in the
            // bottom action row below, where the design actually draws it
            // (NP-6). Add to Library moves here from the title row for the
            // same reason: the design keeps that row to title and artist
            // alone (NP-2). `DetailView` already puts secondary actions
            // behind this glyph, so this follows the app's own precedent
            // rather than inventing a new one.
            overflowMenu
        }
        // `8px 24px 0` (screen 23) — its own inset rather than the shared
        // `Metrics.navGutter` (18), which `ConnectView` and
        // `SubscriptionGapView` also read; widening it there was never asked
        // for (NP-4).
        .padding(.top, 8)
        .padding(.horizontal, 24)
    }

    private var overflowMenu: some View {
        let added = player.isInLibrary(track)
        return Menu {
            Button(
                added ? "In Your Library" : "Add to Library",
                systemImage: added ? HumIcon.inLibrary : HumIcon.addToLibrary
            ) {
                player.addToLibrary(track)
            }
            .disabled(added)
        } label: {
            Image(systemName: HumIcon.overflow)
                .humFont(21, weight: .regular)
                .foregroundStyle(Palette.textSecondary)
                .frame(width: Metrics.tapTarget, height: Metrics.tapTarget)
                .contentShape(.rect)
        }
        .accessibilityLabel("More options")
    }
}

/// The design's progress track: a ring wrapped around the artwork disc.
///
/// Measured off screen 23 — a 3pt circle of radius 152 inside a 322pt box,
/// starting at twelve o'clock, with a 13pt amber knob riding the head. The
/// artwork disc sits in the middle, which is why this takes the disc as
/// content rather than drawing beside it.
///
/// Seeking is a standard first-party MusicKit control
/// (`ApplicationMusicPlayer.playbackTime`) and is user-initiated, so it sits
/// inside the compliance rule even though the brief's shorthand names only
/// play/pause/skip (DECISIONS M-08).
private struct ProgressRing<Content: View>: View {
    @Environment(PlayerViewModel.self) private var player
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ViewBuilder var content: Content

    @State private var dragFraction: Double?
    /// True once a drag has started *on the ring*. Without this the gesture
    /// would also claim touches on the artwork in the middle, and tapping the
    /// album art would seek.
    @State private var isScrubbing = false

    private var fraction: Double { dragFraction ?? player.progress }
    private var radius: CGFloat { Metrics.artNowPlayingRing / 2 }

    var body: some View {
        ZStack {
            content

            Circle()
                // Same value as the hardcoded white 9% this replaces
                // (`Palette.hairlineStrong`) — the number was already right,
                // it just bypassed the token (NP-10).
                .stroke(Palette.hairlineStrong, lineWidth: Metrics.progressRingWidth)
                .frame(width: Metrics.artNowPlayingRing, height: Metrics.artNowPlayingRing)

            Circle()
                .trim(from: 0, to: fraction)
                .stroke(
                    Palette.honeyAmber,
                    style: StrokeStyle(lineWidth: Metrics.progressRingWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .frame(width: Metrics.artNowPlayingRing, height: Metrics.artNowPlayingRing)
                // Animate the arc only. Animating the stack drags the knob's
                // position and the timecodes along with it.
                .animation(reduceMotion ? nil : .linear(duration: 0.25), value: fraction)

            Circle()
                .fill(Palette.honeyAmber)
                .frame(width: Metrics.progressKnob, height: Metrics.progressKnob)
                // `0 0 14px 3px rgba(232,163,61,.7)` — a flat amber dot before
                // this (NP-3). CSS blur halves into a SwiftUI radius, the same
                // conversion used throughout this file; the 3px spread has no
                // SwiftUI equivalent and is folded into the radius instead.
                .shadow(color: Palette.honeyAmber.opacity(0.7), radius: 8.5)
                .offset(knobOffset)
        }
        .frame(width: Metrics.artNowPlaying, height: Metrics.artNowPlaying)
        .contentShape(.rect)
        .gesture(scrub)
        .accessibilityElement(children: .contain)
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

    private var knobOffset: CGSize {
        let angle = fraction * 2 * .pi - .pi / 2
        return CGSize(width: radius * cos(angle), height: radius * sin(angle))
    }

    /// A rotational drag: the angle from the centre *is* the position.
    private var scrub: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let centre = Metrics.artNowPlaying / 2
                let dx = value.location.x - centre
                let dy = value.location.y - centre
                if !isScrubbing {
                    // Engage only on the ring band, so the artwork stays inert.
                    let distance = sqrt(dx * dx + dy * dy)
                    guard abs(distance - radius) < 34 else { return }
                    isScrubbing = true
                }
                var angle = atan2(dy, dx) + .pi / 2
                if angle < 0 { angle += 2 * .pi }
                dragFraction = angle / (2 * .pi)
            }
            .onEnded { _ in
                if isScrubbing, let target = dragFraction { player.seek(toFraction: target) }
                isScrubbing = false
                dragFraction = nil
            }
    }
}

/// Design screen 24's buffering state — `humSpin`, a partial amber ring
/// spinning continuously, in place of `ProgressRing`'s position-based arc.
/// Not seekable: buffering has no position to scrub to yet.
private struct BufferingRing<Content: View>: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ViewBuilder var content: Content

    @State private var isSpinning = false

    var body: some View {
        ZStack {
            content

            Circle()
                .trim(from: 0, to: 0.7)
                .stroke(Palette.honeyAmber, style: StrokeStyle(lineWidth: Metrics.progressRingWidth, lineCap: .round))
                .frame(width: Metrics.artNowPlayingRing, height: Metrics.artNowPlayingRing)
                .rotationEffect(.degrees(isSpinning ? 360 : 0))
                .animation(
                    reduceMotion ? nil : .linear(duration: 1.1).repeatForever(autoreverses: false),
                    value: isSpinning
                )
                .onAppear { isSpinning = true }
        }
        .frame(width: Metrics.artNowPlaying, height: Metrics.artNowPlaying)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Buffering")
    }
}

/// Elapsed and remaining, flanking the hero. The ring carries the position, so
/// these are labels only — the adjustable action lives on the ring.
private struct TimecodeRow: View {
    @Environment(PlayerViewModel.self) private var player

    var body: some View {
        HStack {
            Text(player.elapsed.humTimestamp)
            Spacer()
            Text(player.remaining.humRemaining)
        }
        .humFont(HumTextStyle.timecode.size(12))
        .foregroundStyle(Palette.textMuted)
        // Screen 23 insets this row 46pt, 12 more than the 34pt
        // `Metrics.heroGutter` the surrounding block already applies to
        // everything else in it (NP-5) — this row's own extra margin, not a
        // change to that shared gutter.
        .padding(.horizontal, 12)
        .accessibilityHidden(true)
    }
}

/// The system volume slider, flanked by the design's two speaker glyphs.
///
/// The icons are decoration — `MPVolumeView` carries its own accessibility, so
/// labelling them again would give VoiceOver three stops for one control.
private struct VolumeRow: View {
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: HumIcon.volumeLow)
                .font(.system(size: 16))
            VolumeSlider()
            Image(systemName: HumIcon.volumeHigh)
                .font(.system(size: 18))
        }
        .foregroundStyle(Palette.iconInactive)
        .accessibilityHidden(false)
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
            .foregroundStyle(Palette.textMuted)
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
    /// Landscape has no separate bottom action row to hold shuffle and
    /// repeat, so it still gets them here, directly under the transport row.
    /// Portrait does have one now (`bottomActionRow`, screen 23's actual
    /// placement for shuffle) and passes `false` so they are not drawn twice.
    var showsSecondaryControls: Bool = true

    @Environment(PlayerViewModel.self) private var player

    var body: some View {
        // Measured from the design: three controls only — previous, play,
        // next — 26pt glyphs either side of a 78pt disc, 34 apart and centred.
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

            if showsSecondaryControls {
                HStack(spacing: 56) {
                    ShuffleButton()
                    RepeatButton()
                }
            }
        }
        .frame(maxWidth: alignment == .leading ? nil : .infinity)
    }

    private var playButton: some View {
        Button(action: player.togglePlayPause) {
            Image(systemName: player.isPlaying ? HumIcon.pause : HumIcon.play)
                .humFont(27, weight: .regular)
                // Onyx on amber, as the design draws it. White here measured
                // 2.16:1 — under the 3:1 floor for graphical objects, on the
                // primary control of the app's centrepiece. Onyx is 9.18:1.
                // `AlbumActionButton` already reads this way on the same fill.
                .foregroundStyle(Palette.deepOnyx)
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

/// 21pt, white at 66% until active, then amber — the design's secondary
/// weight. Its own type so both `TransportControls` (landscape) and the
/// portrait `bottomActionRow` can place it without duplicating the toggle.
private struct ShuffleButton: View {
    @Environment(PlayerViewModel.self) private var player

    var body: some View {
        IconButton(
            systemName: HumIcon.shuffle,
            size: 21,
            tint: player.queue.shuffleEnabled
                ? Palette.honeyAmber
                : Palette.textPrimary.opacity(0.66),
            label: player.queue.shuffleEnabled ? "Shuffle on" : "Shuffle off",
            action: player.toggleShuffle
        )
    }
}

/// Not in the design (screen 23 draws shuffle only), but real and tested —
/// see `bottomActionRow`'s comment for why it still gets a home.
private struct RepeatButton: View {
    @Environment(PlayerViewModel.self) private var player

    var body: some View {
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

    private var repeatLabel: String {
        switch player.queue.repeatMode {
        case .off: "Repeat off"
        case .all: "Repeat all"
        case .one: "Repeat one"
        }
    }
}
