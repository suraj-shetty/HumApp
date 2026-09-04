import SwiftUI

/// Design screen 29. **Opaque content**, except the CTA — the same
/// `AmberCapsuleButton` recipe used everywhere else a floating primary
/// action appears (see `floatingActionGlass`'s doc).
///
/// Presented when `PlayerViewModel.perform` sees two playback commands fail
/// in a row with nothing succeeding between them — the closest honest proxy
/// this codebase has for "lost the connection to Apple Music" (MusicKit
/// gives no real signal for that distinct from an ordinary single command
/// failing, which the toast-with-retry elsewhere already covers). The
/// design's monospace error code ("MKError · 6.1") is left off, same as
/// Detail's failed-to-load screen: there's no real code behind it to show.
struct ConnectionLostView: View {
    let onRetry: () -> Void

    var body: some View {
        ZStack {
            Palette.deepOnyx.ignoresSafeArea()

            VStack(spacing: 22) {
                ZStack {
                    Circle()
                        .strokeBorder(Palette.terracotta.opacity(0.38), lineWidth: 1)
                        .frame(width: 112, height: 112)
                    Circle()
                        .strokeBorder(Palette.terracotta.opacity(0.22), lineWidth: 1)
                        .frame(width: 78, height: 78)
                    HumMark(color: Palette.terracottaLift)
                        .frame(width: 40, height: 40)
                }
                .accessibilityHidden(true)

                Text("Playback stopped")
                    .humFont(HumTextStyle(size: 26, weight: .ultraLight, relativeTo: .title, tracking: -0.4))
                    .foregroundStyle(Palette.textPrimary)

                Text("Hum lost its connection to Apple Music. Your queue is intact and resumes where it stopped.")
                    .humFont(15, weight: .light)
                    .lineSpacing(4)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Palette.textSecondary)
                    .frame(maxWidth: 300)

                AmberCapsuleButton(title: "Try Again", action: onRetry)
                    .frame(maxWidth: 322)
                    .padding(.top, 8)
            }
            .padding(.horizontal, 34)
            .accessibilityElement(children: .combine)
        }
    }
}

#Preview {
    ConnectionLostView {}
}
