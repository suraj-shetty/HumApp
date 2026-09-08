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
    /// Shared by both `.recentlyPlayed` and `.madeForYou` — those two
    /// destinations used to each instantiate their own `HomeViewModel`, so
    /// switching between them in the sidebar destroyed and recreated the
    /// view struct (and its `@State`), re-fetching from MusicKit every time.
    /// Hoisted here, at the split view itself, which isn't torn down by a
    /// sidebar selection change, both destinations now share one already-
    /// loaded instance.
    @State private var homeModel: HomeViewModel?
    // A real `@State`, not `.constant(.doubleColumn)`: at 1194×834 landscape
    // (the board's own measurement) both columns fit and this starts and
    // stays expanded. But `.constant` can never be written back to, so at
    // any width the system can't satisfy — portrait, a smaller iPad, Split
    // View multitasking — it was silently dropping the sidebar with no
    // toggle to bring it back, because there was nothing for the system to
    // write the collapse into. A mutable binding gets the sidebar's own
    // built-in reveal control back in that case.
    //
    // A plain `Bool` sidebar (no `NavigationSplitView` at all) was tried
    // too, on the reasoning that the player column already works as a
    // manually-composed `HStack` sibling. Measured and rejected: with the
    // sidebar as a plain conditional view, the content `NavigationStack`
    // rendered every leading pixel under the sidebar's own width hidden —
    // the toolbar's hamburger, the search field's first few letters, every
    // row's leading text — reproducibly, on a clean install, regardless of
    // `.clipped()` or whether the navigation bar was hidden. Only
    // `NavigationSplitView` actually owning the sidebar avoids it, so it
    // stays — with `.doubleColumn`, not `.all`, since this is a genuine
    // two-column split (the player column is a separate `HStack` sibling
    // outside it, not a third split-view column) and `.all` targets a
    // three-column split's "show everything" state.
    @State private var columnVisibility: NavigationSplitViewVisibility = .doubleColumn

    var body: some View {
        @Bindable var bindable = player

        // Genuinely three columns in the design. Built as a real two-column
        // `NavigationSplitView` (sidebar + content) — nothing else — with the
        // player column as a plain `HStack` sibling *outside* it, not folded
        // into the `detail:` slot. That folding was tried first and measured
        // as broken too: putting an `HStack` inside `detail:` made
        // `NavigationSplitView` size that whole `HStack` — content *and*
        // player together — as if it were the entire window, sidebar width
        // included, and then floated the sidebar on top of it as an overlay
        // instead of laying the two out side by side, hiding the same
        // leading content the plain-`Bool` attempt above did.
        // `NavigationSplitView` only negotiates real side-by-side columns
        // correctly when `detail:` is the sole column view it owns — so the
        // player column lives beside the whole split view, not inside it.
        return HStack(spacing: 0) {
            NavigationSplitView(columnVisibility: $columnVisibility) {
                IPadSidebar(
                    selection: $selection,
                    library: library,
                    onNewPlaylist: { isPresentingNewPlaylist = true }
                )
                .navigationSplitViewColumnWidth(min: Metrics.iPadSidebarWidth, ideal: Metrics.iPadSidebarWidth, max: Metrics.iPadSidebarWidth)
            } detail: {
                // A `.toolbar` principal item never rendered here — see
                // `IPadContentToolbar`, which is this control's real
                // replacement, built with `safeAreaInset` instead (the same
                // pattern `IPadSidebar` below already uses for its own
                // header/footer).
                NavigationStack {
                    IPadContentColumn(destination: selection ?? .recentlyPlayed, searchQuery: $searchQuery, homeModel: homeModel)
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
                // Without an explicit minimum here, `NavigationSplitView`
                // assumed a much larger one for this column and, once the
                // player column outside it took its own 340pt, judged the
                // remaining width too tight to show sidebar and content
                // side by side — collapsing to the overlay presentation by
                // default even at this split view's full ~870pt. A minimum
                // that matches what this column actually needs (Board 03's
                // narrowest measured composition) lets it stay expanded.
                .navigationSplitViewColumnWidth(min: 320, ideal: 500)
            }
            // The system's own sidebar-toggle glyph — a different icon than
            // the board's plain 3-line hamburger, and it floated above the
            // search field instead of beside it (see `IPadContentToolbar`,
            // which is this control's real replacement). Without removing
            // the system one too, both showed at once.
            .toolbar(removing: .sidebarToggle)
            .navigationSplitViewStyle(.balanced)

            NowPlayingColumnView()
                .toolbar(.hidden, for: .navigationBar)
        }
        .tint(Palette.honeyAmber)
        .task { await library.load(environment: environment) }
        .task {
            if homeModel == nil { homeModel = HomeViewModel(environment: environment) }
            await homeModel?.load()
            homeModel?.startObservingSubscriptionChanges()
        }
        // This root is *not* actually torn-down-proof the way the comment
        // this replaced assumed: `RootGateView.isIPadLayout` is driven by
        // `horizontalSizeClass`, which Stage Manager/Split View can flip to
        // `.compact` without a device change, swapping this whole view out
        // for `RootTabView` and destroying `homeModel` with it — but its
        // `onChange` registration lives in the app-lifetime
        // `SubscriptionStateStore` and outlives it unless removed here.
        .onDisappear {
            homeModel?.stopObservingSubscriptionChanges()
        }
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
            SubscriptionGapView(state: player.subscription, onRetry: player.subscriptionRetryAction)
        }
        // Board 03's keyboard row: ⌘F focuses search, space toggles
        // play/pause, ⌥→ skips next. ⌘⌥U is left unbound — the player column
        // is permanent and never hidden on iPad, so there's no "show queue"
        // state for it to toggle the way iPhone's sheet has one.
        .installHiddenShortcut("f", modifiers: .command) { selection = .search }
        .installHiddenShortcut(.space, modifiers: []) { player.togglePlayPause() }
        .installHiddenShortcut(.rightArrow, modifiers: .option) { player.skipToNext() }
    }


    private func toggleSidebar() {
        withAnimation(.easeOut(duration: 0.2)) {
            columnVisibility = columnVisibility == .detailOnly ? .doubleColumn : .detailOnly
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
                // Not in Board 03's own sidebar drawing — the design puts
                // search only in the toolbar's own field/island. Added
                // because the toolbar field has no destination-side
                // indication once it *is* active: nothing in the sidebar
                // showed the amber "you are here" the six rows below it
                // already give every other destination.
                row("Search", icon: HumIcon.search, .search)
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
/// (34×34, radius 9) directly beside the search field. Replaces the
/// system's own sidebar-toggle glyph (a different icon, floating alone
/// above the search field rather than beside it).
///
/// The board also draws a filter icon and a "more" kebab at the trailing
/// edge, but neither survived a real audit: no filter/sort concept exists
/// anywhere in the app (Library already has its own real filter chips for
/// its own content), and the kebab's only defined action — DetailView's
/// Play/Shuffle menu — is already shown as visible buttons on-screen
/// whenever DetailView is open, so wiring it would only duplicate an
/// existing control, not add one. Dropped both rather than keep dead
/// placeholders or build redundant behaviour.
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
        }
        .padding(.horizontal, Metrics.iPadContentGutter)
        .padding(.top, 14)
        .padding(.bottom, 14)
        .background(Palette.deepOnyx)
    }
}

private struct IPadToolbarIconButton: View {
    let systemName: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .humFont(15, weight: .regular)
                .foregroundStyle(Palette.textPrimary.opacity(0.72))
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
                // `SearchView` itself already searches live as you type
                // (`.onChange(of: query)`, debounced) — but nothing switched
                // the content column *to* it until Return was pressed, so
                // typing produced no visible results at all until then.
                // `onFocus` here just selects the destination; `SearchView`
                // owns the actual query timing.
                .onChange(of: query) { previous, current in
                    if previous.isEmpty && !current.isEmpty {
                        onFocus()
                    }
                }
            // Same clear affordance the iPhone chrome's own search field
            // carries (`HumTabBar`) — shown only once there's text to clear.
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: HumIcon.clearField)
                        .foregroundStyle(Palette.textMuted)
                        // Sized to the field's own 38pt height rather than
                        // the full 44pt `Metrics.tapTarget` — this field
                        // (unlike `HumTabBar`'s) has no room to grow without
                        // overflowing its pill background, but the bare
                        // glyph's hit area was smaller still.
                        .frame(width: 32, height: 32)
                        .contentShape(.rect)
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
