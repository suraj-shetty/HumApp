enum QueueAction: Sendable, Equatable {
    case setQueue([HumTrack], startingAt: Int)
    /// Tapping a row under "Up next".
    case jump(to: Int)
    /// The trailing × on a queue row.
    case remove(at: Int)
    /// The Queue screen's "Clear". Non-destructive to what is currently audible.
    case clearUpNext
    case next
    case previous
    case toggleShuffle
    case cycleRepeat
    /// The track context menu's "Play Next" (screen 31) — inserts right
    /// after the playing entry, ahead of whatever was already up next.
    case playNext(HumTrack)
    /// The track context menu's "Add to Queue" — appends to the end.
    case appendToQueue(HumTrack)
}

/// Pure. Covers the brief's third named test criterion — queue state management.
///
/// The reducer decides; the adapter mirrors the result onto
/// `ApplicationMusicPlayer.shared.queue`. Keeping the decision pure and the
/// effect in the adapter is what makes queue behaviour testable with no player,
/// no device, and no Apple Music account.
struct QueueReducer: Sendable {

    static func reduce(_ state: QueueState, _ action: QueueAction) -> QueueState {
        var next = state

        switch action {
        case .setQueue(let tracks, let start):
            next.entries = tracks
            next.currentIndex = tracks.isEmpty ? nil : min(max(start, 0), tracks.count - 1)

        case .jump(let index):
            // Out of range is a no-op, not a crash. Queue rows can be tapped
            // after a concurrent removal has already shortened the list.
            guard next.entries.indices.contains(index) else { return state }
            next.currentIndex = index

        case .remove(let index):
            guard next.entries.indices.contains(index) else { return state }
            next.entries.remove(at: index)
            next.currentIndex = Self.indexAfterRemoval(
                removed: index,
                current: next.currentIndex,
                remaining: next.entries.count
            )

        case .clearUpNext:
            // "Clear" empties what is *ahead*. The current track keeps playing —
            // the prototype's empty state says so explicitly ("when this track
            // ends, playback stops"), so clearing must not stop the audio.
            if let current = next.currentIndex, next.entries.indices.contains(current) {
                next.entries = Array(next.entries[...current])
            } else {
                next.entries = []
                next.currentIndex = nil
            }

        case .next:
            next.currentIndex = Self.advance(from: next.currentIndex, in: next)

        case .previous:
            next.currentIndex = Self.retreat(from: next.currentIndex, in: next)

        case .toggleShuffle:
            // Only the flag moves. Playback *order* belongs to the player, so
            // the current track's identity survives a toggle by construction.
            next.shuffleEnabled.toggle()

        case .cycleRepeat:
            next.repeatMode = next.repeatMode.next

        case .playNext(let track):
            // One past the cursor — the same position `QueueView`'s `base`
            // already treats as "up next" starts. Nothing plays yet, and the
            // insert still lands first: `(nil) + 1 == 0`.
            let insertAt = (next.currentIndex ?? -1) + 1
            next.entries.insert(track, at: min(insertAt, next.entries.count))

        case .appendToQueue(let track):
            next.entries.append(track)
        }

        return next
    }

    // MARK: - Cursor arithmetic

    private static func indexAfterRemoval(
        removed: Int,
        current: Int?,
        remaining: Int
    ) -> Int? {
        guard remaining > 0 else { return nil }
        guard let current else { return nil }

        if removed < current {
            // Everything above shifted down by one; stay on the same track.
            return current - 1
        }
        if removed > current {
            return current
        }
        // Removed the playing entry. The same index now holds what used to be
        // next, which is the behaviour we want — unless it was the last entry,
        // in which case fall back to the new final one.
        return min(current, remaining - 1)
    }

    private static func advance(from current: Int?, in state: QueueState) -> Int? {
        guard let current, state.entries.indices.contains(current) else { return nil }
        // Repeat-one holds position; the adapter restarts the track.
        guard state.repeatMode != .one else { return current }

        let candidate = current + 1
        if state.entries.indices.contains(candidate) { return candidate }
        // Ran off the end.
        return state.repeatMode == .all ? 0 : nil
    }

    private static func retreat(from current: Int?, in state: QueueState) -> Int? {
        guard let current, state.entries.indices.contains(current) else { return nil }
        guard state.repeatMode != .one else { return current }

        if current > 0 { return current - 1 }
        // At the head: wrap with repeat-all, otherwise stay put and let the
        // adapter restart the track — matching the prototype, where `prev` at
        // the start of a queue restarts rather than stopping playback.
        return state.repeatMode == .all ? state.entries.count - 1 : 0
    }
}
