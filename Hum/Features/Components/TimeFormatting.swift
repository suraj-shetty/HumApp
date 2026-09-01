import Foundation

extension TimeInterval {
    /// `3:42` — the compact form used on rows and the progress bar.
    ///
    /// Hand-built rather than `DateComponentsFormatter` on purpose: this runs
    /// once per visible row per update, and the formatter allocates. Negative
    /// and non-finite values clamp to zero so a mid-seek `NaN` cannot render
    /// as `-1:-30`.
    var humTimestamp: String {
        guard isFinite, self > 0 else { return "0:00" }
        let total = Int(self.rounded())
        let minutes = total / 60
        let seconds = total % 60
        return "\(minutes):\(seconds < 10 ? "0" : "")\(seconds)"
    }

    /// `-1:18` — the remaining-time label on Now Playing.
    var humRemaining: String {
        "-" + humTimestamp
    }

    /// "3 minutes 42 seconds" — VoiceOver reads this instead of "3:42", which
    /// it would otherwise pronounce as a ratio.
    var humSpokenDuration: String {
        guard isFinite, self > 0 else { return "unknown duration" }
        let total = Int(self.rounded())
        let minutes = total / 60
        let seconds = total % 60
        var parts: [String] = []
        if minutes > 0 { parts.append("\(minutes) minute\(minutes == 1 ? "" : "s")") }
        if seconds > 0 { parts.append("\(seconds) second\(seconds == 1 ? "" : "s")") }
        return parts.isEmpty ? "0 seconds" : parts.joined(separator: " ")
    }
}
