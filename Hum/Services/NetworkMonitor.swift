import Foundation
import Network
import Observation

/// Real network reachability — `Network` framework, not MusicKit; nothing
/// here is under the containment script's MusicKit restriction. Backs
/// Home's offline banner and downloaded-only shelf (design screen 11).
@MainActor
@Observable
final class NetworkMonitor {
    private(set) var isOffline = false

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "org.surajshetty.humapp.network-monitor")

    init() {
        #if DEBUG
        // The Simulator shares the host Mac's own network, which this
        // session has no way to actually disconnect — the same gap the
        // audit's own B-1/B-2 notes hit for other unreachable states. A
        // launch argument forces the banner and downloaded shelf for real
        // verification instead of leaving them uncapturable.
        if UserDefaults.standard.bool(forKey: "HumForceOffline") {
            isOffline = true
            return
        }
        #endif

        monitor.pathUpdateHandler = { [weak self] path in
            let offline = path.status != .satisfied
            Task { @MainActor in
                self?.isOffline = offline
            }
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }
}
