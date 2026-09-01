import SwiftUI

/// Album/track artwork. **Opaque content — never glass.**
///
/// Three things worth noting for performance, since this view appears dozens of
/// times per screen:
///
/// 1. `AsyncImage` is handed a URL already sized by the adapter via
///    `Artwork.url(width:height:)`, so we decode a thumbnail rather than a
///    3000px master for a 52pt row.
/// 2. The placeholder is a warm gradient rather than a spinner. A grid of
///    spinners reads as broken; a warm block reads as loading.
/// 3. `.drawingGroup()` is deliberately *not* used — it would force an
///    offscreen buffer per row and cost more than it saves at these sizes.
///
/// Compliance note: artwork is only ever rendered alongside playback or library
/// management, never repurposed for unrelated screens.
struct ArtworkView: View {
    let url: URL?
    var size: CGFloat
    var cornerRadius: CGFloat = Metrics.radiusArtShelf
    var warm: Bool = false
    /// Names the image for VoiceOver — the album or track title, not "image".
    var label: String?

    var body: some View {
        Group {
            if let url {
                AsyncImage(url: url, transaction: .init(animation: .easeOut(duration: 0.2))) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure, .empty:
                        placeholder
                    @unknown default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(Palette.hairline, lineWidth: 1)
        )
        .accessibilityLabel(label.map { Text($0) } ?? Text(""))
        .accessibilityHidden(label == nil)
    }

    private var placeholder: some View {
        ZStack {
            if warm { Palette.artworkGradientWarm } else { Palette.artworkGradient }
            Image(systemName: HumIcon.musicNote)
                .font(.system(size: max(12, size * 0.22), weight: .light))
                .foregroundStyle(.white.opacity(0.18))
        }
    }
}

/// Circular variant — the player bar thumb.
struct CircularArtworkView: View {
    let url: URL?
    var size: CGFloat
    var label: String?

    var body: some View {
        ArtworkView(url: url, size: size, cornerRadius: size / 2, warm: true, label: label)
    }
}
