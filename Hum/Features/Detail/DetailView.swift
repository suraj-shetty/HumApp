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
            VStack(alignment: .leading, spacing: 20) {
                ArtworkView(
                    url: collection.artworkURL,
                    size: Metrics.artDetailHero,
                    cornerRadius: Metrics.radiusArtMedium,
                    label: collection.title
                )
                .frame(maxWidth: .infinity)
                .shadow(color: .black.opacity(0.6), radius: 30, y: 20)

                metadata
                actions
                trackList
            }
            .padding(.horizontal, Metrics.gutter)
        }
        .scrollIndicators(.hidden)
        .background(Palette.deepOnyx)
        .navigationTitle(collection.title)
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

    private var metadata: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(collection.title)
                .humTitle(size: 27, weight: .light, tracking: -0.5)
                .foregroundStyle(Palette.textPrimary)

            if !collection.subtitle.isEmpty {
                Text(collection.subtitle)
                    .font(.system(size: 16))
                    .foregroundStyle(Palette.honeyAmber)
            }

            Text(collection.metaLine)
                .overline(size: 12.5, tracking: 1.2)
                .foregroundStyle(Palette.textQuaternary)
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var actions: some View {
        if let tracks = model?.tracks.value, !tracks.isEmpty {
            HStack(spacing: 12) {
                AmberCapsuleButton(title: "Play", systemImage: HumIcon.play, height: 50) {
                    play(tracks, at: 0)
                }
                if model?.showsShuffle == true {
                    NeutralCapsuleButton(title: "Shuffle", systemImage: HumIcon.shuffle) {
                        shuffle(tracks)
                    }
                }
            }
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
