import SwiftUI

/// Board 03's "Listen Now" — the iPad content column's `.recentlyPlayed`
/// destination. Not `HomeView` reused: the board measures a two-column top
/// section (a large "Start here" hero beside a "Pick up where you left off"
/// list) that iPhone's single-column shelf-then-list Home never draws.
///
/// The board's own list rows show a resume caption like "12 min left" —
/// `MusicCatalogService`/`HumCollection` has no per-item resume-position
/// data to back that honestly, so these rows show `subtitle`/`metaLine`
/// instead (the same real metadata `ShelfCard` already shows), not a
/// fabricated progress string. Everything below the two-column area reuses
/// the exact "Made for you" track list `HomeView` already has.
struct IPadListenNowView: View {
    @Environment(\.appEnvironment) private var environment
    @Environment(PlayerViewModel.self) private var player
    @State private var model: HomeViewModel?
    @State private var route: HumCollection?
    // The two-column row's actual available width, measured off a
    // `maxWidth: .infinity` container rather than guessed. `recentlyPlayed`
    // used to size the hero from a `GeometryReader`-measured width while its
    // own enclosing `.frame(height:)` was computed from a hardcoded 292pt
    // fallback — the two agreed only by coincidence at whatever width the
    // sidebar happened to leave. Collapsing the sidebar widens this column
    // well past 292pt, so the hero rendered taller than the frame reserved
    // for it and spilled into "Made for you" below. One measured value, used
    // for both the hero's width and the row's height, can't disagree with
    // itself the way two separate ones did.
    @State private var rowWidth: CGFloat = 460

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                recentlyPlayed
                madeForYou
            }
        }
        .scrollIndicators(.hidden)
        .background(Palette.deepOnyx)
        .navigationDestination(item: $route) { DetailView(collection: $0) }
        .task {
            if model == nil { model = HomeViewModel(environment: environment) }
            await model?.load()
        }
    }

    // MARK: - Header

    private var header: some View {
        ScreenHeader(title: model?.greeting ?? "", horizontalPadding: Metrics.iPadContentGutter)
    }

    // MARK: - Recently played (two-column)

    @ViewBuilder
    private var recentlyPlayed: some View {
        switch model?.recentlyPlayed ?? .idle {
        case .idle, .loading:
            ShelfSkeleton()

        case .loaded(let collections) where collections.isEmpty:
            if player.recentlyPlayedMaySyncSoon {
                EmptyStateView(
                    icon: HumIcon.musicNote,
                    headline: "Still syncing",
                    message: "Apple Music can take a few minutes to update your play history after you listen. Check back shortly."
                )
            } else {
                EmptyStateView(
                    icon: HumIcon.musicNote,
                    headline: "Nothing here yet",
                    message: "Albums and playlists you listen to will show up here."
                )
            }

        case .loaded(let collections):
            let heroW = heroWidth(for: rowWidth)
            HStack(alignment: .top, spacing: 22) {
                if let hero = collections.first {
                    Button { route = hero } label: {
                        ListenNowHeroCard(collection: hero, width: heroW)
                    }
                    .buttonStyle(.pressable)
                }
                if collections.count > 1 {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Pick up where you left off")
                            .humFont(.groupLabel)
                            .foregroundStyle(Palette.textMuted)
                            .padding(.bottom, 10)
                        ForEach(Array(collections.dropFirst().prefix(4))) { collection in
                            Button { route = collection } label: {
                                ListenNowResumeRow(collection: collection)
                            }
                            .buttonStyle(.pressable)
                        }
                        Spacer(minLength: 0)
                    }
                    .frame(width: listWidth)
                }
            }
            .frame(height: ListenNowHeroCard.height(for: heroW))
            .frame(maxWidth: .infinity, alignment: .leading)
            .onGeometryChange(for: CGFloat.self, of: \.size.width) { rowWidth = $0 }
            .padding(.horizontal, Metrics.iPadContentGutter)
            .padding(.bottom, 30)

        case .failed(let message):
            InlineError(message: message).padding(.horizontal, Metrics.iPadContentGutter)
        }
    }

    // Board 03's own measurement of the two-column row (528pt available at
    // the design's 1194pt frame): a 214.5pt resume list beside a 291.5pt
    // hero, 22pt apart — not the even split a naive halving would produce.
    private let listWidth: CGFloat = 215

    private func heroWidth(for availableWidth: CGFloat) -> CGFloat {
        max(160, availableWidth - listWidth - 22)
    }

    // MARK: - Made for you

    @ViewBuilder
    private var madeForYou: some View {
        SectionHeader(title: "Made for you")
            .padding(.horizontal, Metrics.iPadContentGutter)
            .padding(.bottom, 8)

        switch model?.recommendations ?? .idle {
        case .idle, .loading:
            RowSkeleton(count: 4)
                .padding(.horizontal, Metrics.iPadContentGutter)

        case .loaded(let tracks) where tracks.isEmpty:
            EmptyStateView(
                icon: HumIcon.musicNote,
                headline: "No recommendations yet",
                message: "Listen to a few things and Apple Music will start suggesting more."
            )

        case .loaded(let tracks):
            LazyVStack(spacing: 0) {
                ForEach(Array(tracks.enumerated()), id: \.offset) { index, track in
                    TrackRow(
                        track: track,
                        isCurrent: player.currentTrack?.id == track.id
                    ) {
                        player.play(tracks, startingAt: index, source: "Made for you")
                    }
                    if index < tracks.count - 1 { RowDivider() }
                }
            }
            .padding(.horizontal, Metrics.iPadContentGutter)

        case .failed(let message):
            InlineError(message: message).padding(.horizontal, Metrics.iPadContentGutter)
        }
    }
}

/// The "Start here" hero — art filling the card, a bottom scrim, and the
/// collection's own real metadata overlaid on it. No resume-position claim:
/// "Start here" just names it as the most recent thing played, which
/// `recentlyPlayed`'s own ordering already guarantees.
private struct ListenNowHeroCard: View {
    let collection: HumCollection
    let width: CGFloat

    /// Board 03 measures this plate at 291.5×272 at its own 1194pt frame —
    /// landscape, not the square every other art plate in this app uses.
    /// Derived from width so the card keeps that proportion at any column
    /// size instead of hard-coding a height that only matches at one width.
    private static let aspectRatio: CGFloat = 272.0 / 291.5

    static func height(for width: CGFloat) -> CGFloat { width * aspectRatio }

    private var height: CGFloat { Self.height(for: width) }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            ArtworkView(
                url: collection.artworkURL,
                size: width,
                height: height,
                cornerRadius: Metrics.radiusArt,
                label: collection.title
            )
            LinearGradient(
                colors: [.clear, Palette.deepOnyx.opacity(0.85)],
                startPoint: .center,
                endPoint: .bottom
            )
            .frame(width: width, height: height)
            .clipShape(RoundedRectangle(cornerRadius: Metrics.radiusArt, style: .continuous))
            .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 4) {
                Text("Start here")
                    .humFont(HumTextStyle(size: 11, relativeTo: .caption, tracking: 1.5, uppercase: true))
                    .foregroundStyle(Palette.honeyAmber)
                Text(collection.title)
                    .humFont(HumTextStyle(size: 18, weight: .light, relativeTo: .title3))
                    .foregroundStyle(Palette.textPrimary)
                    .lineLimit(1)
                Text(collection.subtitle.isEmpty ? collection.metaLine : "\(collection.subtitle) · \(collection.metaLine)")
                    .humFont(13)
                    .foregroundStyle(Palette.textSecondary)
                    .lineLimit(1)
            }
            .padding(16)
        }
        .frame(width: width, height: height)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Start here, \(collection.title), \(collection.subtitle)")
    }
}

/// A compact resume row — smaller than `TrackRow`, since this list sits
/// beside the hero rather than spanning the column.
private struct ListenNowResumeRow: View {
    let collection: HumCollection

    var body: some View {
        HStack(spacing: 10) {
            ArtworkView(
                url: collection.artworkURL,
                size: 44,
                cornerRadius: Metrics.radiusArtRow,
                label: collection.title
            )
            VStack(alignment: .leading, spacing: 2) {
                Text(collection.title)
                    .humFont(13.5)
                    .foregroundStyle(Palette.textPrimary)
                    .lineLimit(1)
                Text(collection.subtitle.isEmpty ? collection.metaLine : collection.subtitle)
                    .humFont(11.5)
                    .foregroundStyle(Palette.textMuted)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }
}
