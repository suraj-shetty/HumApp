import SwiftUI

/// Board 03, Section 02 — "iPad First Run". No sidebar, no player, no chrome
/// until there's something to show. Reuses `AuthViewModel`'s existing connect
/// wiring exactly as `ConnectView` does; only the layout is iPad's own —
/// a single centred composition rather than `ConnectView`'s two.
///
/// Branches on `screen` the same way `ConnectView` does — this used to always
/// render the invitation copy and a button wired to `onPrimaryAction`
/// regardless of `screen`, so a listener who had denied or was restricted saw
/// the identical "Connect Apple Music" button, which `AuthReducer` makes a
/// no-op from either state. Reusing `ConnectCopy`/`AuthReducer.primaryAction`
/// rather than hand-writing iPad's own copy keeps the four states' wording
/// (and which of them get a button at all) from a second place to drift out
/// of sync with `ConnectView`'s.
struct IPadConnectView: View {
    let screen: ConnectScreen
    let onPrimaryAction: () -> Void
    /// Only `.deniedRecoverable`'s "Try again" calls it — see `ConnectView`'s
    /// own doc comment on the same parameter.
    var onRefresh: () -> Void = {}

    @Environment(\.openURL) private var openURL

    private var copy: ConnectCopy { ConnectCopy(screen: screen) }
    private var primaryAction: ConnectPrimaryAction? { AuthReducer.primaryAction(for: screen) }

    var body: some View {
        ZStack {
            Palette.deepOnyx.ignoresSafeArea()

            VStack(spacing: 30) {
                HumMark(outerArcs: true).frame(width: 64, height: 64)

                VStack(spacing: 12) {
                    Text(copy.title)
                        .humFont(HumTextStyle(size: 26, weight: .light, relativeTo: .title, tracking: -0.4))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Palette.textPrimary)

                    Text(copy.body)
                        .humFont(15)
                        .foregroundStyle(Palette.textSecondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 420)
                }

                // Matches `ConnectView`'s own footer condition: `.connecting`
                // has no *action* — the reducer is right to return `nil` —
                // but still needs the capsule, disabled and reading
                // "Connecting…". `.restrictedNoRecourse` gets neither: a
                // button that resolves nothing is worse than none at all.
                if primaryAction != nil || screen == .connecting {
                    VStack(spacing: 14) {
                        AmberCapsuleButton(
                            title: copy.buttonTitle,
                            isLoading: screen == .connecting,
                            action: { primaryAction.map(perform) }
                        )
                        .frame(width: 340)

                        // Board 03's real secondary option, not grey small
                        // print — only offered alongside the invitation
                        // itself, since it triggers the same authorization
                        // prompt `onPrimaryAction` does and would be exactly
                        // as inert from `.denied`/`.restricted` as the
                        // primary button was.
                        if screen == .invitation {
                            Button("Browse what's already on this iPad", action: onPrimaryAction)
                                .buttonStyle(.plain)
                                .humFont(15)
                                .foregroundStyle(Palette.textSecondary)
                        }

                        if let secondaryTitle = copy.secondaryButtonTitle {
                            Button(secondaryTitle, action: onRefresh)
                                .buttonStyle(.plain)
                                .humFont(15)
                                .foregroundStyle(Palette.textSecondary)
                        }
                    }
                }

                if let footnote = copy.footnote {
                    Text(footnote)
                        .humFont(13, weight: .light)
                        .foregroundStyle(Palette.textMuted)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 420)
                } else if screen == .invitation {
                    Text("Hum reads your library to play it. It never posts, never follows, never sells what you listen to.")
                        .humFont(13, weight: .light)
                        .foregroundStyle(Palette.textMuted)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 420)
                }
            }
            .padding(40)
        }
    }

    private func perform(_ action: ConnectPrimaryAction) {
        switch action {
        case .requestAuthorization:
            onPrimaryAction()
        case .openSystemSettings:
            if let url = URL(string: UIApplication.openSettingsURLString) {
                openURL(url)
            }
        }
    }
}
