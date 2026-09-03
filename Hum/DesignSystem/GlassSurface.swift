import SwiftUI

/// **The only file in Hum permitted to call `.glassEffect()`.**
///
/// `Scripts/check-containment.sh` fails the build on a `glassEffect` hit
/// anywhere else, which is what turns the brief's "content views render
/// opaque — never glass" from a review convention into a build error.
///
/// The rule it enforces, from ARCHITECTURE.md §6:
///
/// - **Chrome gets glass:** tab bar, player bar, toolbars, sheets, toasts.
/// - **Content stays opaque:** artwork, track rows, Now Playing, Queue,
///   transport buttons, every empty and error state.
///
/// Apple's iOS 26 guidance treats Liquid Glass as a material for the floating
/// navigation layer. Glass on glass compounds refraction into mud; glass over
/// dense or colorful content destroys both the content's legibility and the
/// material's own read.
///
/// **Reduce Transparency:** SwiftUI substitutes a solid material automatically.
/// That substitution is deliberately *not* reimplemented here — a hand-rolled
/// parallel path would drift from the system's. Confirming amber-on-solid stays
/// legible is a Phase 6 device check.
enum GlassSurface {

    // Every chrome surface in Hum is placed by hand, so every one of them asks
    // for its material here. That was not always true: the player bar once sat
    // in `TabView`'s `tabViewBottomAccessory`, which supplied a material of its
    // own. It no longer does (D-10), and for a while nothing replaced it — the
    // bar and the tab bar were drawing an amber tint over bare content.
}

/// Groups adjacent chrome glass into one material.
///
/// Two glass surfaces that touch must share a container, or each refracts the
/// other and the pair reads as mud rather than as one pane. The player bar and
/// the tab bar sit `Metrics.chromeGap` apart, which is well inside the range
/// where that matters.
///
/// This wraps `GlassEffectContainer` rather than letting call sites reach for
/// it directly, so the whole glass vocabulary stays in this file — the same
/// reason `.glassEffect()` is confined here.
struct ChromeGlassContainer<Content: View>: View {
    var spacing: CGFloat
    @ViewBuilder var content: Content

    var body: some View {
        GlassEffectContainer(spacing: spacing) { content }
    }
}

// MARK: - Amber Glass

/// The design's chrome fill, measured from the rendered board and identical on
/// every glass surface it draws:
///
/// - an amber gradient, 17% → 7% top to bottom
/// - a 1px hairline at white 16%
/// - a 1pt inset highlight along the top edge, white 20%
/// - a soft drop shadow, black 50% at y+10, radius 34
///
/// This is a *tint layer over* the system material, not a second material —
/// which is exactly what the design's "Amber Glass · chrome tint only" token
/// describes, and why it does not violate the glass-on-glass rule.
private struct GlassTintModifier<S: Shape>: ViewModifier {
    let shape: S
    let tint: AnyShapeStyle
    var shadow: Bool = true

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        content
            .background(fill, in: shape)
            .overlay {
                shape
                    .stroke(edge, lineWidth: 1)
                    .overlay(alignment: .top) {
                        shape
                            .stroke(Palette.glassTopHighlight, lineWidth: 1)
                            .mask(alignment: .top) {
                                Rectangle().frame(height: 1)
                            }
                    }
            }
            .shadow(color: .black.opacity(shadow ? 0.5 : 0), radius: 34 / 2, y: 10)
    }

    /// The system substitutes an opaque material for the glass itself; this
    /// substitutes the tint laid over it, so the two do not disagree.
    private var fill: AnyShapeStyle {
        reduceTransparency ? AnyShapeStyle(Palette.glassOpaqueFallback) : tint
    }

    private var edge: Color {
        reduceTransparency ? Palette.glassOpaqueEdge : Palette.glassHairline
    }
}

extension View {
    /// Lays the design's Amber Glass tint over a surface the system has already
    /// given a material — the player bar's accessory slot, a success toast.
    func amberGlass(in shape: some Shape, shadow: Bool = true) -> some View {
        modifier(GlassTintModifier(shape: shape, tint: AnyShapeStyle(Palette.amberGlassTint), shadow: shadow))
    }

    /// The same tint-over-material recipe as `amberGlass`, with a caller-supplied
    /// gradient — the toast's error (terracotta) and neutral (white) variants,
    /// which carry the identical border, top highlight and shadow but a
    /// different fill (design screen 30).
    func glassTint(in shape: some Shape, _ tint: LinearGradient, shadow: Bool = true) -> some View {
        modifier(GlassTintModifier(shape: shape, tint: AnyShapeStyle(tint), shadow: shadow))
    }
}

// MARK: - Modifiers

private struct ChromeGlassModifier<S: Shape>: ViewModifier {
    let shape: S
    let tint: Color?
    let isInteractive: Bool

    func body(content: Content) -> some View {
        content.glassEffect(glass, in: shape)
    }

    private var glass: Glass {
        var glass = Glass.regular
        if let tint { glass = glass.tint(tint) }
        if isInteractive { glass = glass.interactive() }
        return glass
    }
}

// MARK: - Floating action glass

extension View {
    /// The design's floating primary-action glass — the one capsule pattern
    /// that appears identically everywhere it is drawn: Connect's CTA and the
    /// subscription gap's retry button (`AmberCapsuleButton`, its only two
    /// callers), across every screen either appears on (04–07).
    ///
    /// A narrow, deliberate exception to "content stays opaque"
    /// (ARCHITECTURE.md §6). DECISIONS M-07 originally rendered every use of
    /// this component opaque, on the premise that Detail's Play pill and Now
    /// Playing's play/pause shared this same blurred-capsule recipe and that
    /// glass on any content-layer control would blur the line the
    /// containment script exists to keep sharp — but left it explicitly open:
    /// "Flag if you want the exception carved out instead."
    ///
    /// Measuring the recovered design settles it the other way. Detail's Play
    /// and Now Playing's disc are flat, opaque fills with no
    /// `backdrop-filter` at all in the design — already built to match, and
    /// untouched by this. Only `AmberCapsuleButton`'s own two uses specify
    /// `backdrop-filter: blur(24px) saturate(180%)`, identically, everywhere
    /// they're drawn. A single floating CTA is closer to what Apple's own
    /// guidance calls the floating navigation layer than it is to page
    /// content, which is the reasoning M-07 asked for before granting one.
    func floatingActionGlass(in shape: some Shape) -> some View {
        chromeGlass(in: shape, tint: nil)
    }
}

extension View {

    /// Applies Hum's chrome glass. **Chrome only** — see the type doc.
    ///
    /// - Parameters:
    ///   - shape: the glass boundary.
    ///   - tint: Honey Amber by default. Note the system desaturates and
    ///     modulates a tint against what sits behind it, so this will not
    ///     match `Palette.honeyAmber` used as a solid on content. That
    ///     difference is intended.
    ///   - interactive: `true` for surfaces that respond to touch, which
    ///     makes the material react under the finger.
    func chromeGlass(
        in shape: some Shape,
        tint: Color? = Palette.honeyAmber,
        interactive: Bool = false
    ) -> some View {
        modifier(ChromeGlassModifier(shape: shape, tint: tint, isInteractive: interactive))
    }

    /// Capsule chrome glass — the player bar and toast shape.
    func chromeGlassCapsule(
        tint: Color? = Palette.honeyAmber,
        interactive: Bool = false
    ) -> some View {
        chromeGlass(in: Capsule(style: .continuous), tint: tint, interactive: interactive)
    }
}
