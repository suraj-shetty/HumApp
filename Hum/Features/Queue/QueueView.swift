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
                            // Not a `SectionHeader`. The design labels this an
                            // uppercase overline naming the source — "NEXT FROM
                            // LATE KITCHEN" — where Home's section headers are
                            // 19pt sentence case. Same words, different role.
                            Text(upNextLabel)
                                .humFont(.groupLabel)
                                .foregroundStyle(Palette.textPrimary.opacity(0.62))
                                .accessibilityAddTraits(.isHeader)
                                .frame(maxWidth: .infinity, alignment: .leading)
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
            .navigationTitle("Up Next")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    // "Done", not a back chevron: the design treats the queue
                    // as a sheet you finish with, not a page you came from.
                    Button("Done") { dismiss() }
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
                cornerRadius: Metrics.radiusArt
            )

            VStack(alignment: .leading, spacing: 4) {
                Text("Now playing")
                    .humFont(HumTextStyle(size: 11, relativeTo: .caption2, tracking: 1.5, uppercase: true))
                    .foregroundStyle(Palette.honeyAmber)
                Text(track.title)
                    .humFont(16)
                    .foregroundStyle(Palette.textPrimary)
                    .lineLimit(1)
                Text(track.artist)
                    .humFont(.rowSubtitle)
                    .foregroundStyle(Palette.textMuted)
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

    /// BISECT: identity is back to position, the last form confirmed working
    /// on device. Occurrence-numbered identity — `"<track id>#<nth repeat>"` —
    /// is what `onMove` needs to animate a reorder, and introducing it is the
    /// change that began the drag hang. Every adapter fix attempted afterwards
    /// was chasing the wrong file.
    ///
    /// The likely mechanism, unconfirmed: with stable identities SwiftUI runs
    /// a real move animation, and the player mirror's blocking MusicKit call
    /// then lands *inside* that transaction. With position identity the list
    /// reloads instead, and the same call happens outside it — janky, but it
    /// completes.
    ///
    /// Cost of this form: duplicate rows share an identity, and a reorder
    /// cannot animate. See PROGRESS.md Findings 1 and 4.
    private var upNextRows: some View {
        let base = (player.queue.currentIndex ?? -1) + 1

        return ForEach(Array(player.upNext.enumerated()), id: \.offset) { offset, track in
            let index = base + offset
            TrackRow(track: track) {
                player.jump(to: index)
            }
            .listRowInsets(.horizontalGutter)
            .listRowSeparatorTint(Palette.hairline)
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button("Remove", systemImage: HumIcon.remove, role: .destructive) {
                    player.remove(at: index)
                }
                // Without this the action inherits the app's amber tint — the
                // colour that means "play" — for a destructive control.
                .tint(Palette.terracotta)
            }
            .accessibilityActions {
                Button("Play now") { player.jump(to: index) }
                Button("Remove from queue") { player.remove(at: index) }
            }
        }
        .onMove { source, destination in
            move(from: source, to: destination, base: base)
        }
    }

    /// "Next from Late Kitchen" — the design names the source in this label
    /// rather than in a trailing accessory.
    private var upNextLabel: String {
        player.sourceLabel.isEmpty ? "Up next" : "Next from \(player.sourceLabel)"
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
