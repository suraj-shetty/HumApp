import SwiftUI

/// Album, playlist, and artist detail — one screen, three headers.
/// **Opaque content throughout.**
struct DetailView: View {
    let collection: HumCollection

    @Environment(\.appEnvironment) private var environment
    @Environment(PlayerViewModel.self) private var player
    @Environment(\.dismiss) private var dismiss
    @State private var model: DetailViewModel?

    var body: some View {
        ScrollView {
            // The hero block's 16pt gap. The design measures the artwork at 206
            // square, inset and centred — not full-bleed, which is what this
            // screen drew and what the comment here used to claim was measured.
            // Only Artist detail runs a hero edge to edge, and that screen does
            // not exist yet.
            VStack(spacing: 16) {
                ArtworkView(
                    url: collection.artworkURL,
                    size: Metrics.artDetailHero,
                    cornerRadius: Metrics.radiusArtHero,
                    label: collection.title
                )
                // `0 18px 44px rgba(0,0,0,.6)`. CSS blur halves into a SwiftUI
                // radius, the same conversion `AmberGlassModifier` uses.
                .shadow(color: .black.opacity(0.6), radius: 22, y: 18)
                .padding(.top, 26)

                VStack(spacing: 20) {
                    metadata
                    actions
                    trackList
                }
                .padding(.horizontal, Metrics.gutter)
            }
        }
        .scrollIndicators(.hidden)
        .background(Palette.deepOnyx)
        // No nav-bar title: the design's detail screen carries the title once,
        // in the header below. With real Apple Music titles — long, and often
        // suffixed " - Single" — a truncated nav copy read as repetition.
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    if let tracks = model?.tracks.value, !tracks.isEmpty {
                        Button("Play", systemImage: HumIcon.play) { play(tracks, at: 0) }
                        Button("Shuffle", systemImage: HumIcon.shuffle) { shuffle(tracks) }
                    }
                } label: {
                    Image(systemName: HumIcon.overflow)
                }
                .accessibilityLabel("More options")
            }
        }
        .task {
            if model == nil {
                model = DetailViewModel(collection: collection, environment: environment)
            }
            await model?.load()
        }
    }

    // MARK: - Header

    /// Centred, per the design — the build had it leading-aligned.
    private var metadata: some View {
        VStack(spacing: 6) {
            Text(collection.title)
                .humFont(HumTextStyle(size: 26, weight: .light, relativeTo: .title, tracking: -0.4))
                .foregroundStyle(Palette.textPrimary)
                .multilineTextAlignment(.center)

            if !collection.subtitle.isEmpty {
                // 15px, not 16 (m-15).
                Text(collection.subtitle)
                    .humFont(15)
                    .foregroundStyle(Palette.textPrimary.opacity(0.82))
                    .multilineTextAlignment(.center)
            }

            // 13 / 400 in amber at 80% — not a tracked uppercase overline.
            // Was 14 (m-15).
            Text(collection.metaLine)
                .humFont(13)
                .foregroundStyle(Palette.honeyAmber.opacity(0.8))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var actions: some View {
        if let tracks = model?.tracks.value, !tracks.isEmpty {
            // Measured: a compact solid-amber Play with a Deep Onyx label —
            // dark on amber, not white on a translucent wash — beside an
            // outlined Shuffle in amber. Centred, sized to their content.
            HStack(spacing: 12) {
                DetailActionButton(
                    title: "Play",
                    systemImage: HumIcon.play,
                    style: .filled
                ) { play(tracks, at: 0) }

                if model?.showsShuffle == true {
                    DetailActionButton(
                        title: "Shuffle",
                        systemImage: HumIcon.shuffle,
                        style: .outlined
                    ) { shuffle(tracks) }
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Tracks

    @ViewBuilder
    private var trackList: some View {
        switch model?.tracks ?? .idle {
        case .idle, .loading:
            RowSkeleton(count: 5)

        case .loaded(let tracks) where tracks.isEmpty:
            EmptyStateView(
                icon: HumIcon.musicNote,
                headline: "No tracks",
                message: "There's nothing to play here yet."
            )

        case .loaded(let tracks):
            LazyVStack(spacing: 0) {
                // Identified by position, not by track id: a real playlist can hold
                // the same song twice, and duplicate SwiftUI identities make
                // rows drop out and taps land on the wrong one.
                ForEach(Array(tracks.enumerated()), id: \.offset) { index, track in
                    TrackRow(
                        track: track,
                        leading: model?.usesTrackNumbers == true
                            ? .index(index + 1)
                            : .artwork,
                        isCurrent: player.currentTrack?.id == track.id
                    ) {
                        play(tracks, at: index)
                    }
                    if index < tracks.count - 1 { RowDivider() }
                }
            }

        case .failed(let message):
            InlineError(message: message)
        }
    }

    // MARK: - Intents

    private func play(_ tracks: [HumTrack], at index: Int) {
        player.play(tracks, startingAt: index, source: collection.title)
    }

    private func shuffle(_ tracks: [HumTrack]) {
        guard !tracks.isEmpty else { return }
        player.play(tracks, startingAt: Int.random(in: tracks.indices), source: collection.title)
        if !player.queue.shuffleEnabled { player.toggleShuffle() }
    }
}


/// The detail screen's Play and Shuffle, measured from the design.
///
/// Deliberately not `AmberCapsuleButton`: that is Connect's full-width capsule,
/// a translucent amber wash with a white label. The design's detail actions are
/// a different component — compact, solid amber with a **Deep Onyx** label, or
/// outlined in amber with an amber label.
private struct DetailActionButton: View {
    enum Style { case filled, outlined }

    let title: String
    let systemImage: String
    let style: Style
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: systemImage)
                    .humFont(15, weight: .regular)
                    .accessibilityHidden(true)
                Text(title)
                    .humFont(16, weight: style == .filled ? .medium : .regular)
            }
            .foregroundStyle(style == .filled ? Palette.deepOnyx : Palette.honeyAmber)
            // Play 30, Shuffle 26 — was 22 for both (m-2).
            .padding(.horizontal, style == .filled ? 30 : 26)
            // Both 48 — Shuffle was 50 (m-1).
            .frame(height: 48)
            .background {
                if style == .filled {
                    Capsule(style: .continuous).fill(Palette.honeyAmber)
                } else {
                    Capsule(style: .continuous)
                        .strokeBorder(Palette.honeyAmber.opacity(0.5), lineWidth: 1)
                }
            }
        }
        .buttonStyle(.pressable)
        .accessibilityLabel(title)
    }
}
