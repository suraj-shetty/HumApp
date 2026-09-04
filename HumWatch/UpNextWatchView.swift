import SwiftUI

/// Board 03: "Tap to jump. No reordering on watch — that is a phone job."
/// Deliberately no `.onMove`/swipe-to-remove — those stay iPhone/iPad-only.
struct UpNextWatchView: View {
    @Environment(WatchPlayerViewModel.self) private var player
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(Array(player.payload.upNext.enumerated()), id: \.offset) { offset, track in
                    Button {
                        player.jump(to: offset)
                        dismiss()
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(track.title)
                                .font(.system(size: 14))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                            Text(track.artist)
                                .font(.system(size: 12))
                                .foregroundStyle(Palette.honeyAmber.opacity(0.8))
                                .lineLimit(1)
                        }
                    }
                }
            }
            .navigationTitle("Up Next")
            .background(WatchPalette.ground)
        }
    }
}
