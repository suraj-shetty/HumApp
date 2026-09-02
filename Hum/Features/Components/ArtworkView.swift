import SwiftUI
import UIKit

/// Process-wide, in-memory artwork store.
///
/// `AsyncImage` keeps no memory of its own: every time SwiftUI rebuilds a view
/// hosting one, the load starts over and the placeholder shows while it runs.
/// The player bar rebuilds whenever playback state changes, so on device that
/// read as the artwork blinking on every play/pause.
///
/// Compliance: memory only. Nothing is written to disk, entries are dropped
/// under pressure, and it only ever holds art for content on screen — artwork
/// appears alongside playback and library management and is never repurposed.
@MainActor
final class ArtworkStore {
    static let shared = ArtworkStore()

    private let cache = NSCache<NSURL, UIImage>()
    /// Coalesces concurrent requests for the same URL — a grid and the player
    /// bar routinely ask for the same album at the same moment.
    private var inFlight: [URL: Task<UIImage?, Never>] = [:]

    private init() {
        cache.countLimit = 120
    }

    /// A synchronous hit, so a rebuild can paint the right pixels on its very
    /// first frame instead of blinking through the placeholder.
    func cached(_ url: URL?) -> UIImage? {
        url.flatMap { cache.object(forKey: $0 as NSURL) }
    }

    func image(for url: URL) async -> UIImage? {
        if let hit = cache.object(forKey: url as NSURL) { return hit }
        if let existing = inFlight[url] { return await existing.value }

        let task = Task<UIImage?, Never> {
            guard let (data, _) = try? await URLSession.shared.data(from: url) else { return nil }
            return UIImage(data: data)
        }
        inFlight[url] = task
        let image = await task.value
        inFlight[url] = nil

        if let image { cache.setObject(image, forKey: url as NSURL) }
        return image
    }
}

/// Album/track artwork. **Opaque content — never glass.**
///
/// Three things worth noting for performance, since this view appears dozens of
/// times per screen:
///
/// 1. The URL is already sized by the adapter via `Artwork.url(width:height:)`,
///    so we decode a thumbnail rather than a 3000px master for a 52pt row.
/// 2. The placeholder is a warm gradient rather than a spinner. A grid of
///    spinners reads as broken; a warm block reads as loading — and it is only
///    ever shown for art that has genuinely not loaded yet, never as a flash
///    between two renders of the same image.
/// 3. `.drawingGroup()` is deliberately *not* used — it would force an
///    offscreen buffer per row and cost more than it saves at these sizes.
///
/// Compliance note: artwork is only ever rendered alongside playback or library
/// management, never repurposed for unrelated screens.
struct ArtworkView: View {
    let url: URL?
    var size: CGFloat
    var cornerRadius: CGFloat = Metrics.radiusArt
    var warm: Bool = false
    /// Names the image for VoiceOver — the album or track title, not "image".
    var label: String?

    @State private var image: UIImage?

    var body: some View {
        Group {
            // The store is consulted synchronously as well as through `.task`,
            // so a view rebuilt with art already in memory never blinks.
            if let image = image ?? ArtworkStore.shared.cached(url) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .transition(.opacity)
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
        .animation(.easeOut(duration: 0.2), value: image == nil)
        .task(id: url) {
            guard let url else {
                image = nil
                return
            }
            image = await ArtworkStore.shared.image(for: url)
        }
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
