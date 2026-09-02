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

/// Search. **Opaque content.** The tab itself is `Tab(role: .search)`, so the
/// system renders the chrome.
///
/// Designed by inference — the prototype has a Search tab but draws no screen
/// (DECISIONS M-06). Built to the Home/track-row idiom.
struct SearchView: View {
    @Environment(\.appEnvironment) private var environment
    @Environment(PlayerViewModel.self) private var player
    @State private var model: SearchViewModel?

    var body: some View {
        NavigationStack {
            Group {
                switch model?.results ?? .idle {
                case .idle:
                    EmptyStateView(
                        icon: HumIcon.search,
                        headline: "Search Apple Music",
                        message: "Find songs, albums, and artists from the catalog and your library."
                    )

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
                        LazyVStack(spacing: 0) {
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
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
        }
        .searchable(
            text: Binding(
                get: { model?.term ?? "" },
                set: { model?.term = $0 }
            ),
            prompt: "Songs, albums, artists"
        )
        .onSubmit(of: .search) { model?.search() }
        .onChange(of: model?.term ?? "") { _, _ in model?.search() }
        .task {
            if model == nil { model = SearchViewModel(environment: environment) }
        }
    }
}
