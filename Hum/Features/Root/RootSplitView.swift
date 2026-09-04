import SwiftUI

/// Board 03, Section 01 — "iPad, Library, three columns". The phone's tab
/// dock unfolds sideways into a sidebar; the phone's Detail screen becomes
/// the middle column; Now Playing lives permanently in the right column
/// (`NowPlayingColumnView`) instead of rising as a sheet. Reuses the exact
/// view models and states already screen-audited on iPhone (`HomeViewModel`,
/// `LibraryView`, `DetailView`, `SearchView`) rather than redrawing six
/// screens from scratch — every one of them already has its own loading,
/// empty and error state at this content width.
struct RootSplitView: View {
    @Environment(\.appEnvironment) private var environment
    @Environment(PlayerViewModel.self) private var player
    @State private var selection: IPadSidebarDestination? = .recentlyPlayed
    @State private var searchQuery = ""
    @State private var isPresentingNewPlaylist = false
    @State private var library = SidebarLibraryModel()

    var body: some View {
        NavigationSplitView(columnVisibility: .constant(.all)) {
            IPadSidebar(
                selection: $selection,
                library: library,
                onNewPlaylist: { isPresentingNewPlaylist = true }
            )
            .navigationSplitViewColumnWidth(Metrics.iPadSidebarWidth)
        } content: {
            IPadContentColumn(destination: selection ?? .recentlyPlayed, searchQuery: $searchQuery)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        IPadSearchField(query: $searchQuery) { selection = .search }
                    }
                }
        } detail: {
            NowPlayingColumnView()
                .navigationSplitViewColumnWidth(Metrics.iPadPlayerColumnWidth)
                .toolbar(.hidden, for: .navigationBar)
        }
        .navigationSplitViewStyle(.balanced)
        .tint(Palette.honeyAmber)
        .task { await library.load(environment: environment) }
        .sheet(isPresented: $isPresentingNewPlaylist) {
            NewPlaylistView { newPlaylist in
                Task { await library.load(environment: environment, force: true) }
                selection = .playlist(newPlaylist)
            }
        }
        // Board 03's keyboard row: ⌘F focuses search, space toggles
        // play/pause, ⌥→ skips next. ⌘⌥U is left unbound — the player column
        // is permanent and never hidden on iPad, so there's no "show queue"
        // state for it to toggle the way iPhone's sheet has one.
        .installHiddenShortcut("f", modifiers: .command) { selection = .search }
        .installHiddenShortcut(.space, modifiers: []) { player.togglePlayPause() }
        .installHiddenShortcut(.rightArrow, modifiers: .option) { player.skipToNext() }
    }
}

// MARK: - Sidebar destinations

enum IPadSidebarDestination: Hashable {
    case recentlyPlayed
    case recentlyAdded
    case artists
    case albums
    case songs
    case madeForYou
    case search
    case playlist(HumCollection)
}

// MARK: - Sidebar

private struct IPadSidebar: View {
    @Binding var selection: IPadSidebarDestination?
    let library: SidebarLibraryModel
    let onNewPlaylist: () -> Void

    var body: some View {
        List(selection: $selection) {
            Section {
                row("Recently played", icon: "clock", .recentlyPlayed)
                row("Recently added", icon: "plus", .recentlyAdded)
                row("Artists", icon: "person", .artists)
                row("Albums", icon: "square.stack", .albums)
                row("Songs", icon: "music.note", .songs)
                row("Made for you", icon: "star", .madeForYou)
            }

            Section("Playlists") {
                ForEach(library.playlists) { playlist in
                    row(playlist.title, icon: "music.note.list", .playlist(playlist))
                }
                Button(action: onNewPlaylist) {
                    Label("New playlist", systemImage: "plus.circle")
                }
                .foregroundStyle(Palette.honeyAmber)
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .top) {
            HStack(spacing: 10) {
                HumMark().frame(width: 26, height: 26)
                Text("hum,").humFont(.wordmark).foregroundStyle(Palette.honeyAmber)
                Spacer()
            }
            .padding(.horizontal, 18)
            .padding(.top, 10)
            .padding(.bottom, 4)
        }
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Palette.honeyAmber.opacity(0.8))
                Text("Apple Music · Connected")
                    .humFont(12)
                    .foregroundStyle(Palette.textMuted)
                Spacer()
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
        }
        .background(Palette.contentSurfaceIPad)
        .scrollContentBackground(.hidden)
    }

    private func row(_ title: String, icon: String, _ destination: IPadSidebarDestination) -> some View {
        Label(title, systemImage: icon).tag(destination)
    }
}

private struct IPadSearchField: View {
    @Binding var query: String
    let onFocus: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: HumIcon.search).foregroundStyle(Palette.textMuted)
            TextField("Search your library", text: $query)
                .textFieldStyle(.plain)
                .onSubmit(onFocus)
        }
        .padding(.horizontal, 12)
        .frame(height: 36, alignment: .center)
        .frame(minWidth: 260)
        .chromeGlass(in: RoundedRectangle(cornerRadius: 10, style: .continuous), tint: nil)
    }
}

/// Loads just the Playlists list for the sidebar — the same
/// `MusicLibraryService.playlists()` call `LibraryViewModel` makes, kept
/// separate because the sidebar needs it before any content-column selection
/// has run its own view model.
@MainActor
@Observable
final class SidebarLibraryModel {
    private(set) var playlists: [HumCollection] = []

    func load(environment: AppEnvironment, force: Bool = false) async {
        guard force || playlists.isEmpty else { return }
        playlists = (try? await environment.library.playlists()) ?? []
    }
}

// MARK: - Keyboard shortcut helper

private extension View {
    /// A key command with no visible control — `Button.keyboardShortcut`
    /// still needs a real button to hang off, so this hides one behind the
    /// content rather than adding a second `View.keyboardShortcut` overload
    /// that would collide with SwiftUI's own.
    func installHiddenShortcut(_ key: KeyEquivalent, modifiers: EventModifiers, action: @escaping () -> Void) -> some View {
        background {
            Button("", action: action)
                .keyboardShortcut(key, modifiers: modifiers)
                .opacity(0)
                .accessibilityHidden(true)
        }
    }
}
