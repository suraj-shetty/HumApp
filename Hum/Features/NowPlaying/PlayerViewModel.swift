import Observation
import SwiftUI

/// Owns playback and queue state for the whole app.
///
/// One instance, injected at the root, shared by the player bar, Now Playing,
/// and Queue — they are three views onto one session, not three sessions.
///
/// Note what this type does *not* do: it never touches `ApplicationMusicPlayer`
/// and never imports MusicKit. It decides using `QueueReducer` and
/// `SubscriptionReducer` — both pure and already tested — then hands the result
/// to `PlaybackService`. That split is why queue behaviour is provable without
/// a device.
@MainActor
@Observable
final class PlayerViewModel {

    // MARK: - Published state

    private(set) var snapshot: PlaybackSnapshot = .idle
    private(set) var subscription: SubscriptionState = .unknown
    /// Set when a play intent hits a subscription gap; drives Apple's offer sheet.
    var isPresentingSubscriptionOffer = false
    /// Transient message shown as a toast — the only chrome-glass content view.
    private(set) var toast: String?

    /// Tracks the listener has added to their library this session, so the
    /// Now Playing action can render its filled state without a round trip.
    private(set) var addedToLibrary: Set<String> = []

    // MARK: - Derived

    var currentTrack: HumTrack? { snapshot.state.track }
    var isPlaying: Bool { snapshot.state.isPlaying }
    var queue: QueueState { snapshot.queue }
    var upNext: [HumTrack] { snapshot.queue.upNext }

    /// 0…1, clamped. Guards against a zero-duration track producing `NaN` and
    /// a progress bar of infinite width.
    var progress: Double {
        guard snapshot.duration > 0 else { return 0 }
        return min(max(snapshot.elapsed / snapshot.duration, 0), 1)
    }

    var remaining: TimeInterval {
        max(0, snapshot.duration - snapshot.elapsed)
    }

    /// Where playback is coming from — the Now Playing overline.
    private(set) var sourceLabel: String = ""
    /// The full track list the current session was started from, kept so the
    /// Queue screen's "Fill from this album" can restore a cleared queue
    /// without re-fetching.
    private var sourceTracks: [HumTrack] = []

    // MARK: - Dependencies

    private let playback: PlaybackService
    private let subscriptionService: SubscriptionService
    private let libraryService: MusicLibraryService
    private var observationTask: Task<Void, Never>?
    private var toastTask: Task<Void, Never>?

    init(environment: AppEnvironment) {
        self.playback = environment.playback
        self.subscriptionService = environment.subscription
        self.libraryService = environment.library
    }

    // No `deinit` cancellation: a `@MainActor` class's `deinit` is nonisolated
    // and cannot touch these properties under Swift 6. Cancellation is handled
    // by `stop()` from the view lifecycle, and every task below captures `self`
    // weakly so nothing keeps this object alive on its own.

    // MARK: - Lifecycle

    /// Starts observing the player. Idempotent — safe to call from `.task`,
    /// which can run more than once across a view's lifetime.
    func start() {
        guard observationTask == nil else { return }
        subscription = .unknown

        // `playback` is captured directly rather than through `self`: a
        // `guard let self` outside the loop would hold a strong reference for
        // the stream's entire lifetime, which is forever, and the view model
        // would never deallocate.
        observationTask = Task { [weak self, playback] in
            await self?.refreshSubscription()
            for await snapshot in playback.snapshots {
                guard let self, !Task.isCancelled else { return }
                self.snapshot = snapshot
            }
        }
    }

    func stop() {
        observationTask?.cancel()
        observationTask = nil
        toastTask?.cancel()
        toastTask = nil
    }

    private func refreshSubscription() async {
        subscription = await subscriptionService.current
    }

    // MARK: - Intents

    /// The single entry point for starting playback.
    ///
    /// Every play in the app routes through here so the subscription gate
    /// cannot be bypassed. `SubscriptionReducer.resolve` decides; a `.gap`
    /// state can never reach `PlaybackService.play`.
    func play(_ tracks: [HumTrack], startingAt index: Int = 0, source: String) {
        guard let first = tracks[safe: index] else { return }

        switch SubscriptionReducer.resolve(first.source, in: subscription) {
        case .play:
            sourceLabel = source
            sourceTracks = tracks
            Task { await perform { try await self.playback.play(tracks, startingAt: index) } }

        case .presentSubscriptionOffer:
            isPresentingSubscriptionOffer = true

        case .explainNoSubscription:
            showToast("An Apple Music subscription is needed to play this.")

        case .awaitSubscriptionCheck:
            // Resolve the status, then retry once. Never guess — "not checked
            // yet" must not render as "you have no subscription".
            Task {
                await refreshSubscription()
                if case .unknown = subscription {
                    showToast("Couldn't check your Apple Music subscription.")
                } else {
                    play(tracks, startingAt: index, source: source)
                }
            }
        }
    }

    func togglePlayPause() {
        Task {
            if isPlaying {
                await playback.pause()
            } else {
                await perform { try await self.playback.resume() }
            }
        }
    }

    func skipToNext() {
        Task { await perform { try await self.playback.skipToNext() } }
    }

    func skipToPrevious() {
        Task { await perform { try await self.playback.skipToPrevious() } }
    }

    func seek(toFraction fraction: Double) {
        guard snapshot.duration > 0 else { return }
        let target = min(max(fraction, 0), 1) * snapshot.duration
        Task { await playback.seek(to: target) }
    }

    // MARK: - Queue intents
    //
    // Each one reduces purely, then mirrors the result onto the player.

    func jump(to index: Int) { applyQueue(.jump(to: index)) }
    func remove(at index: Int) { applyQueue(.remove(at: index)) }
    func clearUpNext() { applyQueue(.clearUpNext) }
    func toggleShuffle() { applyQueue(.toggleShuffle) }
    func cycleRepeat() { applyQueue(.cycleRepeat) }

    /// Replaces the queue wholesale — used by drag-to-reorder, where the new
    /// order is computed by the list rather than expressible as a single
    /// `QueueAction`. Still routed through the reducer so the cursor
    /// invariant is enforced by the same code path as everything else.
    func replaceQueue(_ entries: [HumTrack], currentIndex: Int) {
        applyQueue(.setQueue(entries, startingAt: currentIndex))
    }

    /// Restores a cleared queue from the collection playback started with.
    func refillFromCurrentSource() {
        guard !sourceTracks.isEmpty,
              let current = currentTrack,
              let index = sourceTracks.firstIndex(where: { $0.id == current.id })
        else { return }
        applyQueue(.setQueue(sourceTracks, startingAt: index))
    }

    private func applyQueue(_ action: QueueAction) {
        let next = QueueReducer.reduce(snapshot.queue, action)
        guard next != snapshot.queue else { return }
        Task { await perform { try await self.playback.applyQueue(next) } }
    }

    // MARK: - Library

    func isInLibrary(_ track: HumTrack) -> Bool {
        addedToLibrary.contains(track.id)
    }

    /// Backs the action the prototype draws as a heart. MusicKit has no
    /// love/favorite API, so this adds to the library — a real capability
    /// (DECISIONS M-04).
    func addToLibrary(_ track: HumTrack) {
        guard !addedToLibrary.contains(track.id) else { return }
        Task {
            do {
                try await libraryService.add(track)
                addedToLibrary.insert(track.id)
                showToast("Added to your library")
            } catch {
                showToast("Couldn't add to your library")
            }
        }
    }

    // MARK: - Helpers

    private func perform(_ work: @escaping () async throws -> Void) async {
        do {
            try await work()
        } catch {
            showToast("Playback failed. Try again.")
        }
    }

    func showToast(_ message: String) {
        toast = message
        toastTask?.cancel()
        toastTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            self?.toast = nil
        }
    }
}

extension Array {
    /// Bounds-checked subscript. Queue indices can go stale between a tap and
    /// its handler when the queue mutates concurrently.
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
