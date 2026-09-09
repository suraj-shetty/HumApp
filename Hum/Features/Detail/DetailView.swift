import SwiftUI

/// Album, playlist, and artist detail — one screen, three headers.
/// **Opaque content throughout.**
struct DetailView: View {
    let collection: HumCollection

    @Environment(\.appEnvironment) private var environment
    @Environment(PlayerViewModel.self) private var player
    @Environment(\.dismiss) private var dismiss
    @State private var model: DetailViewModel?
    /// "Go to Artist" / "Go to Album" (design screen 31) push here. This
    /// view has no `NavigationStack` of its own — it's always pushed onto
    /// its caller's (Home's or Library's) — so declaring the destination
    /// here extends that same stack rather than starting a new one.
    @State private var route: HumCollection?

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
        .navigationDestination(item: $route) { DetailView(collection: $0) }
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
        if model?.needsSubscription == true {
            // Same reasoning as `HomeView`/`SearchView`: a confirmed
            // non-subscriber gets a plain explanation, not a load error.
            EmptyStateView(
                icon: HumIcon.musicNote,
                headline: "Apple Music Needed",
                message: "This is from the Apple Music catalog, which this account isn't subscribed to."
            )
        } else {
            switch model?.tracks ?? .idle {
            case .idle, .loading:
                RowSkeleton(count: 5)

            case .loaded(let tracks) where tracks.isEmpty:
                // Design screen 36. No "Add songs" action: that needs a
                // playlist-mutation capability `MusicLibraryService` doesn't
                // expose (the same gap recorded against M-6 and the track
                // context menu's missing "Add to Playlist…").
                EmptyPlaylistView(collection: collection)

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
                            isCurrent: player.currentTrack?.id == track.id,
                            action: { play(tracks, at: index) },
                            onGoToArtist: { goToArtist(for: $0) },
                            onGoToAlbum: collection.kind == .album ? nil : { goToAlbum(for: $0) }
                        )
                        if index < tracks.count - 1 { RowDivider() }
                    }
                }

            case .failed(let message):
                // Design screen 37 — the same shape `EmptyStateView` stands in
                // for elsewhere, tinted for an error and at Home's 112pt ring
                // rather than redrawn as its own view (it used to be
                // `DetailLoadErrorView`, byte-for-byte the same composition).
                EmptyStateView(
                    icon: "rectangle.slash",
                    headline: "This didn't load",
                    message: message,
                    actionTitle: "Reload",
                    action: { Task { await model?.retry() } },
                    tint: Palette.terracotta,
                    iconTint: Palette.terracottaLift,
                    ringDiameter: 112
                )
                .padding(.horizontal, 46)
                .padding(.top, 60)
                .padding(.bottom, Metrics.chromeClearance)
            }
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

    /// Real `MusicCatalogService` lookups, not a guess from `track.artist` /
    /// `track.albumTitle`'s display strings — `nil` for a library track
    /// (see the protocol doc), in which case this is a silent no-op rather
    /// than an error, matching how the menu items themselves only appear
    /// when a caller actually wired them.
    private func goToArtist(for track: HumTrack) {
        Task {
            if let artist = try? await environment.catalog.artist(for: track) {
                route = artist
            }
        }
    }

    private func goToAlbum(for track: HumTrack) {
        Task {
            if let album = try? await environment.catalog.album(for: track) {
                route = album
            }
        }
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

/// Design screen 36 — a playlist with no tracks. Distinct from the generic
/// "No tracks" `EmptyStateView` other screens use: this one names the
/// playlist and explains where songs would come from, not just that there
/// aren't any.
private struct EmptyPlaylistView: View {
    let collection: HumCollection

    var body: some View {
        VStack(spacing: 16) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(0.16), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                .background(Palette.surfaceCard, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .frame(width: 160, height: 160)
                .overlay {
                    Image(systemName: HumIcon.musicNote)
                        .humFont(38, weight: .light)
                        .foregroundStyle(Palette.honeyAmber.opacity(0.7))
                }

            VStack(spacing: 6) {
                Text(collection.title)
                    .humFont(22, weight: .light)
                    .foregroundStyle(Palette.textPrimary)
                Text("Your playlist · empty for now")
                    .humFont(13.5)
                    .foregroundStyle(Palette.honeyAmber.opacity(0.8))
            }

            Text("Songs you add from anywhere in Hum land here. Adding to this playlist also updates it in Apple Music.")
                .humFont(14.5, weight: .light)
                .lineSpacing(4)
                .multilineTextAlignment(.center)
                .foregroundStyle(Palette.textSecondary)
                .padding(.horizontal, 30)
                .padding(.top, 4)
        }
        .padding(.top, 26)
        // This state has too little else on the page to trip SwiftUI's own
        // chrome-clearance inset the way a full track list does — given
        // explicitly so the content isn't left sitting under the floating
        // tab bar.
        .padding(.bottom, Metrics.chromeClearance)
        .accessibilityElement(children: .combine)
    }
}

