import SwiftUI

/// The first thing a listener sees. **Opaque content — no glass.**
///
/// One layout, four states. `AuthReducer` decides which; this file only picks
/// copy, which is why the `.restricted` case reads as a missing button rather
/// than as a special screen: `primaryAction` returns `nil` there and the button
/// simply is not built.
///
/// Transcribed from the prototype's Connect screen — the ambient amber wash,
/// the 52pt mark, the 36pt Ultra Light two-line title, three hairline-separated
/// permission rows, and the pinned capsule with its footnote. The `.denied` and
/// `.restricted` variants have no design and are built by inference from that
/// layout (DECISIONS M-06).
struct ConnectView: View {
    let screen: ConnectScreen
    let onPrimaryAction: () -> Void

    @Environment(\.openURL) private var openURL
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var primaryAction: ConnectPrimaryAction? {
        AuthReducer.primaryAction(for: screen)
    }

    var body: some View {
        ZStack {
            Palette.deepOnyx.ignoresSafeArea()
            ambientWash

            ScrollView {
                VStack(alignment: .leading, spacing: 34) {
                    HumMark()
                        .frame(width: 52, height: 52)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 16) {
                        Text(copy.title)
                            .humTitle(size: 36, weight: .ultraLight, tracking: -0.9)
                            .lineSpacing(3)
                            .foregroundStyle(Palette.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(copy.body)
                            .font(HumFont.bodyL)
                            .lineSpacing(4)
                            .foregroundStyle(Palette.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .accessibilityElement(children: .combine)

                    permissions

                    if screen == .connecting {
                        ConnectSpinner(isAnimating: !reduceMotion)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 8)
                            .accessibilityLabel("Waiting for Apple Music")
                    }
                }
                .padding(.horizontal, Metrics.heroGutter)
                .padding(.top, 72)
                .padding(.bottom, 40)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .safeAreaInset(edge: .bottom) { footer }
    }

    // MARK: - Pieces

    /// `radial(70% 45% at 50% 30%, amber .13, transparent 70%)`.
    private var ambientWash: some View {
        GeometryReader { proxy in
            let size = proxy.size
            RadialGradient(
                colors: [Palette.honeyAmber.opacity(0.13), .clear],
                center: .init(x: 0.5, y: 0.3),
                startRadius: 0,
                endRadius: max(size.width * 0.7, size.height * 0.45)
            )
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    private var permissions: some View {
        VStack(spacing: 0) {
            Divider().overlay(Palette.hairlineStrong)
            ForEach(ConnectCopy.permissions, id: \.text) { item in
                PermissionRow(systemImage: item.icon, text: item.text)
                Divider().overlay(Palette.hairlineStrong)
            }
        }
    }

    @ViewBuilder
    private var footer: some View {
        VStack(spacing: 18) {
            // `.connecting` has no *action* — the reducer is right to return
            // `nil` — but it still needs the capsule, disabled and reading
            // "Connecting…". Dropping the button while the system prompt is up
            // makes the screen lurch under the sheet.
            if primaryAction != nil || screen == .connecting {
                AmberCapsuleButton(
                    title: copy.buttonTitle,
                    isLoading: screen == .connecting,
                    action: { primaryAction.map(perform) }
                )
                .frame(maxWidth: 322)
            }

            Text(copy.footnote)
                .font(HumFont.caption)
                .foregroundStyle(Palette.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .frame(maxWidth: 300)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, Metrics.heroGutter)
        .padding(.top, 20)
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity)
        .background(Palette.deepOnyx)
    }

    private func perform(_ action: ConnectPrimaryAction) {
        switch action {
        case .requestAuthorization:
            onPrimaryAction()
        case .openSystemSettings:
            // Deep-links to Hum's own pane, where the Media & Apple Music
            // switch lives. Offered only under `.denied` — see the reducer.
            if let url = URL(string: UIApplication.openSettingsURLString) {
                openURL(url)
            }
        }
    }

    private var copy: ConnectCopy { ConnectCopy(screen: screen) }
}

// MARK: - Copy

/// Wording for each state, kept out of the view so the four variants sit side
/// by side and can be read as a set.
private struct ConnectCopy {
    let title: String
    let body: String
    let buttonTitle: String
    let footnote: String

    static let permissions: [(icon: String, text: String)] = [
        (HumIcon.library, "Read your library, playlists and recently played"),
        (HumIcon.play, "Play tracks through Apple's own playback engine"),
        ("lock", "No account, no tracking, no ads — ever"),
    ]

    init(screen: ConnectScreen) {
        switch screen {
        case .invitation, .connecting:
            title = "Connect\nApple Music"
            body = "Hum needs your permission to play your Apple Music library. Nothing leaves your device."
            buttonTitle = screen == .connecting ? "Connecting…" : "Connect Apple Music"
            footnote = "Opens Apple's authorization prompt. You can revoke access any time in Settings."

        case .deniedRecoverable:
            title = "Access\nNot Granted"
            body = "Hum can't reach your music without permission. iOS only asks once, so this has to be turned back on in Settings."
            buttonTitle = "Open Settings"
            footnote = "Settings › Hum › Media & Apple Music. Come back here once it's on."

        case .restrictedNoRecourse:
            title = "Access\nRestricted"
            // No button here on purpose: under Screen Time or a management
            // profile the switch is absent or won't move, and a button that
            // resolves nothing is worse than none at all.
            body = "Media access is restricted on this device — usually by Screen Time or a device management profile. Neither Hum nor Settings can change it from here."
            buttonTitle = ""
            footnote = "Whoever manages this device's restrictions can allow Media & Apple Music."
        }
    }
}

// MARK: - Components

/// One permission row — amber glyph, hairline beneath.
private struct PermissionRow: View {
    let systemImage: String
    let text: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .light))
                .foregroundStyle(Palette.honeyAmber)
                .frame(width: 24)

            Text(text)
                .font(.system(size: 15.5, weight: .light))
                .lineSpacing(2)
                .foregroundStyle(Palette.textPrimary.opacity(0.82))
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(.vertical, 19)
        .accessibilityElement(children: .combine)
    }
}

/// The prototype's `humSpin` ring — a 64pt amber arc on a faint track.
///
/// Held still under Reduce Motion; the ring alone still reads as "working",
/// and the button beneath it says "Connecting…" regardless.
private struct ConnectSpinner: View {
    let isAnimating: Bool
    @State private var angle: Double = 0

    var body: some View {
        Circle()
            .stroke(Palette.honeyAmber.opacity(0.18), lineWidth: 2)
            .frame(width: 64, height: 64)
            .overlay {
                Circle()
                    .trim(from: 0, to: 0.25)
                    .stroke(Palette.honeyAmber, style: .init(lineWidth: 2, lineCap: .round))
                    .rotationEffect(.degrees(angle))
            }
            .task {
                guard isAnimating else { return }
                withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                    angle = 360
                }
            }
    }
}

/// Hum's mark: a centre dot between two facing arcs — sound leaving a source.
/// Drawn rather than shipped as an asset so it inherits the accent colour.
struct HumMark: View {
    var color: Color = Palette.honeyAmber

    var body: some View {
        Canvas { context, size in
            let scale = min(size.width, size.height) / 48
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let dot = Path(
                ellipseIn: CGRect(
                    x: center.x - 3.6 * scale,
                    y: center.y - 3.6 * scale,
                    width: 7.2 * scale,
                    height: 7.2 * scale
                )
            )
            context.fill(dot, with: .color(color))

            let stroke = StrokeStyle(lineWidth: 2.4 * scale, lineCap: .round)
            for mirrored in [false, true] {
                var path = Path()
                path.addArc(
                    center: center,
                    radius: 11.4 * scale,
                    startAngle: .degrees(mirrored ? 128 : -52),
                    endAngle: .degrees(mirrored ? 232 : 52),
                    clockwise: false
                )
                context.stroke(path, with: .color(color), style: stroke)
            }
        }
    }
}

#Preview("Invitation") {
    ConnectView(screen: .invitation, onPrimaryAction: {})
}

#Preview("Restricted") {
    ConnectView(screen: .restrictedNoRecourse, onPrimaryAction: {})
}
