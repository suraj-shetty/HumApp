import SwiftUI

/// `HomeView`, `LibraryView`, and `SearchView` are each reused two ways:
/// standalone as an iPhone tab root (needs its own `NavigationStack`), and
/// embedded in `IPadContentColumn`'s `NavigationSplitView` column (already
/// has one — nesting a second there swallowed that column's own toolbar,
/// including the sidebar-reveal control). All three had copy-pasted the same
/// `if providesOwnChrome { NavigationStack { ... } } else { ... }` branch to
/// decide it. `hidesNavigationBar` covers the one real difference: Home and
/// Library hide their bar (every iPhone tab root does, so switching tabs
/// doesn't animate one in and out); Search keeps its.
extension View {
    @ViewBuilder
    func navigationRoot(providesOwnChrome: Bool, hidesNavigationBar: Bool = true) -> some View {
        if providesOwnChrome {
            if hidesNavigationBar {
                NavigationStack { self.toolbar(.hidden, for: .navigationBar) }
            } else {
                NavigationStack { self }
            }
        } else {
            self
        }
    }
}

/// Home. **Opaque content throughout** — no glass anywhere on this screen.
struct HomeView: View {
    @Environment(\.appEnvironment) private var environment
    @Environment(PlayerViewModel.self) private var player
    @State private var model: HomeViewModel?
    @State private var route: HumCollection?
    @State private var network = NetworkMonitor()

    /// iPad's content column already sits inside `NavigationSplitView`'s own
    /// per-column navigation container and toolbar. Nesting a second
    /// `NavigationStack` here — with its bar hidden, which every iPhone tab
    /// root needs so switching tabs doesn't animate a bar in and out — was
    /// swallowing that column's entire toolbar, including the system
    /// sidebar-reveal control, when `IPadContentColumn` reused this view
    /// as-is. `RootSplitView`'s content column passes `false`.
    var embedsNavigationChrome: Bool = true

    var body: some View {
        content.navigationRoot(providesOwnChrome: embedsNavigationChrome)
    }

    private var content: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                if network.isOffline {
                    offlineBanner
                }
                header
                if model?.needsSubscription == true {
                    catalogUnavailable
                } else if network.isOffline {
                    downloadedShelf
                    connectionRequiredCard
                } else {
                    shelf
                    madeForYou
                }
            }
        }
        .scrollIndicators(.hidden)
        .background(Palette.deepOnyx)
        .navigationDestination(item: $route) { collection in
            DetailView(collection: collection)
        }
        .task {
            if model == nil { model = HomeViewModel(environment: environment) }
            model?.isOffline = network.isOffline
            await model?.load()
            model?.startObservingSubscriptionChanges()
        }
        // Home lives at the root of its tab's persistent `NavigationStack`
        // (`RootTabView`'s own doc comment), so pushing e.g. `DetailView`
        // fires `onDisappear` on Home without destroying it — and whether
        // `.task` reliably restarts when popping back to reveal it again is
        // genuinely ambiguous in SwiftUI. `onAppear` always fires on that
        // reveal, so it's the one guaranteed hook to restart observation;
        // `startObservingSubscriptionChanges()`'s own guard makes calling it
        // from both here and `.task` safe regardless of which one restarts
        // it first.
        .onAppear {
            model?.startObservingSubscriptionChanges()
        }
        .onDisappear {
            model?.stopObservingSubscriptionChanges()
        }
        // Reachability can change after the first load — this is the
        // only place that re-triggers it, since `load()` itself only
        // ever runs once from `.idle`.
        .onChange(of: network.isOffline) { _, offline in
            Task {
                model?.isOffline = offline
                await model?.reload()
            }
        }
        .refreshable {
            model?.isOffline = network.isOffline
            await model?.reload()
        }
    }

    /// Design screen 11's banner — chrome, glass, the same terracotta tint
    /// the error toast uses (`Palette.terracottaGlassTint`), not a content
    /// card.
    private var offlineBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "wifi.slash")
                .humFont(15, weight: .regular)
                .foregroundStyle(Palette.terracottaLift)
                .accessibilityHidden(true)
            Text("You're offline — showing downloads")
                .humFont(13.5)
                .foregroundStyle(Palette.textPrimary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .chromeGlass(in: RoundedRectangle(cornerRadius: 20, style: .continuous), tint: nil)
        .glassTint(in: RoundedRectangle(cornerRadius: 20, style: .continuous), Palette.terracottaGlassTint, shadow: false)
        .padding(.horizontal, 14)
        .padding(.top, 6)
        .padding(.bottom, 6)
        .accessibilityElement(children: .combine)
    }

    /// Design screen 11's "Downloaded" shelf — `MusicLibraryService.downloads()`,
    /// a real `includeOnlyDownloadedContent` query, in place of the
    /// catalog-backed "Recently played" this app can't reach offline.
    @ViewBuilder
    private var downloadedShelf: some View {
        SectionHeader(title: "Downloaded")
            .padding(.horizontal, Metrics.gutter)
            .padding(.bottom, 10)

        switch model?.downloads ?? .idle {
        case .idle, .loading:
            ShelfSkeleton()

        case .loaded(let collections) where collections.isEmpty:
            EmptyStateView(
                icon: HumIcon.musicNote,
                headline: "Nothing downloaded",
                message: "Music you've downloaded for offline listening will show up here."
            )

        case .loaded(let collections):
            ScrollView(.horizontal) {
                LazyHStack(spacing: Metrics.rowSpacing) {
                    ForEach(collections) { collection in
                        Button { route = collection } label: {
                            ShelfCard(collection: collection)
                        }
                        .buttonStyle(.pressable)
                    }
                }
                .padding(.horizontal, Metrics.gutter)
                .padding(.vertical, 6)
            }
            .scrollIndicators(.hidden)
            .padding(.bottom, 20)

        case .failed(let message):
            InlineError(message: message)
        }
    }

    /// Design screen 11's explanatory card in place of "Made for you" —
    /// personalised recommendations are a catalog endpoint this app has no
    /// offline answer for, so it says so rather than showing a dead shelf.
    private var connectionRequiredCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recommendations need a connection.")
                .humFont(15.5, weight: .light)
                .foregroundStyle(Palette.textPrimary.opacity(0.78))
            AmberOutlineButton(title: "Retry", height: 44) {
                Task { await model?.reload() }
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.surfaceCard, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
        .padding(.horizontal, Metrics.gutter)
        .padding(.top, 10)
    }

    // MARK: - Header

    private var header: some View {
        // The design's Home header is the greeting alone, 32/200 in white,
        // beside the profile control — no wordmark and no overline. The
        // wordmark belongs to Connect, splash and onboarding, where the design
        // does use it.
        ScreenHeader(title: model?.greeting ?? "")
    }

    /// Both shelves come from Apple Music's personalized catalog, so with no
    /// subscription there is nothing to put in them. Stated plainly and once,
    /// rather than as two "couldn't load" rows above an empty screen — and
    /// pointing at the Library, which works perfectly well without one.
    ///
    /// Deliberately not a sales pitch: Hum gates nothing of its own and takes
    /// nothing from a signup. Apple's own offer sheet is already where a play
    /// intent goes when it needs a membership.
    private var catalogUnavailable: some View {
        EmptyStateView(
            icon: HumIcon.musicNote,
            headline: "Nothing to suggest yet",
            message: "Recently played and Made for you come from Apple Music, which this account isn't subscribed to. Everything in your library still plays — it's in the Library tab."
        )
        .padding(.top, 40)
    }

    // MARK: - Recently played

    @ViewBuilder
    private var shelf: some View {
        SectionHeader(title: "Recently played")
            .padding(.horizontal, Metrics.gutter)
            .padding(.bottom, 10)

        switch model?.recentlyPlayed ?? .idle {
        case .idle, .loading:
            ShelfSkeleton()

        case .loaded(let collections) where collections.isEmpty:
            if player.recentlyPlayedMaySyncSoon {
                EmptyStateView(
                    icon: HumIcon.musicNote,
                    headline: "Still syncing",
                    message: "Apple Music can take a few minutes to update your play history after you listen. Check back shortly."
                )
            } else {
                EmptyStateView(
                    icon: HumIcon.musicNote,
                    headline: "Nothing here yet",
                    message: "Albums and playlists you listen to will show up here."
                )
            }

        case .loaded(let collections):
            ScrollView(.horizontal) {
                // Lazy so a large recently-played list doesn't build every
                // card up front.
                LazyHStack(spacing: Metrics.rowSpacing) {
                    ForEach(collections) { collection in
                        Button { route = collection } label: {
                            ShelfCard(collection: collection)
                        }
                        .buttonStyle(.pressable)
                    }
                }
                .padding(.horizontal, Metrics.gutter)
                .padding(.vertical, 6)
            }
            .scrollIndicators(.hidden)
            .padding(.bottom, 20)

        case .failed(let message):
            InlineError(message: message)
        }
    }

    // MARK: - Made for you

    private var madeForYou: some View {
        MadeForYouSection(
            recommendations: model?.recommendations ?? .idle,
            currentTrackID: player.currentTrack?.id,
            horizontalPadding: Metrics.gutter,
            onPlay: { tracks, index in player.play(tracks, startingAt: index, source: "Made for you") }
        )
    }
}

/// The personalized-recommendations shelf Home, iPad's Listen Now, and iPad's
/// full-column "Made for you" destination all show — the same
/// `HomeViewModel.recommendations` content, laid out identically apart from
/// each context's own gutter width, top inset, and skeleton row count. Three
/// independent copies of this had already drifted (`RowSkeleton(count: 4)` on
/// iPhone/iPad's shelf vs `count: 6` on iPad's own destination) before this
/// was factored out.
struct MadeForYouSection: View {
    let recommendations: LoadState<[HumTrack]>
    let currentTrackID: String?
    let horizontalPadding: CGFloat
    var topPadding: CGFloat = 0
    var skeletonCount: Int = 4
    let onPlay: (_ tracks: [HumTrack], _ startingAt: Int) -> Void

    var body: some View {
        Group {
            SectionHeader(title: "Made for you")
                .padding(.horizontal, horizontalPadding)
                .padding(.top, topPadding)
                .padding(.bottom, 8)

            switch recommendations {
            case .idle, .loading:
                RowSkeleton(count: skeletonCount)
                    .padding(.horizontal, horizontalPadding)

            case .loaded(let tracks) where tracks.isEmpty:
                EmptyStateView(
                    icon: HumIcon.musicNote,
                    headline: "No recommendations yet",
                    message: "Listen to a few things and Apple Music will start suggesting more."
                )

            case .loaded(let tracks):
                LazyVStack(spacing: 0) {
                    // Identified by position, not by track id: a real playlist can
                    // hold the same song twice, and duplicate SwiftUI identities
                    // make rows drop out and taps land on the wrong one.
                    ForEach(Array(tracks.enumerated()), id: \.offset) { index, track in
                        TrackRow(track: track, isCurrent: currentTrackID == track.id) {
                            onPlay(tracks, index)
                        }
                        if index < tracks.count - 1 { RowDivider() }
                    }
                }
                .padding(.horizontal, horizontalPadding)

            case .failed(let message):
                InlineError(message: message).padding(.horizontal, horizontalPadding)
            }
        }
    }
}

// MARK: - Pieces

/// A collection card — 160 art, title, amber subtitle.
///
/// Shared with Library, whose grid draws the same card in the design. It was
/// duplicated inline there, which is how the two drifted apart: the copy kept a
/// 14.5 title and a grey subtitle after this one was corrected.
struct ShelfCard: View {
    let collection: HumCollection

    @Environment(\.isFocused) private var isFocused

    var body: some View {
        // Measured: 160 art at radius 10, a 10pt gap to the caption, then the
        // title and subtitle 4 apart — 208 tall in total. The caption pair is
        // its own stack because the two gaps differ.
        VStack(alignment: .leading, spacing: 10) {
            ArtworkView(
                url: collection.artworkURL,
                size: Metrics.artShelf,
                cornerRadius: Metrics.radiusArt,
                label: collection.title
            )
            VStack(alignment: .leading, spacing: 4) {
                Text(collection.title)
                    .humFont(15)
                    .foregroundStyle(Palette.textPrimary)
                    .lineLimit(1)
                Text(collection.subtitle)
                    .humFont(13)
                    // Amber at 80%, the same treatment the row artist carries.
                    .foregroundStyle(Palette.honeyAmber.opacity(0.8))
                    .lineLimit(1)
            }
        }
        .frame(width: Metrics.artShelf, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(collection.title), \(collection.subtitle)")
        // Board 03, iPad pointer/keyboard row (A5): a 3pt lift on trackpad
        // hover, and a 2px amber ring — offset so it doesn't crowd the art —
        // when reached via keyboard/game-controller focus navigation. Both
        // are no-ops without a pointer or a hardware keyboard, so this is
        // safe to leave unconditional rather than gated on idiom.
        .hoverEffect(.lift)
        .overlay {
            if isFocused {
                RoundedRectangle(cornerRadius: Metrics.radiusArt, style: .continuous)
                    .strokeBorder(Palette.honeyAmber, lineWidth: Metrics.iPadFocusRingWidth)
                    .padding(-Metrics.iPadFocusRingOffset)
            }
        }
    }
}

/// Loading placeholders that match the final layout's geometry, so content
/// arriving does not reflow the page.
struct ShelfSkeleton: View {
    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: Metrics.rowSpacing) {
                ForEach(0..<3, id: \.self) { _ in
                    VStack(alignment: .leading, spacing: 10) {
                        RoundedRectangle(cornerRadius: Metrics.radiusArt, style: .continuous)
                            .fill(Palette.artworkFill)
                            .frame(width: Metrics.artShelf, height: Metrics.artShelf)
                            .shimmering()
                        Capsule().fill(Palette.artworkFill).frame(width: 110, height: 11)
                        Capsule().fill(Palette.artworkFill).frame(width: 72, height: 10)
                    }
                }
            }
            .padding(.horizontal, Metrics.gutter)
            .padding(.vertical, 6)
        }
        .scrollIndicators(.hidden)
        .disabled(true)
        .padding(.bottom, 20)
        .accessibilityLabel("Loading")
    }
}

struct RowSkeleton: View {
    var count: Int = 4

    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<count, id: \.self) { _ in
                HStack(spacing: Metrics.rowSpacing) {
                    RoundedRectangle(cornerRadius: Metrics.radiusArt, style: .continuous)
                        .fill(Palette.artworkFill)
                        .frame(width: Metrics.artRow, height: Metrics.artRow)
                        .shimmering()
                    VStack(alignment: .leading, spacing: 6) {
                        Capsule().fill(Palette.artworkFill).frame(width: 150, height: 11)
                        Capsule().fill(Palette.artworkFill).frame(width: 90, height: 10)
                    }
                    Spacer()
                }
                .padding(.vertical, Metrics.rowPaddingCompact)
            }
        }
        .accessibilityLabel("Loading")
    }
}

struct InlineError: View {
    let message: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: HumIcon.warning)
                // Terracotta, not amber. Amber means "yes" everywhere else in
                // this app; an error drawn in it reads as an invitation.
                .foregroundStyle(Palette.terracottaLift)
                .accessibilityHidden(true)
            Text(message)
                .humFont(.rowSubtitle)
                .foregroundStyle(Palette.textSecondary)
        }
        .padding(.horizontal, Metrics.gutter)
        .padding(.vertical, 18)
    }
}
