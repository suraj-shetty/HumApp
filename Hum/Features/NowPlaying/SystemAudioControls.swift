import AVKit
import MediaPlayer
import SwiftUI

/// The system volume slider, as the design's Now Playing carries.
///
/// `MPVolumeView` is the only way to change output volume — iOS gives apps no
/// programmatic volume API, by design. It is Apple's own control, so this is a
/// standard first-party surface rather than a custom transport.
///
/// **It renders empty in the Simulator**, which has no audio route to control.
/// Judge it on device.
struct VolumeSlider: UIViewRepresentable {
    func makeUIView(context: Context) -> MPVolumeView {
        // `showsRouteButton` is deprecated — routing belongs to
        // `AVRoutePickerView`, which the utility row carries separately.
        let view = MPVolumeView(frame: .zero)
        view.tintColor = UIColor(Palette.honeyAmber)
        return view
    }

    func updateUIView(_ view: MPVolumeView, context: Context) {}

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: MPVolumeView, context: Context) -> CGSize? {
        CGSize(width: proposal.width ?? 322, height: 28)
    }
}

/// AirPlay, via Apple's own route picker.
///
/// Replaces a decorative glyph that had no action and was hidden from
/// VoiceOver — it looked like a control and was not one.
struct RoutePickerButton: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView {
        let view = AVRoutePickerView(frame: .zero)
        view.tintColor = UIColor(Palette.iconInactive)
        view.activeTintColor = UIColor(Palette.honeyAmber)
        view.prioritizesVideoDevices = false
        return view
    }

    func updateUIView(_ view: AVRoutePickerView, context: Context) {}
}
