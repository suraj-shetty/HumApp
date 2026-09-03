import Observation
import SwiftUI

@MainActor
@Observable
final class SearchViewModel {
    var term: String = ""
    private(set) var results: LoadState<[HumTrack]> = .idle

    private let catalog: MusicCatalogService
    private var searchTask: Task<Void, Never>?

    init(environment: AppEnvironment) {
        self.catalog = environment.catalog
    }

    /// Debounced. Every keystroke firing a catalog request would burn the
    /// network and race its own results back out of order; 300ms is the usual
    /// balance between feeling instant and not thrashing.
    func search() {
        searchTask?.cancel()
        let query = term.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !query.isEmpty else {
            results = .idle
            return
        }

        searchTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(300))
            guard let self, !Task.isCancelled else { return }
            results = .loading
            do {
                let found = try await catalog.search(query)
                // Cancellation is checked again after the await: the term may
                // have changed while the request was in flight, and a stale
                // result overwriting a newer one is the classic search bug.
                guard !Task.isCancelled else { return }
                results = .loaded(found)
            } catch {
                guard !Task.isCancelled else { return }
                results = .failed("Search failed. Check your connection.")
            }
        }
    }
}

/// Search. **Opaque content.**
///
/// This screen no longer owns its search field. The field is in the bottom
/// chrome, which is where the search tab expands to on iOS 26 — so the query
/// arrives as a binding from `RootTabView` and this view only answers it.
///
/// That also settles a divergence the audit raised: `.searchable` put the
/// system field *above* the 32/200 display title, inverting the design's
/// order. With the field in the chrome, the title is back on top.
///
/// The design draws its search field at the top of the screen rather than in
/// the dock (screens 12–14, 33). Moving it to the chrome is a deliberate
/// departure, and it is the behaviour `DESIGN_SYSTEM.md` originally specified
/// via `Tab(role: .search)` before D-10 hand-built the bar.
struct SearchView: View {
    @Binding var query: String

    @Environment(\.appEnvironment) private var environment
    @Environment(PlayerViewModel.self) private var player
    @State private var model: SearchViewModel?

    var body: some View {
        NavigationStack {
            Group {
                switch model?.results ?? .idle {
                case .idle:
                    BrowseGridView { genre in
                        query = genre
                    }

                case .loading:
                    RowSkeleton(count: 6)
                        .padding(.horizontal, Metrics.gutter)
                        .frame(maxHeight: .infinity, alignment: .top)

                case .loaded(let tracks) where tracks.isEmpty:
                    EmptyStateView(
                        icon: HumIcon.search,
                        headline: "No results",
                        message: "Nothing matched that search. Try a different spelling."
                    )

                case .loaded(let tracks):
                    ScrollView {
                        LazyVStack(spacing: 0, pinnedViews: .sectionHeaders) {
                            // Design 13 also draws an "ALBUMS" section — this
                            // app's catalog search returns tracks only, so
                            // there is no second group to head. "TOP RESULTS"
                            // is the one label that's true regardless.
                            Section {
                                // Identified by position, not by track id: results
                                // can repeat a song, and duplicate SwiftUI
                                // identities make rows drop out and taps land on
                                // the wrong one.
                                ForEach(Array(tracks.enumerated()), id: \.offset) { index, track in
                                    TrackRow(
                                        track: track,
                                        isCurrent: player.currentTrack?.id == track.id
                                    ) {
                                        player.play(tracks, startingAt: index, source: "Search")
                                    }
                                    if index < tracks.count - 1 { RowDivider() }
                                }
                            } header: {
                                Text("Top Results")
                                    .humFont(11.5, weight: .semibold)
                                    .tracking(1.2)
                                    .textCase(.uppercase)
                                    .foregroundStyle(Palette.textMuted)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, 8)
                                    .background(Palette.deepOnyx)
                            }
                        }
                        .padding(.horizontal, Metrics.gutter)
                    }
                    .scrollIndicators(.hidden)

                case .failed(let message):
                    EmptyStateView(
                        icon: HumIcon.warning,
                        headline: "Something went wrong",
                        message: message,
                        actionTitle: "Try again",
                        action: { model?.search() }
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Palette.deepOnyx)
            .safeAreaInset(edge: .top, spacing: 0) {
                // The design gives Search the same 32/200 display title Home
                // carries, in the content rather than the nav bar.
                Text("Search")
                    .humFont(.screenTitle)
                    .foregroundStyle(Palette.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Metrics.gutter)
                    .padding(.bottom, 12)
                    .background(Palette.deepOnyx)
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onChange(of: query) { _, term in
            model?.term = term
            model?.search()
        }
        .task {
            if model == nil { model = SearchViewModel(environment: environment) }
            // The tab can be entered with a query already typed — the field is
            // in the chrome and outlives this view's lifetime.
            if !query.isEmpty, model?.term != query {
                model?.term = query
                model?.search()
            }
        }
    }
}

/// Search's default, no-query state — design screen 12's "Browse" grid,
/// finding M-3. It was a plain magnifier-and-caption empty state; the design
/// gives Search a real entry point instead of asking for a query first.
///
/// Genre in, search term out: tapping a tile searches its name. There's no
/// separate genre-browse endpoint in `MusicCatalogService` to page through
/// instead, and a tile that led nowhere would be worse than none.
private struct BrowseGridView: View {
    let onSelect: (String) -> Void

    private let genres: [(name: String, fill: Color)] = [
        ("Ambient", Palette.browseAmbient),
        ("Jazz", Palette.browseJazz),
        ("Classical", Palette.browseClassical),
        ("Folk", Palette.browseFolk),
        ("Electronic", Palette.browseElectronic),
        ("Soul", Palette.browseSoul),
    ]

    private let columns = [
        GridItem(.flexible(), spacing: Metrics.browseGridSpacing),
        GridItem(.flexible(), spacing: Metrics.browseGridSpacing),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Browse")
                    .humFont(20, weight: .light)
                    .foregroundStyle(Palette.textPrimary)

                LazyVGrid(columns: columns, spacing: Metrics.browseGridSpacing) {
                    ForEach(genres, id: \.name) { genre in
                        Button {
                            onSelect(genre.name)
                        } label: {
                            Text(genre.name)
                                .humFont(16, weight: .light)
                                .foregroundStyle(Palette.textPrimary)
                                .frame(maxWidth: .infinity, alignment: .bottomLeading)
                                .padding(14)
                                .frame(height: Metrics.browseTileHeight)
                                .background(genre.fill, in: RoundedRectangle(cornerRadius: Metrics.browseTileRadius))
                        }
                        .buttonStyle(.pressable)
                    }
                }
            }
            .padding(.horizontal, Metrics.gutter)
            .padding(.top, 8)
        }
        .scrollIndicators(.hidden)
    }
}
