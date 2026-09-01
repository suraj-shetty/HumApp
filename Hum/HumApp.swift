import SwiftUI

/// Composition root.
///
/// Phase 0 scaffolding: the app launches to a placeholder so the toolchain,
/// deployment target, and containment checks can be verified before any
/// feature code exists. `AppEnvironment` (which wires live MusicKit adapters
/// against fakes) arrives in Phase 2 — see docs/v1-musickit/DEVELOPMENT_PLAN.md.
@main
struct HumApp: App {
    var body: some Scene {
        WindowGroup {
            ScaffoldPlaceholderView()
                .preferredColorScheme(.dark)
        }
    }
}
