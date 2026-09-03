import SwiftUI

/// Design screen 01. **Opaque content.** Shown once per cold launch, ahead
/// of `RootGateView` — the design draws it as the app's first frame, not a
/// state `AuthReducer` or any service can reach, so `LaunchFlowView` times it
/// itself rather than folding it into that gate.
struct SplashView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isRippling = false

    var body: some View {
        ZStack {
            Palette.deepOnyx.ignoresSafeArea()
            Palette.ambientWash(center: UnitPoint(x: 0.5, y: 0.44), radiusScale: 0.62, opacity: 0.14)
                .ignoresSafeArea()

            VStack(spacing: 26) {
                ZStack {
                    if !reduceMotion {
                        ripple(delay: 0)
                        ripple(delay: 0.9)
                    }
                    HumMark(outerArcs: true)
                        .frame(width: 104, height: 104)
                }
                .frame(width: 150, height: 150)

                Text("hum,")
                    .font(.system(size: 56, weight: .semibold, design: .rounded))
                    .tracking(-1.6)
                    .foregroundStyle(Palette.honeyAmber)
            }

            VStack {
                Spacer()
                Text("Your Apple Music, quietly")
                    .humFont(HumTextStyle(size: 12, relativeTo: .caption, tracking: 1.6, uppercase: true))
                    .foregroundStyle(Color.white.opacity(0.58))
                    .padding(.bottom, 52)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Hum")
        .onAppear { isRippling = true }
    }

    /// `humRipple` — a ring that expands and fades, 2.6s, looping, two copies
    /// staggered 0.9s apart.
    private func ripple(delay: Double) -> some View {
        Circle()
            .strokeBorder(Palette.honeyAmber.opacity(0.4), lineWidth: 1)
            .frame(width: 150, height: 150)
            .scaleEffect(isRippling ? 1.7 : 1)
            .opacity(isRippling ? 0 : 1)
            .animation(
                .easeOut(duration: 2.6).delay(delay).repeatForever(autoreverses: false),
                value: isRippling
            )
    }
}

#Preview {
    SplashView()
}
