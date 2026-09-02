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

    let track: HumTrack
    var leading: Leading = .artwork
    var isCurrent: Bool = false
    var showsDuration: Bool = true
    var action: (() -> Void)?

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
                        .foregroundStyle(Palette.textQuaternary)
                }
            }
            .padding(.vertical, rowPadding)
            .contentShape(.rect)
        }
        .buttonStyle(.pressable)
        .disabled(action == nil)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(action == nil ? [] : .isButton)
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
                .foregroundStyle(isCurrent ? Palette.honeyAmber : Palette.textQuaternary)
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
