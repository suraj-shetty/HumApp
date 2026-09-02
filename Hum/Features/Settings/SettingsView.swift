import Observation
import SwiftUI

@MainActor
@Observable
final class SettingsViewModel {
    private(set) var authorization: AuthState = .notDetermined
    private(set) var subscription: SubscriptionState = .unknown

    private let authService: MusicAuthorizationService
    private let subscriptionService: SubscriptionService

    init(environment: AppEnvironment) {
        self.authService = environment.authorization
        self.subscriptionService = environment.subscription
    }

    func load() async {
        authorization = await authService.current
        subscription = await subscriptionService.current
    }

    var authorizationDescription: String {
        switch authorization {
        case .authorized: "Connected"
        case .denied: "Access denied"
        case .restricted: "Restricted by this device"
        case .notDetermined: "Not connected"
        case .requesting: "Connecting…"
        }
    }

    var subscriptionDescription: String {
        switch subscription {
        case .active: "Active"
        case .gap: "No active subscription"
        case .unknown: "Checking…"
        case .unavailable: "Couldn't check"
        }
    }

    /// Only `.denied` is user-recoverable. Under `.restricted` the switch
    /// either isn't in Settings or won't move, so no link is offered
    /// (ARCHITECTURE §5a).
    var showsSystemSettingsLink: Bool {
        authorization == .denied
    }

    var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "—"
        let build = info?["CFBundleVersion"] as? String ?? "—"
        return "\(version) (\(build))"
    }
}

/// Settings. **Opaque content.** Designed by inference (DECISIONS M-06).
struct SettingsView: View {
    @Environment(\.appEnvironment) private var environment
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @State private var model: SettingsViewModel?

    var body: some View {
        List {
            Section {
                row("Access", model?.authorizationDescription ?? "—")
                row("Subscription", model?.subscriptionDescription ?? "—")

                if model?.showsSystemSettingsLink == true,
                   let url = URL(string: UIApplication.openSettingsURLString) {
                    Link("Open Settings", destination: url)
                        .tint(Palette.honeyAmber)
                }
            } header: {
                groupLabel("Apple Music")
            }

            Section {
                row("Reduce Transparency", reduceTransparency ? "On" : "Off")
            } header: {
                groupLabel("Appearance")
            } footer: {
                Text("Hum follows your system accessibility settings. With Reduce Transparency on, the player and tab bar render solid.")
            }

            Section {
                row("Version", model?.appVersion ?? "—")
            } header: {
                groupLabel("About")
            } footer: {
                // Stated plainly because the Connect screen promises it.
                Text("Hum plays your Apple Music library through Apple's own playback engine. No account, no tracking, no ads.")
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Palette.deepOnyx)
        .safeAreaInset(edge: .top, spacing: 0) {
            // 32 / 200, the same display title Home and Search carry.
            Text("Settings")
                .humFont(.screenTitle)
                .foregroundStyle(Palette.textPrimary)
                .accessibilityAddTraits(.isHeader)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Metrics.gutter)
                .padding(.bottom, 12)
                .background(Palette.deepOnyx)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if model == nil { model = SettingsViewModel(environment: environment) }
            await model?.load()
        }
    }

    private func row(_ title: String, _ value: String) -> some View {
        LabeledContent {
            Text(value)
                .humFont(15)
                .foregroundStyle(Palette.textPrimary.opacity(0.62))
        } label: {
            Text(title)
                .humFont(16)
                .foregroundStyle(Palette.textPrimary)
        }
        .accessibilityElement(children: .combine)
    }

    /// Settings' group headers are the design's uppercase tracked label —
    /// the same style the Queue uses for "next from", not a section title.
    private func groupLabel(_ title: String) -> some View {
        Text(title)
            .humFont(.groupLabel)
            .foregroundStyle(Palette.textPrimary.opacity(0.62))
            .accessibilityAddTraits(.isHeader)
    }
}
