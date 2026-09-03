import SwiftUI

/// Motion, transcribed from the prototype's keyframes.
///
/// All of it is **content-layer** motion, which SwiftUI will not reduce for
/// you — `accessibilityReduceMotion` needs an explicit branch at every call
/// site. `Motion.reduced(_:)` is that branch, in one place.
enum Motion {

    /// `humRise` — opacity 0→1 with a 14pt lift. 0.32s ease-out.
    static let rise = Animation.easeOut(duration: 0.3)
    /// Screen-to-screen content changes.
    ///
    /// Computed, not stored: `AnyTransition` is not `Sendable`, so a static
    /// `let` would be shared mutable global state under strict concurrency.
    static var riseTransition: AnyTransition {
        .opacity.combined(with: .offset(y: 14))
    }
    /// `humBar` — the "playing now" level meter. 1s, autoreversing.
    static let levelBar = Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true)
    /// Stagger between the three meter bars.
    static let levelBarStagger: Double = 0.22
    /// Press feedback.
    /// Ease-out, not a spring: the design says "no bounce, no spring", and a
    /// spring on every pressable control was the most widespread breach of it.
    static let press = Animation.easeOut(duration: 0.16)

    /// Tab selection. The handoff's content spring — response 0.42, damping
    /// 0.82 — which is near-critically damped, so it settles without the bounce
    /// the design rules out elsewhere.
    static let tabSelection = Animation.spring(response: 0.42, dampingFraction: 0.82)

    static let pressScaleButton: CGFloat = 0.98
    static let pressScaleTransport: CGFloat = 0.94

    /// Returns `nil` — meaning "apply no animation" — when Reduce Motion is on.
    static func reduced(_ animation: Animation?, when reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : animation
    }
}

/// The three-bar amber level meter from the Queue screen's "Playing now" card.
///
/// Purely decorative, so it is hidden from VoiceOver — a bouncing bar conveys
/// nothing to a screen reader, and the surrounding card already says
/// "Playing now".
///
/// Under Reduce Motion the bars freeze flat. The prototype's own Dynamic Island
/// note specifies the same static state for "paused", so one appearance serves
/// both cases.
/// Decorative. Hidden from VoiceOver — it carries no information a listener
/// cannot get from the playback state itself.
struct LevelMeter: View {
    var isAnimating: Bool = true
    var barCount: Int = 3
    /// Container height 16, not 20 — measured off the "Playing now" card
    /// (Q-11).
    var height: CGFloat = 16
    var tint: Color = Palette.honeyAmber

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animating = false

    /// The design's three bars rest at three different heights — 7, 14, 10 —
    /// not one uniform scale (Q-11).
    private static let restHeights: [CGFloat] = [7, 14, 10]

    private var shouldAnimate: Bool { isAnimating && !reduceMotion }

    var body: some View {
        // 2.5pt bars, 2.5pt gap — was 3 and 3 (Q-11).
        HStack(alignment: .bottom, spacing: 2.5) {
            ForEach(0..<barCount, id: \.self) { index in
                let rest = Self.restHeights[index % Self.restHeights.count] / height
                Capsule(style: .continuous)
                    .fill(tint)
                    .frame(width: 2.5)
                    .scaleEffect(
                        y: animating && shouldAnimate ? 1.0 : rest,
                        anchor: .bottom
                    )
                    .animation(
                        shouldAnimate
                            ? Motion.levelBar.delay(Double(index) * Motion.levelBarStagger)
                            : nil,
                        value: animating
                    )
            }
        }
        .frame(height: height)
        .onAppear { animating = true }
        .accessibilityHidden(true)
    }
}

/// `scaleEffect` press feedback without swallowing the tap.
struct PressableStyle: ButtonStyle {
    var scale: CGFloat = Motion.pressScaleButton

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? scale : 1.0)
            .animation(Motion.reduced(Motion.press, when: reduceMotion), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PressableStyle {
    static var pressable: PressableStyle { PressableStyle() }
    static var pressableTransport: PressableStyle {
        PressableStyle(scale: Motion.pressScaleTransport)
    }
}
