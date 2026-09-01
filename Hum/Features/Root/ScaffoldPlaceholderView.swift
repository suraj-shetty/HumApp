import SwiftUI

/// Phase 0 placeholder. Replaced by `RootTabView` in Phase 4.
///
/// Deliberately carries no design-system dependency — `DesignSystem/Palette.swift`
/// is Phase 4 work, and hardcoding two colors here is cheaper than shipping a
/// token layer this view will never use.
struct ScaffoldPlaceholderView: View {
    private static let deepOnyx = Color(red: 0.039, green: 0.039, blue: 0.039)   // #0A0A0A
    private static let honeyAmber = Color(red: 0.910, green: 0.639, blue: 0.239) // #E8A33D

    var body: some View {
        ZStack {
            Self.deepOnyx.ignoresSafeArea()

            VStack(spacing: 12) {
                Text("hum,")
                    .font(.system(size: 44, weight: .semibold, design: .rounded))
                    .kerning(-1.1)
                    .foregroundStyle(Self.honeyAmber)

                Text("Phase 0 — scaffolding")
                    .font(.system(size: 13, weight: .regular))
                    .kerning(1.6)
                    .textCase(.uppercase)
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
    }
}

#Preview {
    ScaffoldPlaceholderView()
}
