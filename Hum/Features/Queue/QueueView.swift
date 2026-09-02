import SwiftUI

private extension EdgeInsets {
    /// List rows default to their own leading inset, which does not match the
    /// 24pt screen gutter the rest of the app uses. Set explicitly so the
    /// Queue lines up with Home and Detail.
    static var horizontalGutter: EdgeInsets {
        .init(top: 0, leading: Metrics.gutter, bottom: 0, trailing: Metrics.gutter)
    }
}

/// The queue. **Opaque content throughout.**
///
/// Every mutation here goes through `QueueReducer` inside `PlayerViewModel` —
/// the pure, exhaustively tested function — and only then reaches the player.
/// The view expresses intent; it owns no queue logic.
struct QueueView: View {
    @Environment(PlayerViewModel.self) private var player
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let current = player.currentTrack {
                    nowPlayingCard(current)
                    RowDivider()
                }

                List {
                    Section {
                        if player.upNext.isEmpty {
                            emptyState
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .listRowInsets(.horizontalGutter)
                        } else {
                            upNextRows
                        }
                    } header: {
                        if !player.upNext.isEmpty {
                            SectionHeader(
                                title: "Up next",
                                trailing: player.sourceLabel.isEmpty ? nil : player.sourceLabel
                            )
                            .listRowInsets(
                                .init(
                                    top: 12,
                                    leading: Metrics.gutter,
                                    bottom: 8,
                                    trailing: Metrics.gutter
                                )
                            )
                        }
                    }
                    .listRowBackground(Color.clear)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .environment(\.defaultMinListRowHeight, Metrics.tapTarget)
            }
            .background(Palette.deepOnyx)
            .navigationTitle("Queue")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Now Playing", systemImage: HumIcon.back) { dismiss() }
                        .tint(Palette.honeyAmber)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Clear") { player.clearUpNext() }
                        .tint(Palette.textSecondary)
                        .disabled(player.upNext.isEmpty)
                }
            }
        }
    }

    // MARK: - Now playing card

    private func nowPlayingCard(_ track: HumTrack) -> some View {
        HStack(spacing: Metrics.rowSpacing) {
            ArtworkView(
                url: track.artworkURL,
                size: Metrics.artQueueHeader,
                cornerRadius: Metrics.radiusArtSmall
            )

            VStack(alignment: .leading, spacing: 4) {
                Text("Playing now")
                    .overline(size: 11, tracking: 1.5)
                    .foregroundStyle(Palette.honeyAmber)
                Text(track.title)
                    .font(.system(size: 16))
                    .foregroundStyle(Palette.textPrimary)
                    .lineLimit(1)
                Text(track.artist)
                    .font(HumFont.rowSubtitle)
                    .foregroundStyle(Palette.textTertiary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            LevelMeter(isAnimating: player.isPlaying)
        }
        .padding(.horizontal, Metrics.gutter)
        .padding(.top, 6)
        .padding(.bottom, 20)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Playing now: \(track.title) by \(track.artist)")
    }

    // MARK: - Up next

    /// One up-next row, carrying an identity that is both **stable across a
    /// reorder** and **unique across repeats**. Neither half comes free:
    ///
    /// - Identifying by track id collapses two copies of the same song into a
    ///   single SwiftUI identity: rows drop out and a swipe lands on the wrong
    ///   one. A queue holds repeats routinely.
    /// - Identifying by position makes every row change identity the moment
    ///   anything moves, so `List` cannot animate a reorder — the dropped row
    ///   overlaps its neighbour, the gap it left never opens, and the list
    ///   appears to reload once the dust settles.
    ///
    /// Numbering each repeat gives a row the same identity before and after a
    /// move, which is what `onMove` needs to animate. Two copies of one track
    /// do swap identities when dragged past each other — and are pixel-identical
    /// when they do, so there is nothing to see.
    private struct UpNextRow: Identifiable {
        let id: String
        /// Index into the full queue, not into `upNext`.
        let index: Int
        let track: HumTrack
    }

    private var upNextEntries: [UpNextRow] {
        // `upNext` is a suffix of `entries`, so a row's queue index is its
        // offset past the cursor.
        let base = (player.queue.currentIndex ?? -1) + 1
        var seen: [String: Int] = [:]

        return player.upNext.enumerated().map { offset, track in
            let occurrence = seen[track.id, default: 0]
            seen[track.id] = occurrence + 1
            return UpNextRow(
                id: "\(track.id)#\(occurrence)",
                index: base + offset,
                track: track
            )
        }
    }

    private var upNextRows: some View {
        ForEach(upNextEntries) { row in
            TrackRow(track: row.track, showsDuration: false) {
                player.jump(to: row.index)
            }
            .listRowInsets(.horizontalGutter)
            .listRowSeparatorTint(Palette.hairline)
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button("Remove", systemImage: HumIcon.remove, role: .destructive) {
                    player.remove(at: row.index)
                }
            }
            .accessibilityActions {
                Button("Play now") { player.jump(to: row.index) }
                Button("Remove from queue") { player.remove(at: row.index) }
            }
        }
        .onMove { source, destination in
            move(from: source, to: destination, base: (player.queue.currentIndex ?? -1) + 1)
        }
    }

    /// Native drag-to-reorder. The reducer owns cursor validity, so this
    /// rebuilds the full entry list and hands it over as a `setQueue`.
    private func move(from source: IndexSet, to destination: Int, base: Int) {
        guard let current = player.queue.currentIndex else { return }
        var entries = player.queue.entries
        let absoluteSource = IndexSet(source.map { base + $0 })
        entries.move(fromOffsets: absoluteSource, toOffset: base + destination)
        // Only up-next rows can move, and `base` is one past the cursor, so
        // the playing entry never shifts. Re-finding it by id would pick the
        // wrong copy the moment a track appears in the queue twice.
        player.replaceQueue(entries, currentIndex: current)
    }

    private var emptyState: some View {
        EmptyStateView(
            icon: HumIcon.library,
            headline: "Nothing after this one",
            message: "When this track ends, playback stops. Add something from your library to keep going.",
            actionTitle: player.currentTrack == nil ? nil : "Fill from this album",
            action: player.currentTrack == nil ? nil : { player.refillFromCurrentSource() }
        )
    }
}
