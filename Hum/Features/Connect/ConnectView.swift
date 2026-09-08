import SwiftUI

/// The first thing a listener sees. **Opaque content**, except its one CTA
/// capsule — see `AmberCapsuleButton`.
///
/// Two layouts, four states. `.invitation` and `.connecting` share the
/// permission-list layout — DECISIONS M-06's original inference, and still
/// correct for these two; nothing in the recovered design contradicts it.
/// `.deniedRecoverable` and `.restrictedNoRecourse` share a second, centred
/// layout — icon halo, headline, body, and (only where the design draws one)
/// an info card — matching design screen 06. Both used to render through the
/// invitation's own layout, left-aligned with the same generic permission
/// rows, until the design QA audit found screen 06 and confirmed the two had
/// drifted (`design-audit/HUM_AUDIT.md` §9, CT-1). M-06's "no design exists
/// for these" no longer holds for `.deniedRecoverable` — it does for
/// `.restrictedNoRecourse`, which borrows screen 06's structure but keeps its
/// own already-considered copy, since nothing in the design covers it.
///
/// `.restrictedNoRecourse` still reads as a missing button rather than a
/// special screen for one reason: `primaryAction` returns `nil` there and the
/// button simply is not built. That is `AuthReducer`'s own reasoning, not
/// something screen 06 shows — it has no equivalent state to measure against.
struct ConnectView: View {
    let screen: ConnectScreen
    let onPrimaryAction: () -> Void
    /// Re-checks authorization without prompting. Only `.deniedRecoverable`'s
    /// "Try again" calls it — a convenience for "I already flipped the switch
    /// in Settings." `RootGateView` already does this automatically on
    /// foreground, but the design draws the button, and a listener watching
    /// their own screen shouldn't have to background-and-return to see it
    /// update. Defaults to a no-op so the `#Preview`s below don't need one.
    var onRefresh: () -> Void = {}

    @Environment(\.openURL) private var openURL
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isInfoLayout: Bool {
        screen == .deniedRecoverable || screen == .restrictedNoRecourse
    }

    private var primaryAction: ConnectPrimaryAction? {
        AuthReducer.primaryAction(for: screen)
    }

    var body: some View {
        ZStack {
            Palette.deepOnyx.ignoresSafeArea()
            // Screen 06 is a flat #0A0A0A, same as the invitation's own
            // screen 04 — the wash is invitation-only either way, so this
            // just keeps the info layout from carrying one design never draws
            // for it.
            if !isInfoLayout { ambientWash }

            ScrollView {
                if isInfoLayout {
                    infoContent
                } else {
                    invitationContent
                }
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .safeAreaInset(edge: .bottom) { footer }
    }

    // MARK: - Invitation layout (.invitation, .connecting)

    private var invitationContent: some View {
        VStack(alignment: .leading, spacing: 34) {
            HumMark()
                .frame(width: 52, height: 52)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 16) {
                Text(copy.title)
                    .humFont(HumTextStyle(size: 36, weight: .ultraLight, relativeTo: .title, tracking: -0.9))
                    .lineSpacing(3)
                    .foregroundStyle(Palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(copy.body)
                    .humFont(.bodyL)
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
        // Design 04: 56, not 72 (CT-3).
        .padding(.top, 56)
        .padding(.bottom, 40)
    }

    // MARK: - Info layout (.deniedRecoverable, .restrictedNoRecourse)

    /// Screen 06: a centred icon halo, headline, body, and — only where
    /// `ConnectCopy` supplies one — an info card. Measured top padding is
    /// 130, not the invitation layout's 72; the two screens simply differ.
    private var infoContent: some View {
        VStack(spacing: 30) {
            iconHalo

            Text(copy.title)
                .humFont(HumTextStyle(size: 30, weight: .ultraLight, relativeTo: .title, tracking: -0.6))
                .lineSpacing(4)
                .multilineTextAlignment(.center)
                .foregroundStyle(Palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text(copy.body)
                .humFont(HumTextStyle(size: 15.5, weight: .light))
                .lineSpacing(6)
                .multilineTextAlignment(.center)
                .foregroundStyle(Palette.textSecondary)
                .frame(maxWidth: 302)
                .fixedSize(horizontal: false, vertical: true)

            if let card = copy.infoCard {
                InfoCard(eyebrow: card.eyebrow, value: card.value)
            }
        }
        .accessibilityElement(children: .combine)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Metrics.heroGutter)
        .padding(.top, 130)
        .padding(.bottom, 40)
    }

    /// 112×112, a 1px ring around a 44pt padlock. Terracotta, not amber —
    /// amber means "informational" everywhere else in this file; this state
    /// means "blocked."
    private var iconHalo: some View {
        ZStack {
            Circle()
                .strokeBorder(Palette.terracotta.opacity(0.38), lineWidth: 1)
            Image(systemName: "lock")
                .humFont(44, weight: .light)
                .foregroundStyle(Palette.terracotta)
        }
        .frame(width: 112, height: 112)
        .accessibilityHidden(true)
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
                .frame(maxWidth: 324)
            }

            if let secondaryTitle = copy.secondaryButtonTitle {
                // Plain text, not `AmberCapsuleButton`'s bordered sibling —
                // screen 06 draws "Try again" as an unstyled link, the same
                // way `SubscriptionGapView` draws its own secondary action
                // (that screen's mismatch is audit finding SG-4, not fixed
                // here — a different view, out of scope for this pass).
                Button(secondaryTitle, action: onRefresh)
                    .buttonStyle(.plain)
                    .humFont(16)
                    .foregroundStyle(Palette.textSecondary)
                    .frame(height: Metrics.tapTarget)
            }

            if let footnote = copy.footnote {
                Text(footnote)
                    .humFont(.caption)
                    .foregroundStyle(Palette.textPrimary.opacity(0.62))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .frame(maxWidth: 300)
                    .fixedSize(horizontal: false, vertical: true)
            }
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
    let footnote: String?
    let secondaryButtonTitle: String?
    let infoCard: (eyebrow: String, value: String)?

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
            secondaryButtonTitle = nil
            infoCard = nil

        case .deniedRecoverable:
            // Screen 06, measured verbatim (design-audit/HUM_AUDIT.md §9).
            title = "Access to Apple Music\nis turned off"
            body = "Without it Hum can't show your library, search the catalog or play anything. Turn access back on in iOS Settings and Hum picks up where it left off."
            buttonTitle = "Open Settings"
            footnote = nil
            secondaryButtonTitle = "Try again"
            infoCard = (eyebrow: "Where to look", value: "Settings → Hum → Media & Apple Music")

        case .restrictedNoRecourse:
            title = "Access\nRestricted"
            // No button here on purpose: under Screen Time or a management
            // profile the switch is absent or won't move, and a button that
            // resolves nothing is worse than none at all. No design screen
            // covers this state — it borrows screen 06's layout but keeps
            // its own already-considered copy, since nothing measures it.
            body = "Media access is restricted on this device — usually by Screen Time or a device management profile. Neither Hum nor Settings can change it from here."
            buttonTitle = ""
            footnote = "Whoever manages this device's restrictions can allow Media & Apple Music."
            secondaryButtonTitle = nil
            infoCard = nil
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
            // 22×22, stroke-width 1.4 — was a 17pt glyph shrunk inside a 24pt
            // frame (CT-4).
            Image(systemName: systemImage)
                .humFont(22, weight: .light)
                .foregroundStyle(Palette.honeyAmber)
                .frame(width: 22)
                .accessibilityHidden(true)

            Text(text)
                .humFont(15.5, weight: .light)
                .lineSpacing(2)
                .foregroundStyle(Palette.textPrimary.opacity(0.82))
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(.vertical, 19)
        .accessibilityElement(children: .combine)
    }
}

/// Screen 06's "Where to look" pattern — a small key/value card, drawn only
/// where `ConnectCopy.infoCard` supplies one.
private struct InfoCard: View {
    let eyebrow: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(eyebrow)
                .humFont(HumTextStyle(size: 11, relativeTo: .caption2, tracking: 1.4, uppercase: true))
                .foregroundStyle(Palette.textMuted)
            Text(value)
                .humFont(14.5, weight: .light)
                .foregroundStyle(Palette.textPrimary.opacity(0.78))
                .lineSpacing(3)
        }
        .frame(maxWidth: 322, alignment: .leading)
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        // `#141416` at radius 16. Queue's now-playing card measures the same
        // fill at radius 14 — a literal here rather than reusing that card's
        // radius, since the two aren't the same component and 16 is what
        // this one actually measures.
        .background(Palette.surfaceCard, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
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
            // `id: isAnimating` rather than a bare `.task`: a plain `.task`
            // only runs once for the view's lifetime, so it never noticed a
            // live Reduce Motion toggle flip `isAnimating` after the first
            // render — the ring kept spinning through a mid-screen toggle
            // to on, and never started for a toggle to off. Re-running on
            // every change lets the `else` branch actively override the
            // ongoing `repeatForever` with a fresh, instant animation on
            // the same property — reassigning `angle` alone wouldn't stop
            // it, since nothing there interrupts the existing animation.
            .task(id: isAnimating) {
                if isAnimating {
                    withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                        angle = 360
                    }
                } else {
                    withAnimation(.linear(duration: 0)) {
                        angle = 0
                    }
                }
            }
    }
}

/// Hum's mark: a centre dot between two facing arcs — sound leaving a source.
/// Drawn rather than shipped as an asset so it inherits the accent colour.
///
/// `outerArcs` adds a second, wider pair at 60% opacity — screen 01's louder
/// splash variant of the same glyph. Connect (04) and onboarding screen 03
/// use the plain two-arc form; only the splash screen draws the fuller one.
struct HumMark: View {
    var color: Color = Palette.honeyAmber
    var outerArcs: Bool = false

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

            guard outerArcs else { return }
            let outerStroke = StrokeStyle(lineWidth: 2.4 * scale, lineCap: .round)
            for mirrored in [false, true] {
                var path = Path()
                path.addArc(
                    center: center,
                    radius: 19 * scale,
                    startAngle: .degrees(mirrored ? 122 : -58),
                    endAngle: .degrees(mirrored ? 238 : 58),
                    clockwise: false
                )
                context.stroke(path, with: .color(color.opacity(0.6)), style: outerStroke)
            }
        }
    }
}

#Preview("Invitation") {
    ConnectView(screen: .invitation, onPrimaryAction: {})
}

#Preview("Denied") {
    ConnectView(screen: .deniedRecoverable, onPrimaryAction: {})
}

#Preview("Restricted") {
    ConnectView(screen: .restrictedNoRecourse, onPrimaryAction: {})
}
