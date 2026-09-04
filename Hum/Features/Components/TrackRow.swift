import SwiftUI

/// A track in a list. **Opaque content.**
///
/// Two variants, both drawn in the prototype:
/// - `.artwork` — Home and Queue: thumbnail, title, artist, duration.
/// - `.index` — Album detail: track number instead of a thumbnail.
///
/// Unlike the superseded Feed.fm plan, rows here *are* play triggers — MusicKit
/// supports on-demand playback, so tapping starts the collection at that index.
struct TrackRow: View {
    enum Leading: Equatable {
        case artwork
        case index(Int)
    }

    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(PlayerViewModel.self) private var player
    @Environment(\.isFocused) private var isFocused
    @State private var isPresentingAddToPlaylist = false
    @State private var isHovered = false

    let track: HumTrack
    var leading: Leading = .artwork
    var isCurrent: Bool = false
    var showsDuration: Bool = true
    // `action` stays the first closure-typed property after the plain
    // fields above: an unlabeled trailing closure binds to the *first*
    // parameter of function type it finds after a call's explicit
    // arguments, not the last one declared — so `onGoToArtist`/`onGoToAlbum`
    // below it never intercept a call site's trailing `{ ... }` meant for
    // this.
    var action: (() -> Void)?
    /// "Go to Artist" / "Go to Album" (design screen 31). `nil` — the
    /// default everywhere but `DetailView` — hides the corresponding menu
    /// item entirely rather than showing one that does nothing; see the doc
    /// comment on `contextMenuContent`.
    var onGoToArtist: ((HumTrack) -> Void)?
    var onGoToAlbum: ((HumTrack) -> Void)?

    var body: some View {
        Button {
            action?()
        } label: {
            HStack(spacing: leadingSpacing) {
                leadingView

                VStack(alignment: .leading, spacing: 4) {
                    Text(track.title)
                        .humFont(.rowTitle)
                        .foregroundStyle(isCurrent ? Palette.honeyAmber : Palette.textPrimary)
                        // The design's AX3 screen shows long titles *wrapping*
                        // rather than truncating — "Kitchen Light in the Late
                        // Afternoon" runs to a second line. At normal sizes a
                        // single line keeps the row rhythm.
                        .lineLimit(isAccessibilitySize ? 3 : 1)
                        .truncationMode(.tail)

                    Text(track.artist)
                        .humFont(.rowSubtitle)
                        // Amber at 80%, per the design's type ramp — the row
                        // artist is the one piece of body copy that carries
                        // the accent.
                        .foregroundStyle(Palette.honeyAmber.opacity(0.8))
                        .lineLimit(isAccessibilitySize ? 2 : 1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Dropped at accessibility sizes: the reflow gives the title
                // and artist the width instead, which is what the design shows.
                if showsDuration, track.duration > 0, !isAccessibilitySize {
                    Text(track.duration.humTimestamp)
                        .humFont(.timecode)
                        .foregroundStyle(Palette.textMuted)
                }
            }
            .padding(.vertical, rowPadding)
            .contentShape(.rect)
            // iPad pointer/keyboard row (Board 03 A5): a 4%-white tint on
            // trackpad hover — rows get a tint, not the grid tiles' lift,
            // per the board's own distinction between the two — plus the
            // same 2px amber focus ring grid tiles draw when reached by
            // keyboard/controller focus, not hover.
            .background(isHovered ? Color.white.opacity(0.04) : Color.clear)
            .overlay {
                if isFocused {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Palette.honeyAmber, lineWidth: Metrics.iPadFocusRingWidth)
                        .padding(-Metrics.iPadFocusRingOffset)
                }
            }
        }
        .buttonStyle(.pressable)
        .disabled(action == nil)
        .onHover { isHovered = $0 }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(action == nil ? [] : .isButton)
        .contextMenu { contextMenuContent }
        .sheet(isPresented: $isPresentingAddToPlaylist) {
            AddToPlaylistView(track: track)
        }
    }

    /// Design screen 31's long-press menu, all seven actions now built.
    /// "Add to Playlist…" presents its own sheet (screen 32) directly — a
    /// modal needs no navigation stack, unlike "Go to Artist" / "Go to
    /// Album", which resolve through `MusicCatalogService.artist(for:)` /
    /// `.album(for:)` — real MusicKit lookups, not a guess from
    /// `HumTrack.artist`/`albumTitle`'s display strings — but only appear
    /// when a caller supplies the closure; most `TrackRow` call sites don't
    /// sit on a navigation stack that can push the result, and a menu item
    /// that resolves correctly but has nowhere to go is the same
    /// dead-button problem this codebase already ruled out for Now
    /// Playing's lyrics button (NP-7).
    @ViewBuilder
    private var contextMenuContent: some View {
        Button("Play Next", systemImage: HumIcon.playNext) {
            player.playNext(track)
        }
        Button("Add to Queue", systemImage: HumIcon.addToQueue) {
            player.addToQueue(track)
        }
        let inLibrary = player.isInLibrary(track)
        Button(
            inLibrary ? "In Your Library" : "Add to Library",
            systemImage: inLibrary ? HumIcon.inLibrary : HumIcon.addToLibrary
        ) {
            player.addToLibrary(track)
        }
        .disabled(inLibrary)
        Button("Add to Playlist…", systemImage: "text.badge.plus") {
            isPresentingAddToPlaylist = true
        }
        if let onGoToAlbum {
            Button("Go to Album", systemImage: "square.stack") {
                onGoToAlbum(track)
            }
        }
        if let onGoToArtist {
            Button("Go to Artist", systemImage: "person") {
                onGoToArtist(track)
            }
        }
        ShareLink(item: shareText) {
            Label("Share", systemImage: HumIcon.share)
        }
    }

    private var shareText: String {
        "\(track.title) — \(track.artist)"
    }

    private var isAccessibilitySize: Bool { typeSize >= .accessibility1 }

    // MARK: - Pieces

    @ViewBuilder
    private var leadingView: some View {
        switch leading {
        case .artwork:
            ArtworkView(
                url: track.artworkURL,
                size: Metrics.artRow,
                cornerRadius: Metrics.radiusArtRow
            )
        case .index(let number):
            Text("\(number)")
                .humFont(HumTextStyle.timecode.size(14))
                .foregroundStyle(isCurrent ? Palette.honeyAmber : Palette.textMuted)
                .frame(width: 18, alignment: .leading)
        }
    }

    private var leadingSpacing: CGFloat {
        switch leading {
        case .artwork: Metrics.rowSpacing
        case .index: Metrics.rowSpacingWide
        }
    }

    private var rowPadding: CGFloat {
        switch leading {
        case .artwork: Metrics.rowPaddingCompact
        case .index: Metrics.rowPaddingRelaxed
        }
    }

    private var accessibilityLabel: Text {
        // The currently-playing row is signalled by color alone in the
        // prototype, so VoiceOver needs it said out loud.
        let prefix = isCurrent ? "Now playing, " : ""
        let duration = showsDuration && track.duration > 0
            ? ", \(track.duration.humSpokenDuration)"
            : ""
        return Text("\(prefix)\(track.title), \(track.artist)\(duration)")
    }
}

/// A hairline under a row. Extracted so list spacing stays consistent and the
/// last row can drop its divider without each screen re-deciding.
struct RowDivider: View {
    var body: some View {
        Rectangle()
            .fill(Palette.hairline)
            .frame(height: 1)
    }
}
