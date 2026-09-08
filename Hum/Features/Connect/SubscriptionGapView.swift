import SwiftUI

/// Shown when catalog playback is unavailable **and Apple's offer sheet is not
/// the answer** — either the account cannot become a subscriber, or the check
/// itself failed. **Opaque content.**
///
/// The `.gap(canBecomeSubscriber: true)` case never reaches this view: it goes
/// straight to Apple's own offer sheet. What is left here are the two states
/// where dangling an offer would be dishonest, so this explains and gets out of
/// the way.
///
/// Note what it does *not* do. It does not block the app, does not gate any Hum
/// feature, and does not appear until the listener actually asks for a catalog
/// track. Library playback is unaffected and the sheet dismisses to a working
/// app. Designed by inference (DECISIONS M-06) from the Connect layout.
struct SubscriptionGapView: View {
    let state: SubscriptionState
    let onRetry: (() -> Void)?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            VStack(spacing: 22) {
                ZStack {
                    Circle()
                        .strokeBorder(Palette.honeyAmber.opacity(0.35), lineWidth: 1)
                        .frame(width: 112, height: 112)
                    Image(systemName: icon)
                        .humFont(46, weight: .light)
                        .foregroundStyle(Palette.honeyAmber.opacity(0.8))
                }
                .accessibilityHidden(true)

                VStack(spacing: 14) {
                    Text(title)
                        .humFont(HumTextStyle(size: 30, weight: .ultraLight, relativeTo: .title))
                        .foregroundStyle(Palette.textPrimary)

                    Text(message)
                        .humFont(15, weight: .light)
                        .foregroundStyle(Palette.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .frame(maxWidth: 300)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .multilineTextAlignment(.center)
                .accessibilityElement(children: .combine)
            }

            Spacer(minLength: 0)

            VStack(spacing: 14) {
                if let onRetry {
                    AmberCapsuleButton(title: "Try Again") {
                        onRetry()
                        dismiss()
                    }
                }
                // Plain text, not a bordered capsule — design screens 05/06
                // draw both secondary actions here as unstyled links, the
                // same recipe `ConnectView`'s own "Try again" uses. Was
                // `OutlineCapsuleButton` (audit finding SG-4).
                Button("Continue Without It") { dismiss() }
                    .buttonStyle(.plain)
                    .humFont(16)
                    .foregroundStyle(Palette.textSecondary)
                    .frame(height: Metrics.tapTarget)
            }
            .padding(.bottom, 8)
        }
        .padding(.horizontal, Metrics.heroGutter)
        .padding(.vertical, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.deepOnyx)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Copy

    /// One switch over `state` rather than three, so a future third
    /// `SubscriptionState` case can't fall through as a silent default in
    /// icon/title but a real branch in message — the three used to be
    /// decided independently.
    private var copy: (icon: String, title: String, message: String) {
        switch state {
        case .unavailable:
            (
                HumIcon.warning,
                "Couldn't Check",
                "Hum couldn't confirm your Apple Music subscription, so catalog tracks may not play. Your own library is unaffected."
            )
        case .active, .gap, .unknown:
            (
                HumIcon.musicNote,
                "Apple Music Needed",
                "Playing from the Apple Music catalog needs an active subscription on this account. Everything already in your library still plays."
            )
        }
    }

    private var icon: String { copy.icon }
    private var title: String { copy.title }
    private var message: String { copy.message }
}

#Preview("No subscription") {
    Color.black.sheet(isPresented: .constant(true)) {
        SubscriptionGapView(state: .gap(canBecomeSubscriber: false), onRetry: nil)
    }
}

#Preview("Check failed") {
    Color.black.sheet(isPresented: .constant(true)) {
        SubscriptionGapView(state: .unavailable(reason: "offline"), onRetry: {})
    }
}
