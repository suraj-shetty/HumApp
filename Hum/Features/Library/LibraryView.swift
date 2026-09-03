import Observation
import SwiftUI

@MainActor
@Observable
final class LibraryViewModel {
    private(set) var albums: LoadState<[HumCollection]> = .idle
    private(set) var playlists: LoadState<[HumCollection]> = .idle

    private let library: MusicLibraryService

    init(environment: AppEnvironment) {
        self.library = environment.library
    }

    func load() async {
        guard case .idle = albums else { return }
        albums = .loading
        playlists = .loading

        async let albumsResult = library.albums()
        async let playlistsResult = library.playlists()

        do { albums = .loaded(try await albumsResult) }
        catch { albums = .failed("Couldn't load your albums.") }

        do { playlists = .loaded(try await playlistsResult) }
        catch { playlists = .failed("Couldn't load your playlists.") }
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
/// **Two of the design's four chips are missing**: Artists and Liked, along
/// with the pinned "Liked Songs" row above the grid. `MusicLibraryService`
/// exposes albums and playlists only, so those three want new library queries
/// rather than a layout change — flagged rather than faked with empty states.
struct LibraryView: View {
    @Environment(\.appEnvironment) private var environment
    @State private var model: LibraryViewModel?
    @State private var route: HumCollection?
    @State private var filter: Filter = .playlists

    enum Filter: String, CaseIterable, Identifiable {
        case playlists = "Playlists"
        case albums = "Albums"
        var id: String { rawValue }
    }

    // Two columns of the design's 160pt card, 22 between them. Adaptive so the
    // grid still reads on a wider screen; the minimum is the design's width.
    private let columns = [
        GridItem(.adaptive(minimum: Metrics.artShelf), spacing: Metrics.libraryGridSpacing)
    ]

    private var state: LoadState<[HumCollection]> {
        switch filter {
        case .playlists: model?.playlists ?? .idle
        case .albums: model?.albums ?? .idle
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
            .navigationBarHidden(true)
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
        LazyVGrid(columns: columns, spacing: Metrics.libraryGridSpacing) {
            switch state {
            case .idle, .loading:
                ForEach(0..<4, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: Metrics.radiusArt, style: .continuous)
                        .fill(Palette.artworkFill)
                        .frame(height: Metrics.artShelf)
                }

            case .loaded(let collections) where collections.isEmpty:
                Text("Nothing here yet.")
                    .humFont(.rowSubtitle)
                    .foregroundStyle(Palette.textTertiary)

            case .loaded(let collections):
                ForEach(collections) { collection in
                    Button { route = collection } label: {
                        ShelfCard(collection: collection)
                    }
                    .buttonStyle(.pressable)
                }

            case .failed(let message):
                InlineError(message: message)
            }
        }
        .padding(.horizontal, Metrics.gutter)
    }
}

/// The design's filter chip: 38pt tall, radius 19. Selected carries an amber
/// 16% fill and a 1px amber 45% border — which is what makes it measure 40pt
/// against the others' 38. Unselected is a flat `#161618` with no border.
private struct FilterChip: View {
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
