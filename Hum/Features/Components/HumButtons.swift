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

/// The design's actual outline treatment — a border only, no fill, label in
/// the accent colour. Measured off screen 27's "Browse library" (height 48,
/// padding 0 26, `border: rgba(232,163,61,.5)`, label `#E8A33D`).
///
/// Every secondary action in this design family that isn't plain text uses
/// this recipe. It replaced `OutlineCapsuleButton`, which filled and
/// labelled in white (finding Q-12) — a treatment the design never actually
/// draws anywhere.
///
/// The recipe itself isn't new — `DetailActionButton`'s `.outlined` style
/// (Detail's Shuffle button) already renders it correctly, independently
/// verified against a different design screen. Built fresh here rather than
/// shared with that private, `DetailView`-scoped type, so a change on one
/// screen can't silently move the other; `DetailActionButton`'s own height
/// is 2pt off its own spec (finding m-1) and isn't inherited by this.
struct AmberOutlineButton: View {
    let title: String
    var height: CGFloat = 48
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .humFont(16, weight: .regular)
                .foregroundStyle(Palette.honeyAmber)
                .padding(.horizontal, 26)
                .frame(height: height)
                .background {
                    Capsule(style: .continuous)
                        .strokeBorder(Palette.honeyAmber.opacity(0.5), lineWidth: 1)
                }
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
