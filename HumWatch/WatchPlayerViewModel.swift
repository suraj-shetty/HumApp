import Observation
import WatchConnectivity

/// The watch-side mirror of `PlayerViewModel`. It never touches playback
/// directly — every action here sends a `WatchTransportCommand` to the
/// paired iPhone and waits for the next relayed `WatchPlaybackPayload` to
/// reflect it, the same relay-not-independent-playback decision Board 03's
/// revision settled (`Hum/Services/WatchConnectivityRelayService.swift` is
/// the other half of this pair).
@MainActor
@Observable
final class WatchPlayerViewModel: NSObject {
    private(set) var payload: WatchPlaybackPayload = .idle
    /// `WCSession.isReachable` — Board 03's "Out of range" state. Not the
    /// same as "no session": a session can be activated but momentarily
    /// unreachable while still paired.
    private(set) var isOutOfRange = false

    private var session: WCSession?

    override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
        self.session = session
    }

    func togglePlayPause() { send(.togglePlayPause) }
    func skipToNext() { send(.skipToNext) }
    func skipToPrevious() { send(.skipToPrevious) }
    func jump(to index: Int) { send(.jump(index)) }

    private func send(_ command: WatchTransportCommand) {
        guard let session, let data = try? JSONEncoder().encode(command) else { return }
        session.sendMessage(["command": data], replyHandler: nil, errorHandler: nil)
    }
}

extension WatchPlayerViewModel: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        let reachable = session.isReachable
        Task { @MainActor in isOutOfRange = !reachable }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        let reachable = session.isReachable
        Task { @MainActor in isOutOfRange = !reachable }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        guard let data = applicationContext["snapshot"] as? Data,
              let decoded = try? JSONDecoder().decode(WatchPlaybackPayload.self, from: data)
        else { return }
        Task { @MainActor in payload = decoded }
    }
}
