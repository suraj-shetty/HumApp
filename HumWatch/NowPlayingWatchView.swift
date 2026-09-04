import MediaPlayer
import SwiftUI

/// Board 03's default Watch screen. "The art is a tinted background, the
/// controls are the content" — no circular disc hero, no progress ring like
/// iPhone/iPad; a watch screen has room for one thing.
///
/// The Digital Crown's amber volume arc is *not* drawn here — it's the
/// system's own Now Playing affordance, which watchOS gives for free once
/// the app registers with `MPNowPlayingInfoCenter`/`MPRemoteCommandCenter`.
/// Hand-drawing a `.digitalCrownRotation`-driven arc would not actually move
/// system audio volume, so this registers instead of drawing.
struct NowPlayingWatchView: View {
    @Environment(WatchPlayerViewModel.self) private var player
    @State private var isShowingUpNext = false

    var body: some View {
        ZStack {
            WatchPalette.ground.ignoresSafeArea()

            if player.isOutOfRange {
                outOfRangeBanner
            }

            if let track = player.payload.currentTrack {
                content(track)
            } else {
                Text("Nothing playing")
                    .font(.system(size: 14, weight: .light))
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isShowingUpNext = true
                } label: {
                    Image(systemName: HumIcon.queue)
                }
                .disabled(player.payload.upNext.isEmpty)
            }
        }
        .sheet(isPresented: $isShowingUpNext) {
            UpNextWatchView()
        }
        .onChange(of: player.payload) { _, payload in
            NowPlayingInfoRelay.update(payload)
        }
    }

    private func content(_ track: HumTrack) -> some View {
        VStack(spacing: 6) {
            Text(track.title)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white)
                .lineLimit(1)
            Text(track.artist)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(Palette.honeyAmber)
                .lineLimit(1)

            if let label = player.payload.audioVariantLabel {
                Text(label.uppercased())
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Palette.honeyAmber.opacity(0.85))
                    .padding(.top, 2)
            }

            timecodes

            transport
        }
        .padding(.horizontal, 8)
        .opacity(player.payload.isBuffering ? 0.55 : 1)
    }

    private var timecodes: some View {
        HStack {
            Text(player.payload.elapsed.humTimestamp)
            Spacer()
            Text(max(0, player.payload.duration - player.payload.elapsed).humRemaining)
        }
        .font(.system(size: 11, design: .monospaced))
        .foregroundStyle(.white.opacity(0.5))
        .padding(.top, 6)
    }

    private var transport: some View {
        HStack(spacing: 22) {
            Button(action: player.skipToPrevious) {
                Image(systemName: HumIcon.previous)
            }
            Button(action: player.togglePlayPause) {
                Image(systemName: player.payload.isPlaying ? HumIcon.pause : HumIcon.play)
                    .font(.system(size: 22))
            }
            Button(action: player.skipToNext) {
                Image(systemName: HumIcon.next)
            }
        }
        .foregroundStyle(.white)
        .padding(.top, 10)
    }

    /// Board 03's Out of Range: "One line at the top, transport stays live.
    /// Never a dialog." `isOutOfRange` only ever reflects
    /// `WCSession.isReachable`, never blocks the buttons above it.
    private var outOfRangeBanner: some View {
        VStack {
            Text("Phone out of range")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Palette.terracottaLift)
                .padding(.top, 2)
            Spacer()
        }
    }
}

/// Registers with the system's Now Playing surfaces so the Digital Crown's
/// volume arc appears without this app drawing one.
enum NowPlayingInfoRelay {
    static func update(_ payload: WatchPlaybackPayload) {
        var info: [String: Any] = [:]
        if let track = payload.currentTrack {
            info[MPMediaItemPropertyTitle] = track.title
            info[MPMediaItemPropertyArtist] = track.artist
            info[MPMediaItemPropertyPlaybackDuration] = payload.duration
            info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = payload.elapsed
            info[MPNowPlayingInfoPropertyPlaybackRate] = payload.isPlaying ? 1.0 : 0.0
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
}
