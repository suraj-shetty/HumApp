import SwiftUI

/// The prototype's primary capsule — Connect, album Play, the 76pt transport.
///
/// **Opaque, not glass.** The prototype applies `backdrop-filter: blur()` to
/// these three content-layer controls, which contradicts the brief's boundary
/// ("glass applies only to Player Bar, Tab Bar, toolbars, Toasts, sheets").
/// Resolved in DECISIONS M-07: same amber gradient, same border, same inner
/// highlight, rendered opaque. On a dark ground at these sizes the difference
/// is nearly invisible, and it keeps the containment grep honest.
struct AmberCapsuleButton: View {
    let title: String
    var systemImage: String?
    var isLoading: Bool = false
    var height: CGFloat = 58
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(Palette.honeyAmber)
                } else if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 16, weight: .regular))
                }
                Text(title)
                    .font(HumFont.button)
            }
            .foregroundStyle(Palette.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(Palette.amberButton, in: Capsule(style: .continuous))
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(Palette.buttonStroke, lineWidth: 1)
            )
            .overlay(alignment: .top) {
                // The lit top edge. A 1pt inset highlight, matching the
                // prototype's `inset 0 1px 0 rgba(255,255,255,.24)`.
                Capsule(style: .continuous)
                    .strokeBorder(Palette.buttonInnerHighlight, lineWidth: 1)
                    .blendMode(.plusLighter)
                    .mask(alignment: .top) {
                        Rectangle().frame(height: height / 2)
                    }
            }
        }
        .buttonStyle(.pressable)
        .disabled(isLoading)
    }
}

/// The neutral sibling — album Shuffle.
struct NeutralCapsuleButton: View {
    let title: String
    var systemImage: String?
    var height: CGFloat = 50
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 15, weight: .regular))
                }
                Text(title)
                    .font(HumFont.button)
            }
            .foregroundStyle(Palette.textPrimary.opacity(0.86))
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(Palette.neutralButtonFill, in: Capsule(style: .continuous))
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(Palette.neutralButtonStroke, lineWidth: 1)
            )
        }
        .buttonStyle(.pressable)
    }
}

/// The outline capsule from the Queue empty state.
struct OutlineCapsuleButton: View {
    let title: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15.5))
                .foregroundStyle(Palette.textPrimary)
                .padding(.horizontal, 26)
                .frame(height: 46)
                .background(Palette.amberOutlineFill, in: Capsule(style: .continuous))
                .overlay(
                    Capsule(style: .continuous)
                        .strokeBorder(Palette.amberOutlineStroke, lineWidth: 1)
                )
        }
        .buttonStyle(.pressable)
    }
}

/// A bare symbol button on a 44pt target.
///
/// Every icon control in Hum goes through this so the brief's 44×44 floor is
/// structural rather than something each call site remembers.
struct IconButton: View {
    let systemName: String
    var size: CGFloat = 20
    var weight: Font.Weight = .regular
    var tint: Color = Palette.iconInactive
    var target: CGFloat = Metrics.tapTarget
    var pressScale: CGFloat = Motion.pressScaleButton
    let label: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: size, weight: weight))
                .foregroundStyle(tint)
                .frame(minWidth: target, minHeight: target)
                .contentShape(.rect)
        }
        .buttonStyle(PressableStyle(scale: pressScale))
        .accessibilityLabel(label)
    }
}
