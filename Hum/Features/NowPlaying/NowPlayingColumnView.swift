import SwiftUI

/// Board 03's permanent right column — Now Playing and Up Next merged into
/// one non-modal surface, replacing both the iPhone `.fullScreenCover` and the
/// mini capsule for the iPad path only. **Opaque content**, `Metrics.iPadPlayerColumnWidth`
/// wide, same `PlayerViewModel` singleton as everything else — this is a
/// second view onto the existing session, not a parallel one.
///
/// Board 03's spec comment on this column also flags two states iPhone
/// answers with a `.fullScreenCover`/`.sheet` that a permanent column can't
/// use the same way: buffering and connection-lost get in-column treatments
/// below. Apple's own subscription-offer sheet and `SubscriptionGapView`
/// still present as sheets here — both are already app-modal system/account
/// flows independent of which column triggered them, so there's no in-column
/// equivalent to draw that wouldn't just be a narrower duplicate.
struct NowPlayingColumnView: View {
    @Environment(PlayerViewModel.self) private var player

    var body: some View {
        ZStack {
            Palette.contentSurfaceIPad.ignoresSafeArea()

            if player.isShowingConnectionLost {
                connectionLost
            } else if let track = player.currentTrack {
                VStack(spacing: 0) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 22) {
                            Text("Now Playing")
                                .humFont(.groupLabel)
                                .foregroundStyle(Palette.textMuted)
                            hero(track)
                            titleBlock(track)
                            if player.isBuffering {
                                Text("Buffering")
                                    .humFont(HumTextStyle(size: 11.5, relativeTo: .caption, tracking: 1.4, uppercase: true))
                                    .foregroundStyle(Palette.honeyAmber.opacity(0.85))
                            }
                            ProgressScrubber()
                            TransportControls(size: Metrics.transportPrimaryCompact, showsSecondaryControls: true)
                        }
                        .padding(.horizontal, 26)
                        .padding(.top, 28)
                        .opacity(player.isBuffering ? 0.55 : 1)
                        .disabled(player.isBuffering)

                        RowDivider().padding(.top, 26)

                        upNext
                    }
                }
            } else {
                EmptyStateView(
                    icon: HumIcon.musicNote,
                    headline: "Nothing playing",
                    message: "Pick something from your library or search the catalog."
                )
            }
        }
        .frame(width: Metrics.iPadPlayerColumnWidth)
    }

    // MARK: - Hero

    private func hero(_ track: HumTrack) -> some View {
        Group {
            if player.isBuffering {
                BufferingRing { artwork(track) }
            } else {
                artwork(track)
                    .shadow(color: Palette.honeyAmber.opacity(0.18), radius: 20)
            }
        }
    }

    /// Full column width, not a fixed thumbnail size — the board's own
    /// measurement runs the hero art edge-to-edge with the 26pt gutter on
    /// both sides (288pt at this column's 340pt width), not a smaller
    /// centered square.
    private var heroSize: CGFloat { Metrics.iPadPlayerColumnWidth - 52 }

    private func artwork(_ track: HumTrack) -> some View {
        ArtworkView(
            url: track.artworkURL,
            size: heroSize,
            cornerRadius: Metrics.radiusArt,
            label: track.albumTitle ?? track.title
        )
    }

    /// Left-aligned, title/artist/badge stacked under the art with the
    /// library toggle beside them — not centered text with a text-label
    /// library button underneath. Matches the board's own layout
    /// measurement: title, artist and badge all share the art's left edge,
    /// and "Add to Library" is a plain 44pt circle icon at the block's
    /// trailing edge, the same plus/checkmark glyph the iPhone overflow
    /// menu already uses (`HumIcon.addToLibrary`/`.inLibrary`), not a
    /// second, iPad-only icon.
    private func titleBlock(_ track: HumTrack) -> some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 6) {
                Text(track.title)
                    .humFont(HumTextStyle(size: 20, weight: .light, relativeTo: .title3, tracking: -0.3))
                    .foregroundStyle(Palette.textPrimary)
                    .lineLimit(1)
                Text(track.artist)
                    .humFont(15)
                    .foregroundStyle(Palette.honeyAmber)
                    .lineLimit(1)
                AudioVariantBadge(variant: player.audioVariant)
            }
            Spacer(minLength: 8)
            libraryButton(track)
        }
    }

    private func libraryButton(_ track: HumTrack) -> some View {
        let added = player.isInLibrary(track)
        return Button {
            player.addToLibrary(track)
        } label: {
            Image(systemName: added ? HumIcon.inLibrary : HumIcon.addToLibrary)
                .humFont(21, weight: .regular)
                .foregroundStyle(added ? Palette.textMuted : Palette.textSecondary)
                .frame(width: 44, height: 44)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(added)
        .accessibilityLabel(added ? "In Your Library" : "Add to Library")
    }

    // MARK: - Up Next

    private var upNext: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Up Next")
                    .humFont(.groupLabel)
                    .foregroundStyle(Palette.textMuted)
                Spacer()
                Button("Clear") { player.clearUpNext() }
                    .buttonStyle(.plain)
                    .humFont(13)
                    .foregroundStyle(player.upNext.isEmpty ? Palette.textDisabled : Palette.honeyAmber)
                    .disabled(player.upNext.isEmpty)
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 10)

            if player.upNext.isEmpty {
                EmptyStateView(
                    icon: HumIcon.library,
                    headline: "Nothing after this one",
                    message: "When this track ends, playback stops."
                )
                .padding(.horizontal, 12)
            } else {
                let base = (player.queue.currentIndex ?? -1) + 1
                LazyVStack(spacing: 0) {
                    ForEach(Array(player.upNext.enumerated()), id: \.offset) { offset, track in
                        let index = base + offset
                        TrackRow(track: track) { player.jump(to: index) }
                        if offset < player.upNext.count - 1 { RowDivider() }
                    }
                }
                .padding(.horizontal, 22)
            }
        }
        .padding(.bottom, 30)
    }

    // MARK: - Connection lost

    /// A compact, in-column version of `ConnectionLostView`'s double-ring
    /// halo — the full-screen cover doesn't fit a column that's always
    /// visible beside two other columns (Board 03 revision item 6).
    private var connectionLost: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle().strokeBorder(Palette.terracotta.opacity(0.38), lineWidth: 1).frame(width: 84, height: 84)
                Circle().strokeBorder(Palette.terracotta.opacity(0.22), lineWidth: 1).frame(width: 58, height: 58)
                HumMark(color: Palette.terracottaLift).frame(width: 30, height: 30)
            }
            Text("Playback stopped")
                .humFont(HumTextStyle(size: 18, weight: .light, relativeTo: .title3))
                .foregroundStyle(Palette.textPrimary)
            Text("Hum lost its connection to Apple Music. Your queue is intact.")
                .humFont(13, weight: .light)
                .lineSpacing(3)
                .multilineTextAlignment(.center)
                .foregroundStyle(Palette.textSecondary)
                .frame(maxWidth: 260)
            AmberOutlineButton(title: "Try Again", height: 40) {
                player.retryConnectionLost?()
                player.isShowingConnectionLost = false
            }
        }
        .padding(.horizontal, 26)
        .accessibilityElement(children: .combine)
    }
}
