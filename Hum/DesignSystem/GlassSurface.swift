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

    // The player bar's material and its morph into Now Playing are supplied by
    // `TabView`'s `tabViewBottomAccessory` — the system's own mini-player slot
    // — so neither needs an explicit glass call or a shared namespace here.
    // What remains below is used by surfaces the system does not place for us.
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
private struct AmberGlassModifier<S: Shape>: ViewModifier {
    let shape: S
    var shadow: Bool = true

    func body(content: Content) -> some View {
        content
            .background(Palette.amberGlassTint, in: shape)
            .overlay {
                shape
                    .stroke(Palette.glassHairline, lineWidth: 1)
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
}

extension View {
    /// Lays the design's Amber Glass tint over a surface the system has already
    /// given a material — the player bar's accessory slot, a toast.
    func amberGlass(in shape: some Shape, shadow: Bool = true) -> some View {
        modifier(AmberGlassModifier(shape: shape, shadow: shadow))
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
