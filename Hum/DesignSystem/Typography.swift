import SwiftUI

/// The Amber Glow type ramp, transcribed from the prototype.
///
/// Two families: **SF Pro Rounded Semibold** for the `hum,` wordmark alone, and
/// **SF Pro Display** for everything else. Weights run light — the heaviest
/// non-wordmark weight in the entire prototype is 400.
enum HumFont {

    /// The wordmark. The only rounded type in the app.
    static func wordmark(size: CGFloat = 30) -> Font {
        // Semibold on purpose. The "weights 200/300/400 only" law governs
        // SF Pro Display — the UI face. The wordmark is a brand asset in
        // ui-rounded, and every instance of it in the design measures at 600,
        // including the 30pt one in the Home header. Corrected after reading
        // the rendered design rather than its prose.
        .system(size: size, weight: .semibold, design: .rounded)
    }

    // MARK: - Display & titles
    //
    // `relativeTo:` keeps Dynamic Type working. Weight steps *up* as size
    // grows (see `weight(for:)`) because Ultra Light does not survive the
    // accessibility sizes — it thins out to near-invisibility.

    static func display(_ size: CGFloat = 36) -> Font {
        .system(size: size, weight: .ultraLight)
    }

    static func titleL(_ size: CGFloat = 30) -> Font {
        .system(size: size, weight: .light)
    }

    static func titleM(_ size: CGFloat = 26) -> Font {
        .system(size: size, weight: .light)
    }

    static func titleS(_ size: CGFloat = 23) -> Font {
        .system(size: size, weight: .regular)
    }

    // MARK: - Body & rows

    static let bodyL = Font.system(size: 16, weight: .light)
    /// 17, measured on the Connect button's label. Detail's Play and Shuffle
    /// buttons have not been measured yet and share this token.
    static let button = Font.system(size: 17, weight: .regular)
    static let rowTitle = Font.system(size: 16, weight: .regular)
    static let rowSubtitle = Font.system(size: 13.5, weight: .regular)
    static let caption = Font.system(size: 12.5, weight: .regular)

    /// Every timecode, everywhere. The design asks for `ui-monospace`, which is
    /// a monospaced *face* — `.monospacedDigit()` only equalises digit widths
    /// on the proportional face and is not the same thing.
    static func timecode(_ size: CGFloat = 12.5) -> Font {
        .system(size: size, weight: .regular, design: .monospaced)
    }
    /// 11, not 10.5: the design's floor is "nothing below 11pt".
    static let tabLabel = Font.system(size: 11, weight: .regular)

    /// The uppercase wide-tracked overline — "RECENTLY PLAYED", "UP NEXT",
    /// "PLAYING NOW". The system's most distinctive typographic move, and the
    /// reason `.overline()` exists as a modifier rather than being respecified
    /// at each of its ~10 call sites.
    /// The uppercase tracked label — Settings' group headers, the Queue's
    /// "next from", the detail meta line. 11.5 / 400 / white 62% / 1.5.
    static let groupLabel = Font.system(size: 11.5, weight: .regular)

    static func overline(_ size: CGFloat = 11) -> Font {
        .system(size: size, weight: .regular)
    }

    /// The screen title — "Evening", "Search", "Settings". Measured at
    /// 32 / weight 200 / white / -0.8 on every screen that carries one.
    static let screenTitle = Font.system(size: 32, weight: .ultraLight)

    /// Section headers — "Recently played", "Made for you", "Downloaded".
    ///
    /// Measured at 19 / Light / white / sentence case, with -0.2 tracking. The
    /// app had been drawing these as uppercase, tracked, grey overlines, which
    /// was the single largest difference on the Home screen. The overline style
    /// is real, but it belongs to the greeting and the detail meta line, not to
    /// section headers.
    static let sectionTitle = Font.system(size: 19, weight: .light)

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

private struct OverlineModifier: ViewModifier {
    let size: CGFloat
    let tracking: CGFloat

    func body(content: Content) -> some View {
        content
            .font(HumFont.overline(size))
            .tracking(tracking)
            .textCase(.uppercase)
    }
}

/// Steps weight up at accessibility sizes so light display type stays legible.
private struct ScalingWeightModifier: ViewModifier {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let size: CGFloat
    let base: Font.Weight
    let tracking: CGFloat

    func body(content: Content) -> some View {
        content
            .font(.system(size: size, weight: HumFont.weight(for: base, at: dynamicTypeSize)))
            .tracking(tracking)
    }
}

extension View {
    /// Section headers and metadata lines. Tracking runs +1.4 to +1.8 in the
    /// prototype depending on size.
    func overline(size: CGFloat = 13, tracking: CGFloat = 1.4) -> some View {
        modifier(OverlineModifier(size: size, tracking: tracking))
    }

    /// Display and title type that survives Dynamic Type by gaining weight
    /// rather than stretching thin.
    func humTitle(
        size: CGFloat,
        weight: Font.Weight = .light,
        tracking: CGFloat = 0
    ) -> some View {
        modifier(ScalingWeightModifier(size: size, base: weight, tracking: tracking))
    }
}
