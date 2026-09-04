import SwiftUI

/// Board 03: "True black ground, not onyx — OLED pixels stay off. Amber
/// holds at #E8A33D; no glass, no blur, no gradient chrome at this size."
/// Everything else reuses `Palette`'s existing amber/terracotta tokens
/// unchanged — only the ground differs from iPhone/iPad.
enum WatchPalette {
    static let ground = Color.black
}
