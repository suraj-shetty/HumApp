import SwiftUI

/// Sequences the app's first frames: splash, then onboarding once ever, then
/// `RootGateView` — the existing authorization gate, unchanged and untouched
/// by any of this.
///
/// Root of the app in `HumApp.swift`, replacing a bare `RootGateView` there.
/// Splash and onboarding are screens 01–03 of the design's own "Onboarding &
/// Apple Music authorization" section — screen 04 onward is `ConnectView`,
/// already built, which is why this file stops handing off exactly where
/// `RootGateView` already begins.
struct LaunchFlowView: View {
    private enum Stage { case splash, onboarding, gate }

    /// Whether onboarding has ever been finished on this device. A real
    /// default, not a preview one — `UserDefaults.standard` persists across
    /// launches, which is the entire point: this must show once ever, not
    /// once per cold start.
    @AppStorage("HumHasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var stage: Stage = .splash

    var body: some View {
        ZStack {
            switch stage {
            case .splash:
                SplashView()
                    .transition(.opacity)
            case .onboarding:
                OnboardingView { finishOnboarding() }
                    .transition(.opacity)
            case .gate:
                RootGateView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: stage)
        .task {
            // The design shows the splash as a beat, not a loading state —
            // there is nothing to wait on, so this is a fixed pause rather
            // than gated on any service call.
            try? await Task.sleep(for: .seconds(1.4))
            guard !Task.isCancelled else { return }
            stage = hasCompletedOnboarding ? .gate : .onboarding
        }
    }

    private func finishOnboarding() {
        hasCompletedOnboarding = true
        stage = .gate
    }
}
