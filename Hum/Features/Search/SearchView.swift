import Observation
import SwiftUI

@MainActor
@Observable
final class SearchViewModel {
    var term: String = ""
    private(set) var results: LoadState<HumSearchResults> = .idle
    private(set) var recentSearches = RecentSearches.load()
    /// `MusicCatalogSearchRequest` searches Apple's catalog only — the same
    /// personalized-catalog category Home's shelves are gated on — so this
    /// needs the same subscription check Home already has; without it, a
    /// non-subscriber's search failure rendered as a generic "check your
    /// connection", blaming the network for a subscription gap.
    private(set) var needsSubscription = false

    private let catalog: MusicCatalogService
    private let subscriptionStore: SubscriptionStateStore
    private var searchTask: Task<Void, Never>?

    init(environment: AppEnvironment) {
        self.catalog = environment.catalog
        self.subscriptionStore = environment.subscriptionStore
    }

    /// Debounced. Every keystroke firing a catalog request would burn the
    /// network and race its own results back out of order; 300ms is the usual
    /// balance between feeling instant and not thrashing.
    func search() {
        searchTask?.cancel()
        let query = term.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !query.isEmpty else {
            results = .idle
            needsSubscription = false
            return
        }

        searchTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(300))
            guard let self, !Task.isCancelled else { return }
            results = .loading

            switch SubscriptionReducer.resolveBrowse(in: subscriptionStore.current) {
            case .needsSubscription:
                needsSubscription = true
                results = .loaded(.empty)
                return
            case .checkFailed:
                needsSubscription = false
                results = .failed("Couldn't check your Apple Music subscription.")
                return
            case .browse:
                needsSubscription = false
            }

            do {
                let found: HumSearchResults = try await catalog.search(query)
                // Cancellation is checked again after the await: the term may
                // have changed while the request was in flight, and a stale
                // result overwriting a newer one is the classic search bug.
                guard !Task.isCancelled else { return }
                results = .loaded(found)
                // Recorded on a completed fetch, not every keystroke — a
                // recent search should be something the listener actually
                // searched for, not whatever the debounce happened to catch.
                recentSearches.record(query)
            } catch {
                guard !Task.isCancelled else { return }
                results = .failed("Search failed. Check your connection.")
            }
        }
    }

    func removeRecentSearch(_ term: String) {
        recentSearches.remove(term)
    }

    func clearRecentSearches() {
        recentSearches.clear()
    }
}

/// Design screen 33's "Recent searches" list — up to 8 terms, most recent
/// first, persisted locally (`Privacy` settings names this explicitly:
/// "Stored locally, never sent anywhere").
struct RecentSearches: Equatable {
    private(set) var terms: [String]

    private static let key = "HumRecentSearches"
    private static let limit = 8

    static func load() -> RecentSearches {
        RecentSearches(terms: UserDefaults.standard.stringArray(forKey: key) ?? [])
    }

    /// Settings → Privacy's "Clear local data" (design screen 41). A plain
    /// static write rather than requiring a loaded instance — Settings has
    /// no reason to hold a live `RecentSearches` of its own just to empty it.
    static func clearAll() {
        UserDefaults.standard.removeObject(forKey: key)
    }

    mutating func record(_ term: String) {
        terms.removeAll { $0.caseInsensitiveCompare(term) == .orderedSame }
        terms.insert(term, at: 0)
        if terms.count > Self.limit { terms.removeLast(terms.count - Self.limit) }
        persist()
    }

    mutating func remove(_ term: String) {
        terms.removeAll { $0 == term }
        persist()
    }

    mutating func clear() {
        terms = []
        persist()
    }

    private func persist() {
        UserDefaults.standard.set(terms, forKey: Self.key)
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
    @State private var filter: ResultFilter = .all
    @State private var route: HumCollection?
    /// See `HomeView.embedsNavigationChrome` — same fix, for the same reason:
    /// nesting a second `NavigationStack` inside iPad's content column drew a
    /// second, mostly-empty nav bar under the split view's own (which carries
    /// the always-visible search field). `IPadContentColumn` passes `false`.
    var embedsNavigationChrome: Bool = true

    /// Design screen 13's chip row — reuses `Metrics.chip*`/`Palette.chip*`,
    /// the same tokens Library's own chips already draw from (M-4).
    enum ResultFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case songs = "Songs"
        case albums = "Albums"
        var id: String { rawValue }
    }

    var body: some View {
        results
            .navigationRoot(providesOwnChrome: embedsNavigationChrome, hidesNavigationBar: false)
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

    private var results: some View {
            Group {
                if model?.needsSubscription == true {
                    // Same reasoning as `HomeView.catalogUnavailable`: Search
                    // draws entirely from the Apple Music catalog, so a
                    // confirmed non-subscriber gets a plain explanation, not
                    // "No results" (which reads as the search itself failing).
                    EmptyStateView(
                        icon: HumIcon.musicNote,
                        headline: "Apple Music Needed",
                        message: "Search draws from the Apple Music catalog, which this account isn't subscribed to. Your library still plays — it's in the Library tab."
                    )
                } else {
                switch model?.results ?? .idle {
                case .idle:
                    ScrollView {
                        VStack(alignment: .leading, spacing: 28) {
                            if let model, !model.recentSearches.terms.isEmpty {
                                // Design screen 33 draws recents in place of
                                // the Browse grid, under the keyboard, while
                                // the field is focused. This app's field
                                // lives in the chrome rather than the
                                // content (M-2's own departure), so there's
                                // no separate "focused" content state to key
                                // off — recents sit above Browse instead of
                                // replacing it, honest about what's actually
                                // reachable here rather than simulating a
                                // focus state that doesn't exist.
                                RecentSearchesView(
                                    terms: model.recentSearches.terms,
                                    onSelect: { query = $0 },
                                    onRemove: { model.removeRecentSearch($0) },
                                    onClear: { model.clearRecentSearches() }
                                )
                            }
                            BrowseGridView { genre in
                                query = genre
                            }
                        }
                        .padding(.top, 8)
                    }
                    .scrollIndicators(.hidden)

                case .loading:
                    RowSkeleton(count: 6)
                        .padding(.horizontal, Metrics.gutter)
                        .frame(maxHeight: .infinity, alignment: .top)

                case .loaded(let found) where found.isEmpty:
                    EmptyStateView(
                        icon: HumIcon.search,
                        headline: "No results",
                        message: "Nothing matched that search. Try a different spelling."
                    )

                case .loaded(let found):
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0, pinnedViews: .sectionHeaders) {
                            // Design 13's chip row. Chips filter which of the
                            // two sections below are shown; they don't
                            // re-query — both lists are already in `found`.
                            HStack(spacing: Metrics.chipSpacing) {
                                ForEach(ResultFilter.allCases) { item in
                                    FilterChip(title: item.rawValue, isSelected: filter == item) {
                                        filter = item
                                    }
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(.bottom, 16)

                            if filter != .albums, !found.tracks.isEmpty {
                                // Identified by position, not by track id: results
                                // can repeat a song, and duplicate SwiftUI
                                // identities make rows drop out and taps land on
                                // the wrong one.
                                Section {
                                    ForEach(Array(found.tracks.enumerated()), id: \.offset) { index, track in
                                        TrackRow(
                                            track: track,
                                            isCurrent: player.currentTrack?.id == track.id
                                        ) {
                                            player.play(found.tracks, startingAt: index, source: "Search")
                                        }
                                        if index < found.tracks.count - 1 { RowDivider() }
                                    }
                                } header: {
                                    SearchSectionHeader(title: "Top Results")
                                }
                            }

                            if filter != .songs, !found.albums.isEmpty {
                                Section {
                                    ScrollView(.horizontal) {
                                        LazyHStack(spacing: Metrics.rowSpacing) {
                                            ForEach(found.albums) { album in
                                                Button { route = album } label: {
                                                    ShelfCard(collection: album)
                                                }
                                                .buttonStyle(.pressable)
                                            }
                                        }
                                        .padding(.vertical, 6)
                                    }
                                    .scrollIndicators(.hidden)
                                } header: {
                                    SearchSectionHeader(title: "Albums")
                                        .padding(.top, found.tracks.isEmpty || filter == .albums ? 0 : 12)
                                }
                            }
                        }
                        .padding(.horizontal, Metrics.gutter)
                    }
                    .scrollIndicators(.hidden)

                case .failed(let message):
                    // Design screen 15 — the same shape `EmptyStateView`
                    // stands in for elsewhere, tinted for an error (it used
                    // to be `SearchErrorView`, its own redraw of the same
                    // composition).
                    EmptyStateView(
                        icon: HumIcon.warning,
                        headline: "Search can't reach the catalog",
                        message: message,
                        actionTitle: "Try again",
                        action: { model?.search() },
                        tint: Palette.terracotta,
                        iconTint: Palette.terracottaLift
                    )
                    .padding(.horizontal, 46)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                }
                }
            }
            .navigationDestination(item: $route) { DetailView(collection: $0) }
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
}

/// Design 13's small uppercase section label — "TOP RESULTS" / "ALBUMS" —
/// pinned to the top of its `Section` while that group scrolls (M-4).
private struct SearchSectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .humFont(11.5, weight: .semibold)
            .tracking(1.2)
            .textCase(.uppercase)
            .foregroundStyle(Palette.textMuted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8)
            .background(Palette.deepOnyx)
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
    }
}

/// Design screen 33's "Recent searches" — up to 8 terms, a clock glyph per
/// row, a trailing ✕ to drop one, and a "Clear" to drop them all.
private struct RecentSearchesView: View {
    let terms: [String]
    let onSelect: (String) -> Void
    let onRemove: (String) -> Void
    let onClear: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Recent Searches")
                    .humFont(.groupLabel)
                    .foregroundStyle(Palette.textMuted)
                Spacer()
                Button("Clear", action: onClear)
                    .buttonStyle(.plain)
                    .humFont(14)
                    .foregroundStyle(Palette.honeyAmber)
            }
            .padding(.horizontal, Metrics.gutter)
            .padding(.bottom, 10)

            ForEach(terms, id: \.self) { term in
                Button { onSelect(term) } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "clock")
                            .humFont(15, weight: .regular)
                            .foregroundStyle(Palette.textMuted)
                        Text(term)
                            .humFont(16)
                            .foregroundStyle(Palette.textPrimary)
                        Spacer()
                        Button {
                            onRemove(term)
                        } label: {
                            Image(systemName: "xmark")
                                .humFont(13, weight: .regular)
                                .foregroundStyle(Palette.textMuted)
                                .frame(width: Metrics.tapTarget, height: Metrics.tapTarget)
                                .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Remove \(term)")
                    }
                    .frame(height: 52)
                    .padding(.horizontal, Metrics.gutter)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

