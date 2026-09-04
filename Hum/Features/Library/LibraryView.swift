import Observation
import SwiftUI

@MainActor
@Observable
final class LibraryViewModel {
    private(set) var albums: LoadState<[HumCollection]> = .idle
    private(set) var playlists: LoadState<[HumCollection]> = .idle
    private(set) var artists: LoadState<[HumCollection]> = .idle

    private let library: MusicLibraryService

    init(environment: AppEnvironment) {
        self.library = environment.library
    }

    func load() async {
        guard case .idle = albums else { return }
        albums = .loading
        playlists = .loading
        artists = .loading

        async let albumsResult = library.albums()
        async let playlistsResult = library.playlists()
        async let artistsResult = library.artists()

        do { albums = .loaded(try await albumsResult) }
        catch { albums = .failed("Couldn't load your albums.") }

        do { playlists = .loaded(try await playlistsResult) }
        catch { playlists = .failed("Couldn't load your playlists.") }

        do { artists = .loaded(try await artistsResult) }
        catch { artists = .failed("Couldn't load your artists.") }
    }

    func reload() async {
        albums = .idle
        await load()
    }
}

/// Library. **Opaque content.**
///
/// The design's Library is a 32/200 screen header, a row of filter chips, and
/// one grid of whatever the selected chip names — not the stacked "Albums" and
/// "Playlists" sections this carried before, and not a system large title.
///
/// **One of the design's four chips is still missing**: Liked, along with the
/// pinned "Liked Songs" row above the grid. MusicKit exposes no love/favorite
/// API to back either one (DECISIONS M-04, same gap `MusicLibraryService.add`
/// already documents) — left open rather than wired to a capability that
/// doesn't exist. Artists is built: `MusicLibraryRequest<Artist>` is real
/// (M-6).
struct LibraryView: View {
    @Environment(\.appEnvironment) private var environment
    @State private var model: LibraryViewModel?
    @State private var route: HumCollection?
    @State private var filter: Filter
    /// iPad's sidebar (`RootSplitView`) pushes straight to one filter — the
    /// "Artists"/"Albums" destinations are this same grid, preselected,
    /// rather than a second implementation (Board 03's "Grid" composition).
    init(initialFilter: Filter = .playlists) {
        _filter = State(initialValue: initialFilter)
    }

    enum Filter: String, CaseIterable, Identifiable {
        case playlists = "Playlists"
        case albums = "Albums"
        case artists = "Artists"
        var id: String { rawValue }
    }

    // Two columns of the design's 160pt card, 22 between them. Adaptive so the
    // grid still reads on a wider screen; the minimum is the design's width.
    private let columns = [
        GridItem(.adaptive(minimum: Metrics.artShelf), spacing: Metrics.libraryGridColumnSpacing)
    ]

    private var state: LoadState<[HumCollection]> {
        switch filter {
        case .playlists: model?.playlists ?? .idle
        case .albums: model?.albums ?? .idle
        case .artists: model?.artists ?? .idle
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header
                    chips
                    grid
                }
            }
            .scrollIndicators(.hidden)
            .background(Palette.deepOnyx)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(item: $route) { DetailView(collection: $0) }
            .task {
                if model == nil { model = LibraryViewModel(environment: environment) }
                await model?.load()
            }
            .refreshable { await model?.reload() }
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            Text("Library")
                .humFont(.screenTitle)
                .foregroundStyle(Palette.textPrimary)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            NavigationLink {
                SettingsView()
            } label: {
                Image(systemName: HumIcon.person)
                    .humFont(20, weight: .light)
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

    private var chips: some View {
        HStack(spacing: Metrics.chipSpacing) {
            ForEach(Filter.allCases) { item in
                FilterChip(title: item.rawValue, isSelected: filter == item) {
                    filter = item
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Metrics.gutter)
        .padding(.bottom, 20)
    }

    @ViewBuilder
    private var grid: some View {
        switch state {
        case .idle, .loading:
            LazyVGrid(columns: columns, spacing: Metrics.libraryGridSpacing) {
                ForEach(0..<4, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: Metrics.radiusArt, style: .continuous)
                        .fill(Palette.artworkFill)
                        .frame(height: Metrics.artShelf)
                }
            }
            .padding(.horizontal, Metrics.gutter)

        case .loaded(let collections) where collections.isEmpty:
            Text("Nothing here yet.")
                .humFont(.rowSubtitle)
                .foregroundStyle(Palette.textMuted)
                .padding(.horizontal, Metrics.gutter)

        case .loaded(let collections):
            LazyVGrid(columns: columns, spacing: Metrics.libraryGridSpacing) {
                ForEach(collections) { collection in
                    Button { route = collection } label: {
                        ShelfCard(collection: collection)
                    }
                    .buttonStyle(.pressable)
                }
            }
            .padding(.horizontal, Metrics.gutter)

        case .failed(let message):
            // Design screen 18.
            LibrarySyncErrorView(message: message) {
                Task { await model?.reload() }
            }
            .padding(.horizontal, Metrics.gutter)
        }
    }
}

/// Design screen 18. The design shows this as a card sitting above a *stale*
/// grid, dimmed but still visible — "This is the copy from 2 hours ago."
/// This app fetches fresh every time and keeps no prior copy to fall back
/// to, so there's nothing to show dimmed underneath; the card fills the
/// space alone instead of implying a cache that doesn't exist. Pull-to-
/// refresh (`.refreshable` on the screen) already answers "pull down to try
/// again" for real.
private struct LibrarySyncErrorView: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: HumIcon.warning)
                    .humFont(18, weight: .regular)
                    .foregroundStyle(Palette.terracottaLift)
                Text("Library is out of date")
                    .humFont(16)
                    .foregroundStyle(Palette.textPrimary)
            }
            Text(message)
                .humFont(14.5, weight: .light)
                .lineSpacing(3)
                .foregroundStyle(Palette.textSecondary)
            AmberOutlineButton(title: "Retry sync", height: 44, action: onRetry)
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.surfaceCard, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Palette.terracotta.opacity(0.3), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }
}

/// The design's filter chip: 38pt tall, radius 19. Selected carries an amber
/// 16% fill and a 1px amber 45% border — which is what makes it measure 40pt
/// against the others' 38. Unselected is a flat `#161618` with no border.
///
/// Not private: Search's own result-type chips (M-4) draw from the same
/// design spec and reuse this rather than a second copy.
struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .humFont(HumTextStyle(size: 13.5, relativeTo: .subheadline))
                .foregroundStyle(isSelected ? Palette.honeyAmber : Palette.textSecondary.opacity(0.9))
                .padding(.horizontal, 18)
                .frame(height: Metrics.chipHeight)
                .background {
                    let shape = RoundedRectangle(cornerRadius: Metrics.chipRadius, style: .continuous)
                    if isSelected {
                        shape.fill(Palette.chipSelectedFill)
                            .overlay(shape.strokeBorder(Palette.chipSelectedStroke, lineWidth: 1))
                    } else {
                        shape.fill(Palette.chipFill)
                    }
                }
                // The handoff's 3pt slop top and bottom: a 38pt chip still
                // ships a 44pt target.
                .contentShape(.rect)
                .frame(height: Metrics.tapTarget)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}
