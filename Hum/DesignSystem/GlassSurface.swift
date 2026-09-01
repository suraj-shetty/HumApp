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
