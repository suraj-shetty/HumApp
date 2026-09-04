import SwiftUI

/// Board 03, Section 02 — "iPad First Run". No sidebar, no player, no chrome
/// until there's something to show. Reuses `AuthViewModel`'s existing connect
/// wiring exactly as `ConnectView` does; only the layout is iPad's own —
/// a single centred "Connect Apple Music" CTA rather than paired with a
/// second service. Hum is Apple-Music-only by design: no other provider
/// exists in `AppEnvironment`, so the board's original "Connect Spotify"
/// pairing (revision item 1) was never buildable and isn't reproduced here.
struct IPadConnectView: View {
    let onConnect: () -> Void

    var body: some View {
        ZStack {
            Palette.deepOnyx.ignoresSafeArea()

            VStack(spacing: 30) {
                HumMark(outerArcs: true).frame(width: 64, height: 64)

                VStack(spacing: 12) {
                    Text("Your library, your queue,\non every screen you own.")
                        .humFont(HumTextStyle(size: 26, weight: .light, relativeTo: .title, tracking: -0.4))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Palette.textPrimary)
                }

                VStack(spacing: 14) {
                    AmberCapsuleButton(title: "Connect Apple Music", action: onConnect)
                        .frame(width: 340)

                    // Board 03's real secondary option, not grey small print.
                    // There's nothing behind it beyond the same MusicKit
                    // authorization prompt today — Hum's library reads
                    // require authorization the same as everywhere else in
                    // the app — so it triggers the identical connect flow,
                    // styled as secondary, rather than a distinct "offline
                    // browse" mode this app has no capability for.
                    Button("Browse what's already on this iPad", action: onConnect)
                        .buttonStyle(.plain)
                        .humFont(15)
                        .foregroundStyle(Palette.textSecondary)
                }

                Text("Hum reads your library to play it. It never posts, never follows, never sells what you listen to.")
                    .humFont(13, weight: .light)
                    .foregroundStyle(Palette.textMuted)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 420)
            }
            .padding(40)
        }
    }
}
