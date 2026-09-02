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
/// Designed by inference (DECISIONS M-06) — built from the prototype's shelf
/// card, laid out as a grid.
struct LibraryView: View {
    @Environment(\.appEnvironment) private var environment
    @State private var model: LibraryViewModel?
    @State private var route: HumCollection?

    private let columns = [
        GridItem(.adaptive(minimum: 148), spacing: Metrics.rowSpacing)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 22) {
                    section(title: "Albums", state: model?.albums ?? .idle)
                    section(title: "Playlists", state: model?.playlists ?? .idle)
                }
                .padding(.horizontal, Metrics.gutter)
                .padding(.top, 8)
            }
            .scrollIndicators(.hidden)
            .background(Palette.deepOnyx)
            .navigationTitle("Library")
            .navigationDestination(item: $route) { DetailView(collection: $0) }
            .task {
                if model == nil { model = LibraryViewModel(environment: environment) }
                await model?.load()
            }
            .refreshable { await model?.reload() }
        }
    }

    @ViewBuilder
    private func section(title: String, state: LoadState<[HumCollection]>) -> some View {
        Section {
            switch state {
            case .idle, .loading:
                ForEach(0..<2, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: Metrics.radiusArt, style: .continuous)
                        .fill(Palette.artworkFill)
                        .frame(height: Metrics.artShelf)
                }

            case .loaded(let collections) where collections.isEmpty:
                Text("Nothing here yet.")
                    .font(HumFont.rowSubtitle)
                    .foregroundStyle(Palette.textTertiary)

            case .loaded(let collections):
                ForEach(collections) { collection in
                    Button { route = collection } label: {
                        VStack(alignment: .leading, spacing: 10) {
                            ArtworkView(
                                url: collection.artworkURL,
                                size: Metrics.artShelf,
                                label: collection.title
                            )
                            Text(collection.title)
                                .font(.system(size: 14.5))
                                .foregroundStyle(Palette.textPrimary)
                                .lineLimit(1)
                            Text(collection.subtitle)
                                .font(.system(size: 13))
                                .foregroundStyle(Palette.textTertiary)
                                .lineLimit(1)
                        }
                    }
                    .buttonStyle(.pressable)
                }

            case .failed(let message):
                InlineError(message: message)
            }
        } header: {
            SectionHeader(title: title)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
