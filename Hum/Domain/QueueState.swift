enum RepeatMode: Sendable, Equatable, CaseIterable, Codable {
    case off
    case all
    case one

    /// The prototype's repeat button cycles rather than toggles.
    var next: RepeatMode {
        switch self {
        case .off: .all
        case .all: .one
        case .one: .off
        }
    }
}

/// The playback queue.
///
/// `currentIndex == nil` means nothing is cued — the queue is either empty or
/// has run off its end with repeat off. It is *not* the same as being paused.
struct QueueState: Sendable, Equatable, Codable {
    var entries: [HumTrack] = []
    var currentIndex: Int?
    var shuffleEnabled: Bool = false
    var repeatMode: RepeatMode = .off

    var currentTrack: HumTrack? {
        guard let currentIndex, entries.indices.contains(currentIndex) else { return nil }
        return entries[currentIndex]
    }

    /// What the Queue screen lists under "Up next", and what the player bar
    /// counts. Empty when the current track is the last one.
    var upNext: [HumTrack] {
        guard let currentIndex, entries.indices.contains(currentIndex) else { return [] }
        return Array(entries[(currentIndex + 1)...])
    }

    /// The invariant every `QueueReducer` case must preserve: `currentIndex` is
    /// either `nil` or a valid subscript into `entries`. Asserted after every
    /// reduction in `QueueReducerTests`.
    var isConsistent: Bool {
        guard let currentIndex else { return true }
        return entries.indices.contains(currentIndex)
    }
}
