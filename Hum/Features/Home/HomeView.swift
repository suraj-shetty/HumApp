import SwiftUI

/// Home. **Opaque content throughout** — no glass anywhere on this screen.
struct HomeView: View {
    @Environment(\.appEnvironment) private var environment
    @Environment(PlayerViewModel.self) private var player
    @State private var model: HomeViewModel?
    @State private var route: HumCollection?

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    header
                    if model?.needsSubscription == true {
                        catalogUnavailable
                    } else {
                        shelf
                        madeForYou
                    }
                }
            }
            .scrollIndicators(.hidden)
            .background(Palette.deepOnyx)
            .navigationDestination(item: $route) { collection in
                DetailView(collection: collection)
            }
            .task {
                if model == nil { model = HomeViewModel(environment: environment) }
                await model?.load()
            }
            .refreshable { await model?.reload() }
        }
    }

    // MARK: - Header

    private var header: some View {
        // The design's Home header is the greeting alone, 32/200 in white,
        // beside the profile control — no wordmark and no overline. The
        // wordmark belongs to Connect, splash and onboarding, where the design
        // does use it.
        HStack(alignment: .center) {
            Text(model?.greeting ?? "")
                .font(.system(size: 32, weight: .ultraLight))
                .kerning(-0.8)
                .foregroundStyle(Palette.textPrimary)
            Spacer()
            NavigationLink {
                SettingsView()
            } label: {
                Image(systemName: HumIcon.person)
                    .font(.system(size: 20, weight: .light))
                    .foregroundStyle(Palette.textSecondary)
                    .frame(width: Metrics.tapTarget, height: Metrics.tapTarget)
                    .background(Palette.surfaceRaised, in: Circle())
            }
            .accessibilityLabel("Settings")
        }
        .padding(.horizontal, Metrics.gutter)
        .padding(.top, 14)
        .padding(.bottom, 22)
    }

    /// Both shelves come from Apple Music's personalized catalog, so with no
    /// subscription there is nothing to put in them. Stated plainly and once,
    /// rather than as two "couldn't load" rows above an empty screen — and
    /// pointing at the Library, which works perfectly well without one.
    ///
    /// Deliberately not a sales pitch: Hum gates nothing of its own and takes
    /// nothing from a signup. Apple's own offer sheet is already where a play
    /// intent goes when it needs a membership.
    private var catalogUnavailable: some View {
        EmptyStateView(
            icon: HumIcon.musicNote,
            headline: "Nothing to suggest yet",
            message: "Recently played and Made for you come from Apple Music, which this account isn't subscribed to. Everything in your library still plays — it's in the Library tab."
        )
        .padding(.top, 40)
    }

    // MARK: - Recently played

    @ViewBuilder
    private var shelf: some View {
        SectionHeader(title: "Recently played")
            .padding(.horizontal, Metrics.gutter)
            .padding(.bottom, 10)

        switch model?.recentlyPlayed ?? .idle {
        case .idle, .loading:
            ShelfSkeleton()

        case .loaded(let collections) where collections.isEmpty:
            EmptyStateView(
                icon: HumIcon.musicNote,
                headline: "Nothing here yet",
                message: "Albums and playlists you listen to will show up here."
            )

        case .loaded(let collections):
            ScrollView(.horizontal) {
                // Lazy so a large recently-played list doesn't build every
                // card up front.
                LazyHStack(spacing: Metrics.rowSpacing) {
                    ForEach(collections) { collection in
                        Button { route = collection } label: {
                            ShelfCard(collection: collection)
                        }
                        .buttonStyle(.pressable)
                    }
                }
                .padding(.horizontal, Metrics.gutter)
                .padding(.vertical, 6)
            }
            .scrollIndicators(.hidden)
            .padding(.bottom, 20)

        case .failed(let message):
            InlineError(message: message)
        }
    }

    // MARK: - Made for you

    @ViewBuilder
    private var madeForYou: some View {
        SectionHeader(title: "Made for you")
            .padding(.horizontal, Metrics.gutter)
            .padding(.bottom, 8)

        switch model?.recommendations ?? .idle {
        case .idle, .loading:
            RowSkeleton(count: 4)
                .padding(.horizontal, Metrics.gutter)

        case .loaded(let tracks) where tracks.isEmpty:
            EmptyStateView(
                icon: HumIcon.musicNote,
                headline: "No recommendations yet",
                message: "Listen to a few things and Apple Music will start suggesting more."
            )

        case .loaded(let tracks):
            LazyVStack(spacing: 0) {
                // Identified by position, not by track id: a real playlist can hold
                // the same song twice, and duplicate SwiftUI identities make
                // rows drop out and taps land on the wrong one.
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
            .padding(.horizontal, Metrics.gutter)

        case .failed(let message):
            InlineError(message: message)
        }
    }
}

// MARK: - Pieces

/// A collection card — 160 art, title, amber subtitle.
///
/// Shared with Library, whose grid draws the same card in the design. It was
/// duplicated inline there, which is how the two drifted apart: the copy kept a
/// 14.5 title and a grey subtitle after this one was corrected.
struct ShelfCard: View {
    let collection: HumCollection

    var body: some View {
        // Measured: 160 art at radius 10, a 10pt gap to the caption, then the
        // title and subtitle 4 apart — 208 tall in total. The caption pair is
        // its own stack because the two gaps differ.
        VStack(alignment: .leading, spacing: 10) {
            ArtworkView(
                url: collection.artworkURL,
                size: Metrics.artShelf,
                cornerRadius: Metrics.radiusArt,
                label: collection.title
            )
            VStack(alignment: .leading, spacing: 4) {
                Text(collection.title)
                    .font(.system(size: 15))
                    .foregroundStyle(Palette.textPrimary)
                    .lineLimit(1)
                Text(collection.subtitle)
                    .font(.system(size: 13))
                    // Amber at 80%, the same treatment the row artist carries.
                    .foregroundStyle(Palette.honeyAmber.opacity(0.8))
                    .lineLimit(1)
            }
        }
        .frame(width: Metrics.artShelf, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(collection.title), \(collection.subtitle)")
    }
}

/// Loading placeholders that match the final layout's geometry, so content
/// arriving does not reflow the page.
struct ShelfSkeleton: View {
    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: Metrics.rowSpacing) {
                ForEach(0..<3, id: \.self) { _ in
                    VStack(alignment: .leading, spacing: 10) {
                        RoundedRectangle(cornerRadius: Metrics.radiusArt, style: .continuous)
                            .fill(Palette.artworkFill)
                            .frame(width: Metrics.artShelf, height: Metrics.artShelf)
                        Capsule().fill(Palette.artworkFill).frame(width: 110, height: 11)
                        Capsule().fill(Palette.artworkFill).frame(width: 72, height: 10)
                    }
                }
            }
            .padding(.horizontal, Metrics.gutter)
            .padding(.vertical, 6)
        }
        .scrollIndicators(.hidden)
        .disabled(true)
        .padding(.bottom, 20)
        .accessibilityLabel("Loading")
    }
}

struct RowSkeleton: View {
    var count: Int = 4

    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<count, id: \.self) { _ in
                HStack(spacing: Metrics.rowSpacing) {
                    RoundedRectangle(cornerRadius: Metrics.radiusArt, style: .continuous)
                        .fill(Palette.artworkFill)
                        .frame(width: Metrics.artRow, height: Metrics.artRow)
                    VStack(alignment: .leading, spacing: 6) {
                        Capsule().fill(Palette.artworkFill).frame(width: 150, height: 11)
                        Capsule().fill(Palette.artworkFill).frame(width: 90, height: 10)
                    }
                    Spacer()
                }
                .padding(.vertical, Metrics.rowPaddingCompact)
            }
        }
        .accessibilityLabel("Loading")
    }
}

struct InlineError: View {
    let message: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: HumIcon.warning)
                // Terracotta, not amber. Amber means "yes" everywhere else in
                // this app; an error drawn in it reads as an invitation.
                .foregroundStyle(Palette.terracottaLift)
            Text(message)
                .font(HumFont.rowSubtitle)
                .foregroundStyle(Palette.textSecondary)
        }
        .padding(.horizontal, Metrics.gutter)
        .padding(.vertical, 18)
    }
}
