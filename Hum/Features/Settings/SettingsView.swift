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
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                settingsGroup("Apple Music") {
                    row("Access", model?.authorizationDescription ?? "—")
                    if model?.showsSystemSettingsLink == true,
                       let url = URL(string: UIApplication.openSettingsURLString) {
                        Divider().overlay(Palette.hairline)
                        linkRow("Open Settings", destination: url)
                    }
                    Divider().overlay(Palette.hairline)
                    row("Subscription", model?.subscriptionDescription ?? "—")
                }

                settingsGroup(
                    "Appearance",
                    footer: "Hum follows your system accessibility settings. With Reduce Transparency on, the player and tab bar render solid."
                ) {
                    row("Reduce Transparency", reduceTransparency ? "On" : "Off")
                }

                settingsGroup("Privacy") {
                    NavigationLink {
                        PrivacyView()
                    } label: {
                        HStack {
                            Text("Privacy")
                                .humFont(16)
                                .foregroundStyle(Palette.textPrimary)
                            Spacer()
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 14)
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                }

                settingsGroup(
                    "About",
                    // Stated plainly because the Connect screen promises it.
                    footer: "Hum plays your Apple Music library through Apple's own playback engine. No account, no tracking, no ads."
                ) {
                    row("Version", model?.appVersion ?? "—")
                }
            }
            .padding(.horizontal, Metrics.gutter)
            .padding(.top, 8)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
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
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .accessibilityElement(children: .combine)
    }

    private func linkRow(_ title: String, destination: URL) -> some View {
        Link(destination: destination) {
            Text(title)
                .humFont(16)
                .foregroundStyle(Palette.honeyAmber)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }

    /// Settings' group headers are the design's uppercase tracked label —
    /// the same style the Queue uses for "next from", not a section title.
    private func groupLabel(_ title: String) -> some View {
        Text(title)
            .humFont(.groupLabel)
            .foregroundStyle(Palette.textPrimary.opacity(0.62))
            .accessibilityAddTraits(.isHeader)
    }

    /// One card: `#141416` fill, radius 16, rows separated by a `.07` white
    /// hairline inset to the row's own leading edge — the design's grouped
    /// list, not the system's (m-14). The system version's fill sits at
    /// roughly `#1C1C1E` — lighter than the design's card — at the system's
    /// own ~10pt corner radius.
    @ViewBuilder
    private func settingsGroup(
        _ title: String,
        footer: String? = nil,
        @ViewBuilder rows: () -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            groupLabel(title)
                .padding(.horizontal, 4)

            VStack(alignment: .leading, spacing: 0) {
                rows()
            }
            .background(Palette.surfaceCard, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

            if let footer {
                Text(footer)
                    .humFont(12.5, weight: .light)
                    .foregroundStyle(Palette.textMuted)
                    .lineSpacing(2)
                    .padding(.horizontal, 4)
            }
        }
    }
}
