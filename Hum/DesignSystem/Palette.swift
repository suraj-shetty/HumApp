import SwiftUI

/// "Amber Glow", transcribed from `designs/Hum Prototype.html`.
///
/// Every value here is extracted from the prototype rather than invented — see
/// docs/v1-musickit/DESIGN_SYSTEM.md §1 for the mapping.
enum Palette {

    // MARK: - Base

    /// `#0A0A0A` — the content base. Every opaque surface starts here.
    static let deepOnyx = Color(hex: 0x0A0A0A)
    /// `#E8A33D` — accent, artist names, active tint, progress fill, wordmark.
    static let honeyAmber = Color(hex: 0xE8A33D)
    /// `#F2B75C` — pressed/hover lift.
    static let honeyAmberLift = Color(hex: 0xF2B75C)

    /// Terracotta — the design's error colour, and the *only* one. Its absence
    /// is why destructive and failed states were previously drawn in the
    /// accent, which is the colour that means "yes" everywhere else.
    static let terracotta = Color(hex: 0xD2714A)
    /// The lighter warning step, for text on onyx where Terracotta is too dark.
    static let terracottaLift = Color(hex: 0xE29070)
    /// `#1C1A18` — raised chips (the Home avatar).
    /// Slate 900 — the design's plate colour, measured on the Home avatar.
    /// The same value as `artworkFill`; kept as its own name because one is a
    /// control's ground and the other is missing artwork.
    static let surfaceRaised = Color(hex: 0x1E1E20)
    /// `#141416` — the card fill under a block of content: Settings' grouped
    /// rows, Queue's now-playing card, the "Where to look" card on the denied
    /// screen. 22 occurrences in the design, always at this exact value —
    /// distinct from `surfaceRaised`, which is a control's ground, not a
    /// content card's.
    static let surfaceCard = Color(hex: 0x141416)

    // MARK: - Text ramp
    //
    // One scale, used consistently. White at four opacities.

    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.66)
    /// The design's workhorse dim text — durations, timecodes, tracked
    /// overlines, captions, metadata. By a wide margin the most-used colour in
    /// the prototype (133 occurrences of `rgba(255,255,255,.62)`; the next
    /// step up, `.66`, appears 24 times).
    ///
    /// It replaces a `textTertiary` at 52% and a `textQuaternary` at 40%, and
    /// the reason it replaces them is that **neither value exists in the
    /// design** — 52% occurs zero times and 40% once. They were transcription
    /// drift, not a tier.
    ///
    /// It also fixes the app's only contrast failure. At `#A2A2A2` on Deep
    /// Onyx this is **7.76:1** and passes AA and AAA; the 40% it supersedes
    /// measured 3.77:1 and failed AA on every duration in the app.
    static let textMuted = Color.white.opacity(0.62)
    static let iconInactive = Color.white.opacity(0.60)
    /// A disabled toolbar action's label — measured on Queue's "Clear" when
    /// the queue is empty. Not part of the four-step text ramp above: that
    /// ramp is for content at rest, this is one control's disabled state.
    static let textDisabled = Color.white.opacity(0.25)
    /// The tab bar's unselected glyph — measured white 68%, brighter than the
    /// general inactive icon because it sits on glass rather than on onyx.
    static let tabIconInactive = Color.white.opacity(0.68)
    /// The selected tab pill's fill — measured amber at 24%.
    static let tabSelection = Color(hex: 0xE8A33D, alpha: 0.24)
    /// Library filter chips — measured amber 16% on a 45% amber border when
    /// selected, flat `#161618` when not.
    static let chipSelectedFill = Color(hex: 0xE8A33D, alpha: 0.16)
    static let chipSelectedStroke = Color(hex: 0xE8A33D, alpha: 0.45)
    static let chipFill = Color(hex: 0x161618)

    // MARK: - Hairlines

    static let hairline = Color.white.opacity(0.07)
    static let hairlineStrong = Color.white.opacity(0.09)

    // MARK: - Artwork placeholders
    //
    // Shown while artwork loads and when a track has none. Warm-toned so a
    // missing image reads as intentional rather than broken.

    /// Slate 900 — the art plate, per the design's colour table.
    static let artworkFill = Color(hex: 0x1E1E20)
    static let artworkGradient = LinearGradient(
        colors: [Color(hex: 0x26241F), Color(hex: 0x16151A)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let artworkGradientWarm = LinearGradient(
        colors: [Color(hex: 0x332E26), Color(hex: 0x17161B)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: - Amber fills
    //
    // The accent is used at four strengths, deliberately. Chrome gets it as a
    // *tint* (the system desaturates and modulates it); content gets it as a
    // solid or a gradient at full strength. They will not look identical, and
    // that is correct.

    /// Primary action — Connect, album Play.
    static let amberButton = LinearGradient(
        colors: [Color(hex: 0xE8A33D, alpha: 0.26), Color(hex: 0xE8A33D, alpha: 0.12)],
        startPoint: .top,
        endPoint: .bottom
    )
    /// The 76pt transport play button — a touch stronger than `amberButton`.
    static let amberTransport = LinearGradient(
        colors: [Color(hex: 0xE8A33D, alpha: 0.30), Color(hex: 0xE8A33D, alpha: 0.13)],
        startPoint: .top,
        endPoint: .bottom
    )
    /// **Amber Glass** — the chrome tint. Every glass surface in the design
    /// carries it, which is what makes the chrome read as one family.
    ///
    /// The design measures 17% → 7% over a *transparent* backdrop-filter. The
    /// system's Liquid Glass already tints and darkens what it covers, so
    /// laying the measured value on top of it double-counts and reads brown
    /// rather than warm. Halved to match the design's **appearance**, which is
    /// what the value was expressing — checked side by side against the
    /// rendered board.
    static let amberGlassTint = LinearGradient(
        colors: [Color(hex: 0xE8A33D, alpha: 0.085), Color(hex: 0xE8A33D, alpha: 0.035)],
        startPoint: .top,
        endPoint: .bottom
    )
    /// The Reduce Transparency substitute for every glass surface: the design
    /// names it exactly — `#1C1A17` at 96%, with a 1px amber-tinted edge.
    /// Layout, tap targets and hierarchy are unchanged; only the material is.
    static let glassOpaqueFallback = Color(hex: 0x1C1A17, alpha: 0.96)
    static let glassOpaqueEdge = Color(hex: 0xE8A33D, alpha: 0.35)

    /// The hairline every glass surface carries, at 16%.
    static let glassHairline = Color.white.opacity(0.16)
    /// The 1pt inset highlight along a glass surface's top edge.
    static let glassTopHighlight = Color.white.opacity(0.2)

    static let amberOutlineFill = Color(hex: 0xE8A33D, alpha: 0.16)
    static let amberOutlineStroke = Color(hex: 0xE8A33D, alpha: 0.40)

    /// Secondary action — album Shuffle.
    static let neutralButtonFill = Color.white.opacity(0.07)
    static let neutralButtonStroke = Color.white.opacity(0.12)
    /// The inner top highlight that gives the capsules their lit edge.
    static let buttonInnerHighlight = Color.white.opacity(0.24)
    static let buttonStroke = Color.white.opacity(0.20)

    /// Row press feedback.
    static let rowHighlight = Color.white.opacity(0.03)

    // MARK: - Ambient washes
    //
    // Content-layer radial gradients, NOT glass. These are what give Connect
    // and Now Playing their glow without stacking a material on content.

    static func ambientWash(
        center: UnitPoint,
        radiusScale: CGFloat = 0.78,
        opacity: Double = 0.16
    ) -> RadialGradient {
        RadialGradient(
            colors: [Color(hex: 0xE8A33D, alpha: opacity), .clear],
            center: center,
            startRadius: 0,
            endRadius: 420 * radiusScale
        )
    }
}

// MARK: - Hex convenience

extension Color {
    /// `Color(hex: 0xE8A33D)`. Kept fileprivate-ish in spirit — the palette is
    /// the only place raw hex should appear.
    init(hex: UInt32, alpha: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: alpha
        )
    }
}
