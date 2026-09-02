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
                Image(systemName: icon)
                    .humFont(38, weight: .light)
                    .foregroundStyle(Palette.honeyAmber.opacity(0.8))
                    .accessibilityHidden(true)

                VStack(spacing: 14) {
                    Text(title)
                        .humFont(HumTextStyle(size: 27, weight: .light, relativeTo: .title))
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
                OutlineCapsuleButton(title: "Continue Without It") { dismiss() }
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

    private var icon: String {
        if case .unavailable = state { return HumIcon.warning }
        return HumIcon.musicNote
    }

    private var title: String {
        if case .unavailable = state { return "Couldn't Check" }
        return "Apple Music Needed"
    }

    private var message: String {
        switch state {
        case .unavailable:
            "Hum couldn't confirm your Apple Music subscription, so catalog tracks may not play. Your own library is unaffected."
        default:
            "Playing from the Apple Music catalog needs an active subscription on this account. Everything already in your library still plays."
        }
    }
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
