import SwiftUI

/// Design screens 02–03, the two onboarding pages between the splash and
/// Connect. **Opaque content**, except the floating CTA — the same
/// `AmberCapsuleButton` recipe Connect's own primary action uses (see
/// `floatingActionGlass`'s doc for why that's a deliberate, narrow exception).
///
/// Shown once: `LaunchFlowView` gates it behind a UserDefaults flag it sets
/// on `onFinish`, so a relaunch goes straight to `RootGateView`.
struct OnboardingView: View {
    var onFinish: () -> Void

    @State private var page = 0

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            headline: "Your library,\nin a quieter room",
            body: "Hum plays the Apple Music you already have — same songs, same subscription, a calmer interface.",
            buttonTitle: "Continue"
        ),
        OnboardingPage(
            headline: "One capsule,\nalways within reach",
            body: "Playback follows you across Home, Search and Library. Tap the capsule to open Now Playing.",
            buttonTitle: "Get started"
        ),
    ]

    var body: some View {
        VStack(spacing: 0) {
            skipRow

            Spacer(minLength: 0)

            VStack(spacing: 60) {
                OnboardingGlyph(isSecondPage: page == 1)

                VStack(spacing: 18) {
                    Text(pages[page].headline)
                        .humFont(HumTextStyle(size: 38, weight: .ultraLight, relativeTo: .largeTitle, tracking: -1))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Palette.textPrimary)

                    Text(pages[page].body)
                        .humFont(16, weight: .light)
                        .lineSpacing(6)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Palette.textSecondary)
                }
            }
            .padding(.horizontal, 34)
            .id(page)
            .transition(.opacity.combined(with: .offset(y: 8)))

            Spacer(minLength: 0)

            VStack(spacing: 26) {
                dots
                AmberCapsuleButton(title: pages[page].buttonTitle) { advance() }
                    .frame(maxWidth: 322)
            }
            .padding(.bottom, 44)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.deepOnyx.ignoresSafeArea())
        .animation(.easeOut(duration: 0.24), value: page)
    }

    private var skipRow: some View {
        HStack {
            Spacer()
            Button("Skip", action: onFinish)
                .buttonStyle(.plain)
                .humFont(16)
                .foregroundStyle(Palette.textSecondary)
                .frame(minWidth: Metrics.tapTarget, minHeight: Metrics.tapTarget)
        }
        .padding(.horizontal, Metrics.navGutter)
        .padding(.top, 4)
    }

    private var dots: some View {
        HStack(spacing: 8) {
            ForEach(pages.indices, id: \.self) { index in
                Circle()
                    .fill(index == page ? Palette.honeyAmber : Color.white.opacity(0.22))
                    .frame(width: 7, height: 7)
            }
        }
        .accessibilityHidden(true)
    }

    private func advance() {
        if page < pages.count - 1 {
            page += 1
        } else {
            onFinish()
        }
    }
}

private struct OnboardingPage {
    let headline: String
    let body: String
    let buttonTitle: String
}

/// The ringed icon block, screens 02 and 03 — two different recipes around
/// the same `HumMark` glyph family, not one icon reused.
private struct OnboardingGlyph: View {
    let isSecondPage: Bool

    var body: some View {
        ZStack {
            if isSecondPage {
                Circle()
                    .fill(Color(hex: 0x1E1E20))
                    .frame(width: 196, height: 196)
                    .shadow(color: Palette.honeyAmber.opacity(0.28), radius: 35)
                HumMark()
                    .frame(width: 60, height: 60)
            } else {
                Circle().strokeBorder(Palette.honeyAmber.opacity(0.14), lineWidth: 1).frame(width: 230, height: 230)
                Circle().strokeBorder(Palette.honeyAmber.opacity(0.22), lineWidth: 1).frame(width: 168, height: 168)
                Circle().strokeBorder(Palette.honeyAmber.opacity(0.34), lineWidth: 1).frame(width: 106, height: 106)
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Palette.browseAmbient)
                    .frame(width: 66, height: 66)
                    .overlay {
                        Image(systemName: HumIcon.library)
                            .humFont(15, weight: .regular)
                            .foregroundStyle(Palette.honeyAmber)
                    }
            }
        }
        .frame(width: 230, height: 230)
        .accessibilityHidden(true)
    }
}

#Preview {
    OnboardingView(onFinish: {})
}
