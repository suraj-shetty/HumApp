import SwiftUI

/// Board 03's Library — "Five destinations, no search." The relay
/// architecture (Board 03 revision item 11) means this app has no direct
/// `MusicLibraryService` of its own on watchOS; browsing a destination other
/// than what's already relayed (current track, Up Next) is out of this
/// pass's scope and left as a labelled placeholder rather than wired to a
/// phone round-trip this relay doesn't support yet.
struct LibraryWatchView: View {
    @Environment(WatchPlayerViewModel.self) private var player

    private let destinations = [
        "Listen now", "Recently played", "Downloaded", "Playlists",
    ]

    var body: some View {
        List {
            ForEach(destinations, id: \.self) { title in
                Text(title)
                    .font(.system(size: 15, weight: .light))
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .listStyle(.carousel)
        .background(WatchPalette.ground)
        .navigationTitle("Library")
        .safeAreaInset(edge: .bottom) {
            // "The capsule at the bottom returns to playback" — Board 03.
            if let track = player.payload.currentTrack {
                HStack(spacing: 6) {
                    Image(systemName: player.payload.isPlaying ? HumIcon.pause : HumIcon.play)
                    Text(track.title).lineLimit(1)
                }
                .font(.system(size: 12))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Palette.surfaceRaised, in: Capsule())
                .onTapGesture { player.togglePlayPause() }
            }
        }
    }
}
