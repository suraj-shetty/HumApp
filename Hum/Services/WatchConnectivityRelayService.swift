import Foundation
import Observation
import WatchConnectivity

/// Board 03, Section 03 — Apple Watch relays through the paired iPhone
/// rather than talking to MusicKit independently (the architecture question
/// the board itself left open, resolved this way per the revision prompt).
///
/// This file imports `WatchConnectivity`, not `MusicKit` — it never touches
/// `ApplicationMusicPlayer` directly. It only republishes
/// `PlayerViewModel`'s existing state to the watch and calls
/// `PlayerViewModel`'s existing methods when the watch asks for a transport
/// change, so `Scripts/check-containment.sh`'s "MusicKit only in
/// Services/Adapters" rule holds unmodified — there's no new playback logic
/// here, only a new transport for commands and state that already exist.
@MainActor
final class WatchConnectivityRelayService: NSObject {
    private let player: PlayerViewModel
    private var session: WCSession?
    /// Reused rather than constructed per `publish()` call — this can fire
    /// several times a second during active transport changes.
    private static let encoder = JSONEncoder()

    init(player: PlayerViewModel) {
        self.player = player
        super.init()
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
        self.session = session
        observe()
    }

    /// Republishes on every change to the fields the watch actually renders.
    /// `elapsed` is deliberately excluded — it ticks ~4Hz
    /// (`PlaybackService`'s own doc comment), and pushing a WatchConnectivity
    /// context that often would be wasted work for a value the watch can
    /// interpolate locally from `isPlaying` + the elapsed it already has.
    private func observe() {
        withObservationTracking {
            _ = player.currentTrack?.id
            _ = player.isPlaying
            _ = player.isBuffering
            _ = player.audioVariant
            _ = player.upNext.count
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.publish()
                self?.observe()
            }
        }
    }

    /// Called after every `PlayerViewModel` change the relay cares about.
    /// `updateApplicationContext` rather than `sendMessage`: the watch app
    /// may not be foreground, and context delivery is exactly "the watch
    /// gets the latest state next time it's running" — no queueing, no
    /// backlog of stale snapshots to replay.
    func publish() {
        guard let session, session.activationState == .activated else { return }
        let payload = WatchPlaybackPayload(from: player)
        guard let data = try? Self.encoder.encode(payload) else { return }
        try? session.updateApplicationContext(["snapshot": data])
    }

    private func handle(_ command: WatchTransportCommand) {
        switch command {
        case .togglePlayPause: player.togglePlayPause()
        case .skipToNext: player.skipToNext()
        case .skipToPrevious: player.skipToPrevious()
        case .jump(let upNextIndex):
            // The watch only ever sees `upNext` (a slice, not
            // `QueueState.entries`), so it sends an index relative to that
            // slice — the same shape `QueueView.upNextRows` starts from on
            // the phone. This is the one place with the current-track
            // context (`player.queue.currentIndex`) needed to turn that
            // into the absolute index `PlayerViewModel.jump(to:)` expects.
            let base = (player.queue.currentIndex ?? -1) + 1
            player.jump(to: base + upNextIndex)
        }
    }
}

private extension WatchPlaybackPayload {
    /// Board 03's Watch screens show at most a handful of Up Next rows —
    /// there's no scroll-to-load-more affordance on the crown-and-one-thumb
    /// screen, so the relay doesn't send the whole queue. Lives here, not in
    /// `Domain/`, because it reads `PlayerViewModel`, which is iPhone-only —
    /// `Domain/WatchPlaybackPayload.swift` itself is compiled into `HumWatch`
    /// too (`project.yml`), and that target never sees `PlayerViewModel`.
    private static var upNextLimit: Int { 10 }

    @MainActor
    init(from player: PlayerViewModel) {
        self.init(
            currentTrack: player.currentTrack,
            isPlaying: player.isPlaying,
            isBuffering: player.isBuffering,
            elapsed: player.elapsed,
            duration: player.duration,
            audioVariantLabel: player.audioVariant?.badgeLabel,
            upNext: Array(player.upNext.prefix(Self.upNextLimit)),
            isInLibrary: player.currentTrack.map(player.isInLibrary) ?? false
        )
    }
}

extension WatchConnectivityRelayService: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in publish() }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated func sessionDidDeactivate(_ session: WCSession) { session.activate() }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        guard let raw = message["command"] as? Data,
              let command = try? JSONDecoder().decode(WatchTransportCommand.self, from: raw)
        else { return }
        Task { @MainActor in handle(command) }
    }
}
