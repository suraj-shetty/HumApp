import Testing
@testable import Hum

/// Acceptance criterion: "Unit tests pass for … queue-state logic."
@Suite("Queue")
struct QueueReducerTests {

    // MARK: - Helpers

    private static func track(_ n: Int) -> HumTrack {
        HumTrack(id: "t\(n)", title: "Track \(n)", artist: "Ana Roele")
    }

    private static func queue(count: Int, at index: Int?) -> QueueState {
        QueueState(
            entries: (0..<count).map(track),
            currentIndex: index
        )
    }

    // MARK: - setQueue

    @Test("Setting a queue clamps an out-of-range start rather than crashing")
    func setQueueClampsStart() {
        let tracks = (0..<3).map(Self.track)
        let high = QueueReducer.reduce(QueueState(), .setQueue(tracks, startingAt: 99))
        #expect(high.currentIndex == 2)

        let low = QueueReducer.reduce(QueueState(), .setQueue(tracks, startingAt: -5))
        #expect(low.currentIndex == 0)
    }

    @Test("An empty queue has no cursor")
    func emptyQueueHasNoCursor() {
        let state = QueueReducer.reduce(QueueState(), .setQueue([], startingAt: 0))
        #expect(state.currentIndex == nil)
        #expect(state.currentTrack == nil)
    }

    // MARK: - jump

    @Test("Jumping moves the cursor")
    func jumpMoves() {
        let state = QueueReducer.reduce(Self.queue(count: 5, at: 0), .jump(to: 3))
        #expect(state.currentIndex == 3)
        #expect(state.currentTrack?.id == "t3")
    }

    @Test("Jumping out of range is a no-op", arguments: [-1, 5, 99])
    func jumpOutOfRangeIsNoOp(index: Int) {
        // A queue row can be tapped after a concurrent removal already
        // shortened the list.
        let before = Self.queue(count: 5, at: 2)
        #expect(QueueReducer.reduce(before, .jump(to: index)) == before)
    }

    // MARK: - remove — cursor arithmetic

    @Test("Removing below the cursor keeps the same track playing")
    func removeBelowCursorKeepsTrack() {
        let before = Self.queue(count: 5, at: 3)
        let playing = before.currentTrack
        let after = QueueReducer.reduce(before, .remove(at: 1))
        #expect(after.currentIndex == 2)
        #expect(after.currentTrack == playing, "the audible track must not change")
    }

    @Test("Removing above the cursor leaves it alone")
    func removeAboveCursorLeavesIt() {
        let before = Self.queue(count: 5, at: 1)
        let after = QueueReducer.reduce(before, .remove(at: 4))
        #expect(after.currentIndex == 1)
        #expect(after.currentTrack?.id == "t1")
    }

    @Test("Removing the playing entry advances to what was next")
    func removeCursorAdvances() {
        let before = Self.queue(count: 5, at: 2)
        let after = QueueReducer.reduce(before, .remove(at: 2))
        #expect(after.currentIndex == 2)
        #expect(after.currentTrack?.id == "t3", "should now hold the following track")
    }

    @Test("Removing the playing entry when it is last falls back to the new last")
    func removeLastCursorFallsBack() {
        let before = Self.queue(count: 3, at: 2)
        let after = QueueReducer.reduce(before, .remove(at: 2))
        #expect(after.currentIndex == 1)
        #expect(after.currentTrack?.id == "t1")
    }

    @Test("Removing the only entry leaves no cursor")
    func removeOnlyEntry() {
        let after = QueueReducer.reduce(Self.queue(count: 1, at: 0), .remove(at: 0))
        #expect(after.entries.isEmpty)
        #expect(after.currentIndex == nil)
    }

    @Test("Removing out of range is a no-op", arguments: [-1, 5, 99])
    func removeOutOfRangeIsNoOp(index: Int) {
        let before = Self.queue(count: 5, at: 2)
        #expect(QueueReducer.reduce(before, .remove(at: index)) == before)
    }

    // MARK: - clearUpNext

    @Test("Clear empties up-next but does NOT stop the current track")
    func clearKeepsCurrent() {
        // The prototype's empty state promises exactly this: "When this track
        // ends, playback stops." So clearing must leave the audio running.
        let before = Self.queue(count: 6, at: 2)
        let playing = before.currentTrack
        let after = QueueReducer.reduce(before, .clearUpNext)

        #expect(after.currentTrack == playing, "clear must not stop playback")
        #expect(after.upNext.isEmpty)
        #expect(after.entries.count == 3, "history up to and including current is kept")
    }

    @Test("Clear with no cursor empties everything")
    func clearWithoutCursor() {
        let after = QueueReducer.reduce(Self.queue(count: 4, at: nil), .clearUpNext)
        #expect(after.entries.isEmpty)
        #expect(after.currentIndex == nil)
    }

    // MARK: - next / previous

    @Test("Next advances")
    func nextAdvances() {
        #expect(QueueReducer.reduce(Self.queue(count: 4, at: 1), .next).currentIndex == 2)
    }

    @Test("Next off the end with repeat off stops playback")
    func nextOffEndStops() {
        let after = QueueReducer.reduce(Self.queue(count: 3, at: 2), .next)
        #expect(after.currentIndex == nil, "playback stops rather than wrapping")
    }

    @Test("Next off the end with repeat-all wraps to the start")
    func nextOffEndWrapsWithRepeatAll() {
        var state = Self.queue(count: 3, at: 2)
        state.repeatMode = .all
        #expect(QueueReducer.reduce(state, .next).currentIndex == 0)
    }

    @Test("Repeat-one holds position on next and previous")
    func repeatOneHolds() {
        var state = Self.queue(count: 4, at: 2)
        state.repeatMode = .one
        #expect(QueueReducer.reduce(state, .next).currentIndex == 2)
        #expect(QueueReducer.reduce(state, .previous).currentIndex == 2)
    }

    @Test("Previous steps back")
    func previousSteps() {
        #expect(QueueReducer.reduce(Self.queue(count: 4, at: 2), .previous).currentIndex == 1)
    }

    @Test("Previous at the head stays put rather than stopping")
    func previousAtHeadStays() {
        // Matches the prototype: `prev` at the start restarts the track, it
        // does not end playback.
        #expect(QueueReducer.reduce(Self.queue(count: 4, at: 0), .previous).currentIndex == 0)
    }

    @Test("Previous at the head with repeat-all wraps to the end")
    func previousAtHeadWraps() {
        var state = Self.queue(count: 4, at: 0)
        state.repeatMode = .all
        #expect(QueueReducer.reduce(state, .previous).currentIndex == 3)
    }

    // MARK: - shuffle / repeat

    @Test("Toggling shuffle preserves the playing track's identity")
    func shufflePreservesCurrentTrack() {
        let before = Self.queue(count: 5, at: 2)
        let after = QueueReducer.reduce(before, .toggleShuffle)
        #expect(after.shuffleEnabled)
        #expect(after.currentTrack == before.currentTrack)
    }

    @Test("Repeat cycles off → all → one → off")
    func repeatCycles() {
        var state = Self.queue(count: 3, at: 0)
        #expect(state.repeatMode == .off)
        state = QueueReducer.reduce(state, .cycleRepeat)
        #expect(state.repeatMode == .all)
        state = QueueReducer.reduce(state, .cycleRepeat)
        #expect(state.repeatMode == .one)
        state = QueueReducer.reduce(state, .cycleRepeat)
        #expect(state.repeatMode == .off)
    }

    // MARK: - upNext

    @Test("Up-next lists only what follows the cursor")
    func upNextFollowsCursor() {
        let state = Self.queue(count: 5, at: 1)
        #expect(state.upNext.map(\.id) == ["t2", "t3", "t4"])
    }

    @Test("Up-next is empty on the last track")
    func upNextEmptyAtEnd() {
        #expect(Self.queue(count: 3, at: 2).upNext.isEmpty)
    }

    // MARK: - The invariant, swept over every action

    @Test("No single action can produce an out-of-range cursor")
    func everyActionPreservesConsistency() {
        let actions: [QueueAction] = [
            .setQueue((0..<4).map(Self.track), startingAt: 2),
            .setQueue([], startingAt: 0),
            .jump(to: 0), .jump(to: 3), .jump(to: 99), .jump(to: -1),
            .remove(at: 0), .remove(at: 2), .remove(at: 99), .remove(at: -1),
            .clearUpNext, .next, .previous, .toggleShuffle, .cycleRepeat,
        ]
        let starts: [QueueState] = [
            QueueState(),
            Self.queue(count: 1, at: 0),
            Self.queue(count: 4, at: 0),
            Self.queue(count: 4, at: 3),
            Self.queue(count: 4, at: nil),
        ]

        for start in starts {
            for action in actions {
                let result = QueueReducer.reduce(start, action)
                #expect(result.isConsistent, "\(action) broke the cursor invariant")
            }
        }
    }

    @Test("Long action sequences never break the cursor invariant")
    func sequencesPreserveConsistency() {
        // A light property check: walk a deterministic pseudo-random action
        // sequence and assert the invariant after every single step. Catches
        // interactions that per-action tests miss — e.g. remove-then-next at
        // a boundary.
        var state = Self.queue(count: 6, at: 0)
        var seed = 1
        let actions: [QueueAction] = [
            .next, .remove(at: 0), .previous, .clearUpNext, .cycleRepeat,
            .next, .jump(to: 1), .remove(at: 1), .toggleShuffle, .next,
        ]

        for step in 0..<200 {
            seed = (seed &* 1103515245 &+ 12345) & 0x7FFF_FFFF
            let action = actions[seed % actions.count]
            state = QueueReducer.reduce(state, action)
            #expect(state.isConsistent, "step \(step): \(action) broke the invariant")
        }
    }
}
