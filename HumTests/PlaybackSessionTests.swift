import Observation
import Testing
@testable import Hum

/// Phase 5. `QueueReducerTests` proves the queue arithmetic; this suite proves
/// the *session* wiring around it — that every queue intent reduces first and
/// is then mirrored onto the player exactly once, that transport intents map
/// one-to-one onto the standard MusicKit controls, and that a reduction which
/// changes nothing never reaches the player at all.
///
/// The adapter itself (`ApplicationMusicPlayerAdapter`) is not testable here:
/// it needs a device, an account, and audio hardware. What *is* testable is
/// everything that decides what the adapter is asked to do — which is the
/// reason the decision was kept out of the adapter in the first place.
@MainActor
@Suite("Playback session")
struct PlaybackSessionTests {

    private func model() -> (PlayerViewModel, FakePlaybackService) {
        let playback = FakePlaybackService()
        let environment = AppEnvironment(
            authorization: FakeAuthorizationService(status: .authorized),
            subscription: FakeSubscriptionService(state: .active),
            catalog: FakeCatalogService(),
            library: FakeLibraryService(),
            playback: playback
        )
        return (PlayerViewModel(environment: environment), playback)
    }

    private nonisolated static func track(_ id: String) -> HumTrack {
        HumTrack(id: id, title: id, artist: "Ana Roele", duration: 200, source: .library)
    }

    private static let tracks = ["a", "b", "c"].map(track)

    /// Puts the view model in the state the real adapter would leave it in
    /// after a play: three entries, cursor on the first.
    private func started(
        at index: Int = 0
    ) async throws -> (PlayerViewModel, FakePlaybackService) {
        let (sut, playback) = model()
        sut.start()
        await playback.emit(
            PlaybackSnapshot(
                state: .playing(Self.tracks[index]),
                elapsed: 0,
                duration: 200,
                queue: QueueState(entries: Self.tracks, currentIndex: index)
            )
        )
        try await Task.sleep(for: .milliseconds(50))
        return (sut, playback)
    }

    // MARK: - Observation
    //
    // The player bar reads the track and whether it is playing, and nothing
    // else. If those reads also track progress, every tick invalidates the
    // bar — and the `TabView` hosting it — four times a second, which is
    // visible on device as a flickering accessory.

    /// Records whether `@Observable` woke a reader.
    private final class Invalidation: @unchecked Sendable {
        var fired = false
    }

    @Test("A progress tick does not invalidate a view that only reads the track")
    func progressDoesNotInvalidateTrackReaders() async throws {
        let (sut, playback) = try await started()

        let invalidation = Invalidation()
        withObservationTracking {
            // Exactly what `PlayerBar` reads.
            _ = sut.currentTrack
            _ = sut.isPlaying
        } onChange: {
            invalidation.fired = true
        }

        await playback.emit(
            PlaybackSnapshot(
                state: .playing(Self.tracks[0]),
                elapsed: 12,
                duration: 200,
                queue: QueueState(entries: Self.tracks, currentIndex: 0)
            )
        )
        try await Task.sleep(for: .milliseconds(50))

        #expect(!invalidation.fired)
    }

    @Test("A real change still invalidates it")
    func trackChangeInvalidatesTrackReaders() async throws {
        let (sut, playback) = try await started()

        let invalidation = Invalidation()
        withObservationTracking {
            _ = sut.currentTrack
            _ = sut.isPlaying
        } onChange: {
            invalidation.fired = true
        }

        await playback.emit(
            PlaybackSnapshot(
                state: .playing(Self.tracks[1]),
                elapsed: 0,
                duration: 200,
                queue: QueueState(entries: Self.tracks, currentIndex: 1)
            )
        )
        try await Task.sleep(for: .milliseconds(50))

        #expect(invalidation.fired)
    }

    // MARK: - Transport

    @Test("Transport intents map one-to-one onto standard controls")
    func transportIntents() async throws {
        let (sut, playback) = try await started()

        sut.togglePlayPause()          // currently playing → pause
        try await Task.sleep(for: .milliseconds(30))
        sut.skipToNext()
        sut.skipToPrevious()
        try await Task.sleep(for: .milliseconds(50))

        #expect(await playback.calls == [.pause, .skipToNext, .skipToPrevious])
    }

    @Test("Seeking converts a fraction of the bar into a time on the track")
    func seekConvertsFraction() async throws {
        let (sut, playback) = try await started()

        sut.seek(toFraction: 0.25)
        try await Task.sleep(for: .milliseconds(50))

        #expect(await playback.calls == [.seek(50)])
    }

    @Test("A seek past either end of the bar is clamped, never negative")
    func seekIsClamped() async throws {
        let (sut, playback) = try await started()

        sut.seek(toFraction: -3)
        sut.seek(toFraction: 4)
        try await Task.sleep(for: .milliseconds(50))

        #expect(await playback.calls == [.seek(0), .seek(200)])
    }

    // MARK: - Queue

    @Test("Removing an up-next entry mirrors the reduced queue onto the player")
    func removeMirrors() async throws {
        let (sut, playback) = try await started()

        sut.remove(at: 2)
        try await Task.sleep(for: .milliseconds(50))

        #expect(await playback.calls == [.applyQueue(trackIDs: ["a", "b"])])
    }

    @Test("Clearing up next keeps the current track, so the audio survives it")
    func clearKeepsCurrent() async throws {
        let (sut, playback) = try await started(at: 1)

        sut.clearUpNext()
        try await Task.sleep(for: .milliseconds(50))

        #expect(await playback.calls == [.applyQueue(trackIDs: ["a", "b"])])
    }

    @Test("A reduction that changes nothing never reaches the player")
    func noOpIntentsAreDropped() async throws {
        let (sut, playback) = try await started()

        // Both are out of range for a three-entry queue: the reducer returns
        // the state unchanged, and a mirror call would be pure churn — a real
        // queue rebuild on the player for no change at all.
        sut.jump(to: 9)
        sut.remove(at: -1)
        try await Task.sleep(for: .milliseconds(50))

        #expect(await playback.calls.isEmpty)
    }

    @Test("Shuffle and repeat move only the flags, never the entries")
    func modesLeaveEntriesAlone() async throws {
        let (sut, playback) = try await started()

        sut.toggleShuffle()
        try await Task.sleep(for: .milliseconds(30))
        sut.cycleRepeat()
        try await Task.sleep(for: .milliseconds(50))

        // Order is the *player's* to change, via its own shuffle mode. Hum
        // reordering the entries too would double-shuffle and lose the
        // listener's place.
        #expect(
            await playback.calls == [
                .applyQueue(trackIDs: ["a", "b", "c"]),
                .applyQueue(trackIDs: ["a", "b", "c"]),
            ]
        )
    }

    @Test("Refilling a cleared queue restores the collection around the current track")
    func refillRestoresSource() async throws {
        let (sut, playback) = model()
        sut.start()
        sut.play(Self.tracks, startingAt: 1, source: "Longer Evenings")
        try await Task.sleep(for: .milliseconds(50))

        // The queue has been cleared down to the playing track.
        await playback.emit(
            PlaybackSnapshot(
                state: .playing(Self.tracks[1]),
                elapsed: 12,
                duration: 200,
                queue: QueueState(entries: Array(Self.tracks[0...1]), currentIndex: 1)
            )
        )
        try await Task.sleep(for: .milliseconds(50))

        sut.refillFromCurrentSource()
        try await Task.sleep(for: .milliseconds(50))

        #expect(
            await playback.calls == [
                .play(trackIDs: ["a", "b", "c"], startingAt: 1),
                .applyQueue(trackIDs: ["a", "b", "c"]),
            ]
        )
    }
}
