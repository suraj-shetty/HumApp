import SwiftUI

/// The prototype's primary capsule — Connect's CTA and the subscription
/// gap's retry button, its only two callers.
///
/// **Glass, per the design — see `floatingActionGlass`'s own doc for why
/// DECISIONS M-07's original "render everything opaque" default no longer
/// holds.** The gradient, border and inner highlight were already exact
/// matches for the design's floating-CTA recipe; only the material itself
/// was missing.
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
                        .humFont(16, weight: .regular)
                        // The title carries the meaning; the glyph repeats it.
                        .accessibilityHidden(true)
                }
                Text(title)
                    .humFont(.button)
            }
            .foregroundStyle(Palette.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            // Material first, then the design's amber tint over it — the
            // same order the chrome glass uses, and for the same reason: the
            // tint has to sit on top of a real material or it is just a
            // translucent shape with nothing behind it.
            .floatingActionGlass(in: Capsule(style: .continuous))
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
            // `0 10px 30px rgba(0,0,0,.5)`. CSS blur halves into a SwiftUI
            // radius, the same conversion used throughout this file.
            .shadow(color: .black.opacity(0.5), radius: 15, y: 10)
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
                        .humFont(15, weight: .regular)
                        .accessibilityHidden(true)
                }
                Text(title)
                    .humFont(.button)
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
                .humFont(15.5)
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
                .humFont(size, weight: weight)
                .foregroundStyle(tint)
                .frame(minWidth: target, minHeight: target)
                .contentShape(.rect)
        }
        .buttonStyle(PressableStyle(scale: pressScale))
        .accessibilityLabel(label)
    }
}
