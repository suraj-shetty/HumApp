import SwiftUI

/// The Amber Glow type ramp, transcribed from the prototype.
///
/// Two families: **SF Pro Rounded Semibold** for the `hum,` wordmark alone, and
/// **SF Pro Display** for everything else. Weights run light — the heaviest
/// non-wordmark weight in the entire prototype is 400.
/// One entry in the ramp: a size, a weight, and the text style it scales
/// against.
///
/// Sizes are **points at the default Dynamic Type size**. They are not applied
/// directly — `humFont(_:)` runs them through `@ScaledMetric`, which is the only
/// supported way to make a custom point size follow the listener's text size.
/// `Font.system(size:)` has no scaling variant, and using it directly is why
/// Dynamic Type did nothing in this app until now.
struct HumTextStyle {
    var size: CGFloat
    var weight: Font.Weight = .regular
    var design: Font.Design = .default
    /// The metric the size scales against. Body for content, caption for the
    /// small tracked labels, title for display type.
    var relativeTo: Font.TextStyle = .body
    var tracking: CGFloat = 0
    var uppercase: Bool = false

    func size(_ newSize: CGFloat) -> HumTextStyle {
        var copy = self
        copy.size = newSize
        return copy
    }
}

extension HumTextStyle {

    // MARK: - Display & titles

    /// "Evening", "Search", "Settings" — 32 / 200 / -0.8.
    static let screenTitle = Self(size: 32, weight: .ultraLight, relativeTo: .largeTitle, tracking: -0.8)
    /// "Recently played", "Made for you" — 19 / 300 / -0.2.
    static let sectionTitle = Self(size: 19, weight: .light, relativeTo: .title3, tracking: -0.2)
    static let display = Self(size: 36, weight: .ultraLight, relativeTo: .largeTitle, tracking: -0.9)
    static let titleL = Self(size: 30, weight: .light, relativeTo: .title)
    static let titleM = Self(size: 26, weight: .light, relativeTo: .title2, tracking: -0.4)
    static let titleS = Self(size: 23, weight: .regular, relativeTo: .title3)

    // MARK: - Body & rows

    static let bodyL = Self(size: 16, weight: .light)
    static let button = Self(size: 17)
    static let rowTitle = Self(size: 16)
    static let rowSubtitle = Self(size: 13.5, relativeTo: .subheadline)
    static let caption = Self(size: 12.5, relativeTo: .caption)
    /// The design asks for `ui-monospace` — a monospaced *face*, which is not
    /// the same as `.monospacedDigit()` on the proportional one.
    static let timecode = Self(size: 12.5, design: .monospaced, relativeTo: .caption)
    // MARK: - Tracked labels

    // No `tabLabel` token: the native `TabView` owns its label typography, so
    // the design's 13.5/500 is unreachable without hand-building the bar.
    // No `overline` token either — every tracked uppercase label in the app is
    // either `groupLabel` or a screen-specific size set inline.

    /// Settings' group headers and the Queue's "next from".
    static let groupLabel = Self(size: 11.5, relativeTo: .caption, tracking: 1.5, uppercase: true)
    /// The wordmark — the only rounded type in the app, and the only place a
    /// weight above 400 is permitted.
    static let wordmark = Self(size: 30, weight: .semibold, design: .rounded, relativeTo: .largeTitle, tracking: -0.8)
}

enum HumFont {

    /// Ultra Light and Light fail at accessibility sizes. Rather than letting
    /// them stretch, step the weight up as the text scales.
    static func weight(
        for base: Font.Weight,
        at size: DynamicTypeSize
    ) -> Font.Weight {
        guard size >= .accessibility1 else { return base }
        return switch base {
        case .ultraLight, .thin: .light
        case .light: .regular
        default: base
        }
    }
}

// MARK: - Modifiers

/// Applies a `HumTextStyle`, scaled.
///
/// `@ScaledMetric` is a property wrapper, so it cannot live inside a static
/// `Font` constant — which is exactly why the ramp has to be data plus a
/// modifier rather than a set of `Font` values.
private struct HumFontModifier: ViewModifier {
    @ScaledMetric private var size: CGFloat
    @Environment(\.dynamicTypeSize) private var typeSize

    private let style: HumTextStyle

    init(_ style: HumTextStyle) {
        self.style = style
        _size = ScaledMetric(wrappedValue: style.size, relativeTo: style.relativeTo)
    }

    func body(content: Content) -> some View {
        content
            .font(
                .system(
                    size: size,
                    weight: HumFont.weight(for: style.weight, at: typeSize),
                    design: style.design
                )
            )
            .tracking(style.tracking)
            .textCase(style.uppercase ? .uppercase : nil)
    }
}

extension View {

    /// The one way type is applied in Hum. Scales with Dynamic Type, steps
    /// weight up at accessibility sizes, and carries the style's tracking and
    /// casing so call sites cannot forget them.
    func humFont(_ style: HumTextStyle) -> some View {
        modifier(HumFontModifier(style))
    }

    /// An ad-hoc size that still scales — for the handful of places the design
    /// specifies a one-off.
    func humFont(_ size: CGFloat, weight: Font.Weight = .regular, relativeTo: Font.TextStyle = .body) -> some View {
        modifier(HumFontModifier(HumTextStyle(size: size, weight: weight, relativeTo: relativeTo)))
    }
}
