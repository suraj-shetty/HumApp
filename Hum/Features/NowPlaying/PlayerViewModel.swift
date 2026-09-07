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

    /// The snapshot is stored *split apart* rather than whole, and this is
    /// load-bearing rather than stylistic. `@Observable` tracks the stored
    /// properties a view actually reads, so a single `snapshot` property makes
    /// every consumer a progress observer: the player bar, which wants only
    /// the track and whether it is playing, would be invalidated four times a
    /// second — taking the whole `TabView` around it with it, and visibly
    /// churning the accessory. Split, the bar re-renders on real changes only.
    private(set) var state: PlaybackState = .idle
    private(set) var elapsed: TimeInterval = 0
    private(set) var duration: TimeInterval = 0
    private(set) var queue = QueueState()
    /// Design screen 39's read-only alternative — see `HumAudioVariant`'s
    /// own doc for why this is a badge naming what's playing, not a picker
    /// choosing it.
    private(set) var audioVariant: HumAudioVariant?
    private(set) var subscription: SubscriptionState = .unknown
    /// Set when a play intent hits a subscription gap Apple *can* close;
    /// drives Apple's own offer sheet.
    var isPresentingSubscriptionOffer = false
    /// Set when the gap is one an offer cannot close — the account cannot
    /// subscribe, or the check itself failed. Drives `SubscriptionGapView`.
    var isPresentingSubscriptionGap = false
    /// Transient message shown as a toast — the only chrome-glass content view.
    private(set) var toast: ToastMessage?
    /// Design screen 29's full-screen "Playback stopped" — see `perform`'s
    /// doc comment for what actually triggers this.
    var isShowingConnectionLost = false
    private(set) var retryConnectionLost: (() -> Void)?
    private var consecutiveFailures = 0
    private static let connectionLostThreshold = 2

    /// Tracks the listener has added to their library this session, so the
    /// Now Playing action can render its filled state without a round trip.
    private(set) var addedToLibrary: Set<String> = []
    /// Tracks an add that's in flight but hasn't confirmed yet — separate
    /// from `addedToLibrary` so a double-tap before the first request
    /// completes doesn't fire a second one for the same track.
    private var addingToLibrary: Set<String> = []

    // MARK: - Derived

    // `state.track` is nil during `.loading` — MusicKit's own state has no
    // "buffering" case, so the adapter infers it from an in-flight request,
    // and that inference carries no track. The queue's cursor is already set
    // by then (`play()` sets it before the adapter call), so falling back to
    // it is what keeps Now Playing showing the right track — art, title,
    // artist — through the buffering window instead of reading as "nothing
    // playing" (design screen 24). `.idle` needs no special case here: it's
    // only ever reached when the queue has no current track either.
    var currentTrack: HumTrack? { state.track ?? queue.currentTrack }
    var isPlaying: Bool { state.isPlaying }
    var isBuffering: Bool { if case .loading = state { true } else { false } }
    var upNext: [HumTrack] { queue.upNext }

    /// 0…1, clamped. Guards against a zero-duration track producing `NaN` and
    /// a progress bar of infinite width.
    var progress: Double {
        guard duration > 0 else { return 0 }
        return min(max(elapsed / duration, 0), 1)
    }

    var remaining: TimeInterval {
        max(0, duration - elapsed)
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
    private var subscriptionTask: Task<Void, Never>?
    private var toastTask: Task<Void, Never>?

    /// The play intent the subscription gate turned back, kept so it can be
    /// resumed if the listener subscribes — through our offer sheet or in the
    /// Music app — without making them find the track again.
    private var deferredIntent: (tracks: [HumTrack], index: Int, source: String)?

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
                self.adopt(snapshot)
            }
        }

        // A subscription can begin *while Hum is open* — through the offer
        // sheet, or in the Music app. Without this the listener would have to
        // relaunch before catalog playback started working, which reads as the
        // app ignoring a purchase they just made.
        subscriptionTask = Task { [weak self, subscriptionService] in
            for await state in subscriptionService.updates {
                guard let self, !Task.isCancelled else { return }
                self.apply(state)
            }
        }
    }

    /// Assignment is guarded per field: under `@Observable`, writing a value
    /// equal to the one already there still notifies. Only `elapsed` changes on
    /// a routine tick, so only progress-reading views should wake up for one.
    private func adopt(_ snapshot: PlaybackSnapshot) {
        if state != snapshot.state { state = snapshot.state }
        if elapsed != snapshot.elapsed { elapsed = snapshot.elapsed }
        if duration != snapshot.duration { duration = snapshot.duration }
        if queue != snapshot.queue { queue = snapshot.queue }
        if audioVariant != snapshot.audioVariant { audioVariant = snapshot.audioVariant }
    }

    func stop() {
        observationTask?.cancel()
        observationTask = nil
        subscriptionTask?.cancel()
        subscriptionTask = nil
        toastTask?.cancel()
        toastTask = nil
    }

    private func refreshSubscription() async {
        apply(await subscriptionService.current)
    }

    /// Adopts a new subscription state and resumes a turned-back play intent
    /// if the gap has closed.
    private func apply(_ state: SubscriptionState) {
        subscription = state
        guard case .active = state, let intent = deferredIntent else { return }
        deferredIntent = nil
        isPresentingSubscriptionOffer = false
        isPresentingSubscriptionGap = false
        play(intent.tracks, startingAt: intent.index, source: intent.source)
    }

    /// Re-runs the check after a failed one. Backs `SubscriptionGapView`'s
    /// "Try Again".
    func retrySubscriptionCheck() {
        Task { await refreshSubscription() }
    }

    /// Apple's offer sheet failed to load. Reported plainly rather than left
    /// as a control that visibly does nothing.
    func subscriptionOfferFailed(_ reason: String) {
        showToast("Couldn't open Apple Music sign-up.", kind: .error)
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
            Task {
                await perform(
                    { try await self.playback.play(tracks, startingAt: index) },
                    onSuccess: { [weak self] in self?.recordPlaybackStart() }
                )
            }

        case .presentSubscriptionOffer:
            deferredIntent = (tracks, index, source)
            isPresentingSubscriptionOffer = true

        case .explainNoSubscription:
            deferredIntent = (tracks, index, source)
            isPresentingSubscriptionGap = true

        case .awaitSubscriptionCheck:
            // Resolve the status, then retry once. Never guess — "not checked
            // yet" must not render as "you have no subscription".
            Task {
                subscription = await subscriptionService.current
                if case .unknown = subscription {
                    showToast("Couldn't check your Apple Music subscription.", kind: .error)
                } else {
                    play(tracks, startingAt: index, source: source)
                }
            }
        }
    }

    // MARK: - Recently played sync hint

    private static let lastPlaybackStartedKey = "HumLastPlaybackStartedAt"

    private func recordPlaybackStart() {
        UserDefaults.standard.set(Date(), forKey: Self.lastPlaybackStartedKey)
    }

    /// `MusicRecentlyPlayedContainerRequest` reads Apple's own server-side
    /// history, which is not updated the instant playback starts — a listener
    /// who plays something and immediately force-quits can relaunch to find
    /// Apple hasn't scrobbled it yet. This distinguishes that case from
    /// genuinely never having played anything, so Home's empty state can say
    /// "still syncing" instead of the wrong "nothing here yet".
    var recentlyPlayedMaySyncSoon: Bool {
        guard let last = UserDefaults.standard.object(forKey: Self.lastPlaybackStartedKey) as? Date else {
            return false
        }
        return Date().timeIntervalSince(last) < 15 * 60
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
        guard duration > 0 else { return }
        let target = min(max(fraction, 0), 1) * duration
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

    /// The track context menu's "Play Next" / "Add to Queue" (design screen
    /// 31). A neutral toast confirms each — there's no other feedback for a
    /// queue change that doesn't touch what's currently playing.
    func playNext(_ track: HumTrack) {
        applyQueue(.playNext(track))
        showToast("Playing next", kind: .neutral)
    }

    func addToQueue(_ track: HumTrack) {
        applyQueue(.appendToQueue(track))
        showToast("Added to queue", kind: .neutral)
    }

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
        let next = QueueReducer.reduce(queue, action)
        guard next != queue else { return }
        // Adopted immediately rather than waiting for the round trip's
        // snapshot: `queue` is what the next `applyQueue` reduces from, so
        // two edits fired in quick succession (e.g. removing two rows before
        // the first confirms) would otherwise both reduce from the same
        // pre-edit queue and the second would overwrite the first's change.
        // If the round trip itself fails, the adapter rolls its own mirror
        // back and republishes, which corrects this back through `adopt(_:)`.
        queue = next
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
        guard !addedToLibrary.contains(track.id), !addingToLibrary.contains(track.id) else { return }
        addingToLibrary.insert(track.id)
        Task {
            defer { addingToLibrary.remove(track.id) }
            do {
                try await libraryService.add(track)
                addedToLibrary.insert(track.id)
                showToast("Added to your library")
            } catch {
                showToast("Couldn't add to your library", kind: .error) { [weak self] in
                    self?.addedToLibrary.remove(track.id)
                    self?.addToLibrary(track)
                }
            }
        }
    }

    // MARK: - Helpers

    private func perform(_ work: @escaping () async throws -> Void, onSuccess: (() -> Void)? = nil) async {
        do {
            try await work()
            consecutiveFailures = 0
            onSuccess?()
        } catch {
            consecutiveFailures += 1
            // MusicKit gives this app no signal that distinguishes "lost the
            // connection to Apple Music" from an ordinary single command
            // failing — design screen 29's full-screen "Playback stopped" is
            // for the former, and the toast-with-retry above is for the
            // latter. Two failures in a row, with nothing succeeding between
            // them, is the closest honest proxy this codebase has: still a
            // heuristic, not a real status read, which is why it's spelled
            // out here rather than left implicit.
            guard consecutiveFailures >= Self.connectionLostThreshold else {
                showToast("Playback failed.", kind: .error) { [weak self] in
                    guard let self else { return }
                    Task { await self.perform(work) }
                }
                return
            }
            // The cover is already up over an earlier failure — leave its
            // retry target alone. Overwriting it here would mean tapping
            // "Try Again" retries whatever unrelated command failed twice
            // most recently, not the one the listener is looking at.
            guard !isShowingConnectionLost else { return }
            consecutiveFailures = 0
            retryConnectionLost = { [weak self] in
                guard let self else { return }
                Task { await self.perform(work) }
            }
            isShowingConnectionLost = true
        }
    }

    func showToast(_ message: String, kind: ToastMessage.Kind = .success, onRetry: (() -> Void)? = nil) {
        toast = ToastMessage(text: message, kind: kind, onRetry: onRetry)
        toastTask?.cancel()
        toastTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            self?.toast = nil
        }
    }
}

/// A toast's content, decoupled from `ToastView` so the view model doesn't
/// import SwiftUI's view layer. `onRetry` is excluded from equality — the
/// player bar only needs to know the *message* changed to re-animate.
struct ToastMessage: Equatable {
    enum Kind {
        case success, error, neutral
    }

    let text: String
    var kind: Kind = .success
    var onRetry: (() -> Void)?

    static func == (lhs: ToastMessage, rhs: ToastMessage) -> Bool {
        lhs.text == rhs.text && lhs.kind == rhs.kind
    }
}

extension Array {
    /// Bounds-checked subscript. Queue indices can go stale between a tap and
    /// its handler when the queue mutates concurrently.
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
