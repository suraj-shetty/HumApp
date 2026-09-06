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
    // A real `@State`, not `.constant(.all)`: at 1194×834 landscape (the
    // board's own measurement) all three fixed-width columns fit and this
    // starts and stays `.all`. But `.constant` can never be written back to,
    // so at any width the system can't satisfy — portrait, a smaller iPad,
    // Split View multitasking — it was silently dropping the sidebar with no
    // toggle to bring it back, because there was nothing for the system to
    // write the collapse into. A mutable binding gets the sidebar's own
    // built-in reveal control back in that case.
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        @Bindable var bindable = player

        // Genuinely three columns in the design, but built as a *two*-column
        // `NavigationSplitView` (sidebar + detail) with the player column
        // folded into the detail side as a plain `HStack` sibling, not
        // NavigationSplitView's own third `detail:` slot. Measured against
        // the running app (not just read from the API): with all three
        // slots real NavigationSplitView columns, `.balanced` (and every
        // other built-in style) inserted two dead-black ~60-140pt gaps ­—
        // one between content and player, one after player to the trailing
        // edge — that no combination of `min`/`ideal`/`max` on any column
        // could close; the content column's own `ideal` was silently
        // ignored outright. A plain `HStack` has none of that arbitration to
        // get wrong. The only behaviour actually needed from
        // `NavigationSplitView` here is the sidebar's own collapse/reveal at
        // narrow widths (RootSplitView's own history: `.constant(.all)` used
        // to drop the sidebar with no way back) — a two-column split still
        // gives that, with content+player simply riding along as one unit.
        return NavigationSplitView(columnVisibility: $columnVisibility) {
            IPadSidebar(
                selection: $selection,
                library: library,
                onNewPlaylist: { isPresentingNewPlaylist = true }
            )
            .navigationSplitViewColumnWidth(min: Metrics.iPadSidebarWidth, ideal: Metrics.iPadSidebarWidth, max: Metrics.iPadSidebarWidth)
        } detail: {
            HStack(spacing: 0) {
                // A `.toolbar` principal item never rendered here — a
                // `NavigationStack` nested inside this `HStack` (rather than
                // being NavigationSplitView's own direct column content)
                // didn't host one reliably, with or without a navigation
                // title. `safeAreaInset` is the pattern `IPadSidebar` below
                // already uses for its own header/footer, and it doesn't
                // depend on that toolbar-hosting relationship at all — so
                // this also becomes the fix for the sidebar-toggle icon
                // being the system's own (a different glyph, floating above
                // the search field instead of beside it) and for the
                // filter/more icons the board draws beside it that a system
                // toolbar had no slot for anyway.
                NavigationStack {
                    IPadContentColumn(destination: selection ?? .recentlyPlayed, searchQuery: $searchQuery)
                        .safeAreaInset(edge: .top) {
                            IPadContentToolbar(
                                query: $searchQuery,
                                isSidebarVisible: columnVisibility != .detailOnly,
                                onToggleSidebar: toggleSidebar,
                                onFocusSearch: { selection = .search }
                            )
                        }
                        .toolbar(.hidden, for: .navigationBar)
                }
                .frame(maxWidth: .infinity)

                NowPlayingColumnView()
                    .toolbar(.hidden, for: .navigationBar)
            }
        }
        // The system's own sidebar-toggle glyph — a different icon than the
        // board's plain 3-line hamburger, and it floated above the search
        // field instead of beside it (see `IPadContentToolbar`, which is
        // this control's real replacement). Without removing the system one
        // too, both showed at once.
        .toolbar(removing: .sidebarToggle)
        .tint(Palette.honeyAmber)
        .task { await library.load(environment: environment) }
        .sheet(isPresented: $isPresentingNewPlaylist) {
            NewPlaylistView { newPlaylist in
                Task { await library.load(environment: environment, force: true) }
                selection = .playlist(newPlaylist)
            }
        }
        // Same account-modal flows `RootTabView` presents (design screen 29
        // and its subscription-gap/offer follow-ons) — app-modal regardless
        // of which column triggered them, so there's no separate iPad
        // treatment, only the same two modifiers wired at this root too.
        .subscriptionOffer(
            isPresented: $bindable.isPresentingSubscriptionOffer,
            onFailure: { reason in player.subscriptionOfferFailed(reason) }
        )
        .sheet(isPresented: $bindable.isPresentingSubscriptionGap) {
            SubscriptionGapView(state: player.subscription, onRetry: retryAction)
        }
        // Board 03's keyboard row: ⌘F focuses search, space toggles
        // play/pause, ⌥→ skips next. ⌘⌥U is left unbound — the player column
        // is permanent and never hidden on iPad, so there's no "show queue"
        // state for it to toggle the way iPhone's sheet has one.
        .installHiddenShortcut("f", modifiers: .command) { selection = .search }
        .installHiddenShortcut(.space, modifiers: []) { player.togglePlayPause() }
        .installHiddenShortcut(.rightArrow, modifiers: .option) { player.skipToNext() }
    }

    /// A retry is only honest when the check *failed*. A confirmed "no
    /// subscription" is an answer, and offering to re-ask it would be theatre.
    private var retryAction: (() -> Void)? {
        guard player.subscription.isUnavailable else { return nil }
        return { player.retrySubscriptionCheck() }
    }

    private func toggleSidebar() {
        withAnimation(.easeOut(duration: 0.2)) {
            columnVisibility = columnVisibility == .detailOnly ? .all : .detailOnly
        }
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
        ScrollView {
            // A plain `VStack` of custom rows, not `List(selection:)` — the
            // system sidebar list style draws its own row height, insets and
            // selection tint, none of which match Board 03's measured 44pt
            // row on an 11px-radius pill at 14%-amber when selected. Reusing
            // it would leave the sidebar looking system-default forever, no
            // matter how the tokens above it were tuned.
            VStack(alignment: .leading, spacing: 2) {
                row("Recently played", icon: "clock", .recentlyPlayed)
                row("Recently added", icon: "plus", .recentlyAdded)
                row("Artists", icon: "person", .artists)
                row("Albums", icon: "square.stack", .albums)
                row("Songs", icon: HumIcon.musicNote, .songs)
                row("Made for you", icon: "star", .madeForYou)

                sectionLabel("Playlists")
                ForEach(library.playlists) { playlist in
                    row(playlist.title, icon: "music.note.list", .playlist(playlist))
                }
                Button(action: onNewPlaylist) {
                    rowLabel("New playlist", icon: "plus.circle", tint: Palette.honeyAmber)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .top) {
            HStack(spacing: 10) {
                HumMark().frame(width: 26, height: 26)
                Text("hum,").humFont(.wordmark).foregroundStyle(Palette.honeyAmber)
                Spacer()
            }
            .padding(.horizontal, 18)
            .padding(.top, 10)
            .padding(.bottom, 4)
            .background(Palette.contentSurfaceIPad)
        }
        .safeAreaInset(edge: .bottom) {
            // Board 03's measurement: a plain person-circle avatar, then two
            // lines — "Apple Music" over "Connected · library synced" — not
            // a single checkmark-and-line row.
            HStack(spacing: 12) {
                Image(systemName: "person.crop.circle")
                    .humFont(20, weight: .regular)
                    .foregroundStyle(Palette.textSecondary)
                    .frame(width: 34, height: 34)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Apple Music")
                        .humFont(14)
                        .foregroundStyle(Palette.textPrimary)
                    Text("Connected · library synced")
                        .humFont(11.5)
                        .foregroundStyle(Palette.textMuted)
                }
                Spacer()
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(Palette.contentSurfaceIPad)
        }
        .background(Palette.contentSurfaceIPad)
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title.uppercased())
            .humFont(HumTextStyle(size: 11, relativeTo: .caption, tracking: 1.2))
            .foregroundStyle(Palette.textMuted)
            .padding(.horizontal, 12)
            .padding(.top, 18)
            .padding(.bottom, 6)
    }

    private func row(_ title: String, icon: String, _ destination: IPadSidebarDestination) -> some View {
        let isSelected = selection == destination
        return Button {
            selection = destination
        } label: {
            rowLabel(title, icon: icon, tint: isSelected ? Palette.honeyAmber : Palette.textPrimary)
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(isSelected ? Palette.honeyAmber.opacity(0.14) : .clear)
        )
    }

    private func rowLabel(_ title: String, icon: String, tint: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .humFont(15, weight: .regular)
                .foregroundStyle(tint)
                .frame(width: 20)
            Text(title)
                .humFont(15)
                .foregroundStyle(tint)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .frame(height: 44)
        .contentShape(.rect)
    }
}

/// Board 03's own measured content-column toolbar: a plain 3-line hamburger
/// (34×34, radius 9) directly beside the search field, then a filter icon
/// and a "more" kebab at the trailing edge — all four in one row, 30pt
/// gutters matching `Metrics.iPadContentGutter`. Replaces both the system's
/// own sidebar-toggle glyph (a different icon, floating alone above the
/// search field rather than beside it) and the toolbar that had no slot for
/// the filter/kebab icons at all.
private struct IPadContentToolbar: View {
    @Binding var query: String
    let isSidebarVisible: Bool
    let onToggleSidebar: () -> Void
    let onFocusSearch: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            IPadToolbarIconButton(systemName: HumIcon.dragHandle, action: onToggleSidebar)
                .accessibilityLabel(isSidebarVisible ? "Hide Sidebar" : "Show Sidebar")

            IPadSearchField(query: $query, onFocus: onFocusSearch)
                .frame(maxWidth: .infinity)

            // Filter and sort aren't defined features yet — the board draws
            // both icons but specifies no behaviour behind them, so these
            // stay honest placeholders (Board 03 revision items 10/12's
            // "flag, don't silently resolve" treatment) rather than a
            // fabricated menu.
            IPadToolbarIconButton(systemName: "line.3.horizontal.decrease", action: {})
                .accessibilityLabel("Filter")
            IPadToolbarIconButton(systemName: HumIcon.overflow, rotation: 90, action: {})
                .accessibilityLabel("More")
        }
        .padding(.horizontal, Metrics.iPadContentGutter)
        .padding(.top, 14)
        .padding(.bottom, 14)
        .background(Palette.deepOnyx)
    }
}

private struct IPadToolbarIconButton: View {
    let systemName: String
    var rotation: Double = 0
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .humFont(15, weight: .regular)
                .foregroundStyle(Palette.textPrimary.opacity(0.72))
                .rotationEffect(.degrees(rotation))
                .frame(width: 34, height: 34)
                .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
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
            // Same clear affordance the iPhone chrome's own search field
            // carries (`HumTabBar`) — shown only once there's text to clear.
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: HumIcon.clearField)
                        .foregroundStyle(Palette.textMuted)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
            // Board 03's own measurement shows this hint sitting inside the
            // field's trailing edge — a label, not a live key-event target;
            // ⌘F itself is wired as a hidden shortcut at the split view root.
            Text("⌘F")
                .humFont(12, weight: .medium)
                .foregroundStyle(Palette.textDisabled)
        }
        .padding(.horizontal, 12)
        .frame(height: 38, alignment: .center)
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
