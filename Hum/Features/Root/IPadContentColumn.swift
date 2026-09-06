import SwiftUI

/// Routes a sidebar destination to the middle column's content. Every case
/// reuses the exact production view/view model already screen-audited on
/// iPhone (`HomeView`, `LibraryView`, `DetailView`, `SearchView`) — Board 03
/// calls these six distinct compositions, and the iPhone views already are
/// that: adaptive grids and gutter-based padding, not a fixed phone width.
struct IPadContentColumn: View {
    let destination: IPadSidebarDestination
    @Binding var searchQuery: String

    @Environment(PlayerViewModel.self) private var player

    var body: some View {
        Group {
            switch destination {
            case .recentlyPlayed:
                // Board 03's own measurement: "Listen Now" is a two-column
                // composition (a "Start here" hero beside a resume list),
                // not iPhone's single-column shelf-then-list Home. See
                // `IPadListenNowView`'s doc comment for what backs the list
                // rows instead of the board's unbacked "12 min left" text.
                IPadListenNowView()

            case .artists:
                LibraryView(initialFilter: .artists, embedsNavigationChrome: false)
            case .albums:
                LibraryView(initialFilter: .albums, embedsNavigationChrome: false)

            case .recentlyAdded, .songs:
                // Board 03 revision item 12: neither destination has a
                // confirmed backing query in `MusicLibraryService` yet — no
                // "recently added" endpoint, and no flat song list distinct
                // from a playlist/album's own track list. Flagged pending a
                // capability check rather than wired to a guess.
                IPadPendingDestinationView(title: pendingTitle)

            case .madeForYou:
                IPadMadeForYouView()

            case .search:
                SearchView(query: $searchQuery, embedsNavigationChrome: false)

            case .playlist(let collection):
                // No `NavigationStack` wrapper here — `DetailView`'s own doc
                // comment is explicit that it has none of its own and must
                // extend its caller's, the same ambient stack every other
                // case in this switch already renders into. Wrapping it in a
                // second, nested stack (as this used to) gave it its own
                // isolated navigation/layout context instead, which is what
                // was cutting its content off under the sidebar — the width
                // every sibling case gets for free never reached this one.
                DetailView(collection: collection)
            }
        }
        .background(Palette.deepOnyx)
        // Board 03 revision item 8: the toast anchors to the middle column
        // only, not the full window width — the sidebar and player column
        // are never what a toast is confirming or apologizing for.
        .overlay(alignment: .bottom) {
            if let toast = player.toast {
                ToastView(toast: toast)
                    .padding(.bottom, 20)
                    .transition(.opacity.combined(with: .offset(y: 8)))
            }
        }
        .animation(.easeOut(duration: 0.2), value: player.toast)
    }

    private var pendingTitle: String {
        if case .recentlyAdded = destination { return "Recently added" }
        return "Songs"
    }
}

/// Board 03 revision items 10/12's "flag, don't silently resolve" treatment,
/// generalised: a destination whose data source isn't confirmed yet renders
/// as an honest placeholder instead of guessing at a query or crashing.
private struct IPadPendingDestinationView: View {
    let title: String

    var body: some View {
        EmptyStateView(
            icon: HumIcon.musicNote,
            headline: title,
            message: "This view has no confirmed Apple Music query yet — pending a MusicLibraryService capability check, not shipped."
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Board 03's "Made for you" sidebar destination — the same catalog
/// recommendations `HomeView`'s own "Made for you" row shows, promoted to a
/// full column here since iPad has room to give it its own destination
/// rather than folding it into "Listen Now".
private struct IPadMadeForYouView: View {
    @Environment(\.appEnvironment) private var environment
    @Environment(PlayerViewModel.self) private var player
    @State private var model: HomeViewModel?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                SectionHeader(title: "Made for you")
                    .padding(.horizontal, Metrics.gutter)
                    .padding(.top, 20)
                    .padding(.bottom, 12)

                switch model?.recommendations ?? .idle {
                case .idle, .loading:
                    RowSkeleton(count: 6).padding(.horizontal, Metrics.gutter)

                case .loaded(let tracks) where tracks.isEmpty:
                    EmptyStateView(
                        icon: HumIcon.musicNote,
                        headline: "No recommendations yet",
                        message: "Listen to a few things and Apple Music will start suggesting more."
                    )

                case .loaded(let tracks):
                    LazyVStack(spacing: 0) {
                        ForEach(Array(tracks.enumerated()), id: \.offset) { index, track in
                            TrackRow(track: track, isCurrent: player.currentTrack?.id == track.id) {
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
        .background(Palette.deepOnyx)
        .task {
            if model == nil { model = HomeViewModel(environment: environment) }
            await model?.load()
        }
    }
}
