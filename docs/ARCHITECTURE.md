# Hum — Architecture

**Status:** Proposed. Nothing implemented. Requires sign-off on [DECISIONS.md](DECISIONS.md) before code is written.
**Target:** iOS 26+, Swift 6 (strict concurrency), SwiftUI, MVVM.

---

## 1. System overview

```
┌─────────────────────────────────────────────────────────────────┐
│  View layer (SwiftUI) — zero business logic                     │
│  RootTabView · HomeView · NowPlayingView · AdBreakView          │
│  LibraryView · PaywallView · PlayerBar · TrackRow               │
└───────────────▲─────────────────────────────────────────────────┘
                │ reads @Observable state, sends intents
┌───────────────┴─────────────────────────────────────────────────┐
│  ViewModel layer (@MainActor @Observable)                       │
│  PlayerViewModel · HomeViewModel · LibraryViewModel             │
│  AdBreakViewModel · PaywallViewModel                            │
└───────────────▲─────────────────────────────────────────────────┘
                │ observes / commands
┌───────────────┴─────────────────────────────────────────────────┐
│  Coordination layer (@MainActor, single source of truth)        │
│  PlaybackCoordinator — owns the session state machine           │
└──────┬──────────────┬──────────────┬───────────────┬────────────┘
       │              │              │               │
┌──────▼──────┐┌──────▼──────┐┌──────▼───────┐┌──────▼──────────┐
│MusicPlayback││ AdService   ││ Entitlement  ││ AdBreakPolicy   │
│Service      ││ (protocol)  ││ Service      ││ (pure value —   │
│(protocol)   ││             ││ (protocol)   ││  no I/O)        │
└──────┬──────┘└──────┬──────┘└──────┬───────┘└─────────────────┘
       │              │              │
┌──────▼──────┐┌──────▼──────┐┌──────▼───────┐
│ FeedFM      ││ AVPlayer-   ││ StoreKit2    │
│ Adapter     ││ AdPlayer    ││ Adapter      │
│ (FMAudio-   ││             ││ (Transaction │
│  Player)    ││             ││  .current…)  │
└─────────────┘└─────────────┘└──────────────┘
```

**Rule:** every arrow points downward. A View never imports `FeedMedia` or `StoreKit`. A ViewModel never imports them either — it talks only to protocols. Only the three adapter files in `Services/Adapters/` import vendor SDKs. This is what makes the `MusicPlaybackService` swap-without-touching-ViewModels acceptance criterion structurally true rather than aspirational.

---

## 2. Target & file layout

Single app target + single unit-test target. No SPM sub-modules — the layering is enforced by the "only adapters import vendor SDKs" rule, and a multi-module split would exceed the requested scope.

```
HumApp/
├── HumApp.xcodeproj
├── Config/
│   ├── Debug.xcconfig            # FEEDFM_TOKEN / FEEDFM_SECRET (gitignored)
│   ├── Release.xcconfig
│   └── Shared.xcconfig
├── Hum/
│   ├── HumApp.swift              # @main — builds the composition root
│   ├── Info.plist                # keys read from xcconfig via $(FEEDFM_TOKEN)
│   ├── AppEnvironment.swift      # composition root: wires concrete adapters
│   │
│   ├── DesignSystem/
│   │   ├── Palette.swift         # Deep Onyx, Honey Amber, sepia ramp
│   │   ├── Typography.swift      # SF Pro Display Light/Thin scale
│   │   ├── Motion.swift          # drift speeds, spring constants
│   │   └── GlassSurface.swift    # THE ONLY place .glassEffect() is called
│   │
│   ├── Domain/
│   │   ├── Track.swift           # provider-neutral value type
│   │   ├── Station.swift
│   │   ├── AdCreative.swift
│   │   ├── PlaybackState.swift   # the state machine enum
│   │   ├── Entitlement.swift
│   │   └── AdBreakPolicy.swift   # pure, fully unit-tested
│   │
│   ├── Services/
│   │   ├── MusicPlaybackService.swift    # protocol
│   │   ├── AdService.swift               # protocol
│   │   ├── EntitlementService.swift      # protocol
│   │   ├── AudioSessionManager.swift
│   │   └── Adapters/
│   │       ├── FeedFMPlaybackAdapter.swift   # only file importing FeedMedia
│   │       ├── BundledAdService.swift        # only file importing AVFoundation for ads
│   │       └── StoreKit2EntitlementService.swift  # only file importing StoreKit
│   │
│   ├── Coordination/
│   │   └── PlaybackCoordinator.swift
│   │
│   ├── Features/
│   │   ├── Root/RootTabView.swift
│   │   ├── Home/{HomeView,HomeViewModel}.swift
│   │   ├── NowPlaying/{NowPlayingView,PlayerViewModel,LiquidMeshBackground,ProgressArc,AlbumArtGlow}.swift
│   │   ├── AdBreak/{AdBreakView,AdBreakViewModel,RippleVisualizer,WaningMoonCountdown}.swift
│   │   ├── Library/{LibraryView,LibraryViewModel}.swift
│   │   ├── Paywall/{PaywallView,PaywallViewModel}.swift
│   │   └── Components/{PlayerBar,TrackRow}.swift
│   └── Resources/
│       ├── Assets.xcassets
│       └── Ads/                  # bundled ad audio — see DECISION D-01
└── HumTests/
    ├── AdBreakPolicyTests.swift
    ├── PlaybackCoordinatorTests.swift
    ├── EntitlementGatingTests.swift
    └── Fakes/{FakeMusicPlaybackService,FakeAdService,FakeEntitlementService}.swift
```

---

## 3. Concurrency model (Swift 6 strict)

| Component | Isolation | Reason |
|---|---|---|
| Views | `@MainActor` (implicit) | SwiftUI |
| ViewModels | `@MainActor @Observable final class` | drive UI directly, no hops |
| `PlaybackCoordinator` | `@MainActor @Observable final class` | single mutable session state; MainActor avoids a second lock |
| `MusicPlaybackService` | `protocol …: AnyObject, Sendable` + `@MainActor` conformances | Feed.fm SDK is main-thread-bound |
| `EntitlementService` | `actor` | StoreKit calls are async and off-UI |
| `AdBreakPolicy` | `struct: Sendable` | pure, no isolation |
| Domain types | `struct: Sendable, Equatable` | free to cross boundaries |

**Known friction to budget for:** the Feed.fm SDK is Objective-C and predates `Sendable`. Under Swift 6 strict concurrency its types (`FMAudioPlayer`, `FMAudioItem`, `FMStation`) will not be `Sendable`, and its `NotificationCenter` callbacks carry non-`Sendable` payloads. Containment strategy:

1. Mark `FeedFMPlaybackAdapter` as `@MainActor`.
2. Never let an `FMAudioItem` escape the adapter — map to `Track` at the boundary, inside the same function that received it.
3. If the SDK ships without a Swift 6 language mode, set `SWIFT_VERSION` per-dependency or use `@preconcurrency import FeedMedia`. Expect to need `@preconcurrency`.
4. Bridge notifications via an `AsyncStream<PlaybackEvent>` the adapter vends, so the coordinator consumes `Sendable` events only.

This is the single largest technical risk in the build. Phase 1 exists to de-risk it before any UI is written.

---

## 4. Core contracts

```swift
// Domain/Track.swift — provider-neutral. Nothing Feed.fm-shaped leaks in.
struct Track: Sendable, Identifiable, Equatable {
    let id: String
    let title: String
    let artist: String
    let album: String?
    let duration: TimeInterval
    let artworkURL: URL?
}

// Domain/PlaybackState.swift
enum PlaybackState: Sendable, Equatable {
    case idle
    case loading
    case playing(Track)
    case paused(Track)
    case adBreak(AdCreative)     // music suspended, ad audio owns the session
    case failed(PlaybackFailure)
}

// Services/MusicPlaybackService.swift
protocol MusicPlaybackService: AnyObject, Sendable {
    var events: AsyncStream<PlaybackEvent> { get }
    var currentTrack: Track? { get }

    func prepare() async throws            // auth handshake, station list
    func availableStations() async throws -> [Station]
    func play(station: Station) async throws
    func resume() async
    func pause() async
    func skip() async throws               // throws .skipDenied — see D-05
    func stop() async
}

enum PlaybackEvent: Sendable, Equatable {
    case stateChanged(PlaybackState)
    case trackDidStart(Track)
    case trackDidComplete(Track)           // fired ONLY on natural end
    case trackWasSkipped(Track)
    case progress(elapsed: TimeInterval, duration: TimeInterval)
    case failed(PlaybackFailure)
}

// Services/AdService.swift
protocol AdService: AnyObject, Sendable {
    func nextCreative() async throws -> AdCreative
    func play(_ creative: AdCreative) async throws   // returns when ad finishes
    func cancel() async
}

// Services/EntitlementService.swift
protocol EntitlementService: AnyObject, Sendable {
    var entitlement: Entitlement { get async }
    var updates: AsyncStream<Entitlement> { get }
    func refresh() async
    func purchase(_ tier: SubscriptionTier) async throws -> PurchaseOutcome
    func restore() async throws
}

enum Entitlement: Sendable, Equatable {
    case none
    case subscribed(tier: SubscriptionTier, expires: Date?)

    var suppressesAds: Bool { if case .subscribed = self { true } else { false } }
}
```

---

## 5. The ad-break state machine

`PlaybackCoordinator` is the only object allowed to move between music and ad. Views observe; they never drive.

```
                     trackDidComplete
   ┌──────────────┐   (+ policy says no)   ┌──────────────┐
   │  .playing    │◄───────────────────────┤  .playing    │
   └──────┬───────┘                        └──────────────┘
          │ trackDidComplete
          │ AdBreakPolicy.shouldTriggerBreak == true
          ▼
   ┌──────────────────────────────────────────────┐
   │ 1. musicService.pause()                      │
   │ 2. creative = try await adService.next()     │
   │ 3. state = .adBreak(creative)                │  ← AdBreakView appears
   │ 4. try await adService.play(creative)        │    (fullScreenCover)
   │ 5. counter.reset()                           │
   │ 6. musicService.resume()                     │
   └──────────────────────────────────────────────┘
          │ any throw in 2–4
          ▼
   fail-open: log, reset counter, resume music.
   An ad failure must NEVER strand the listener in silence.
```

**Entitlement gate is checked at step 0, not at render time.** If `entitlement.suppressesAds` is true the counter is not even incremented, and `.adBreak` is unreachable. A subscriber whose receipt refreshes mid-session gets ad suppression on the *next* track boundary, never mid-ad — cancelling a playing ad on a purchase is deliberately out of scope (see D-08).

```swift
// Domain/AdBreakPolicy.swift — pure. This is the most-tested type in the app.
struct AdBreakPolicy: Sendable, Equatable {
    var interval: Int = 3              // "[N]"
    var countsSkippedTracks: Bool      // see D-04

    func shouldTriggerBreak(tracksSinceLastBreak: Int, entitlement: Entitlement) -> Bool {
        guard !entitlement.suppressesAds else { return false }
        guard interval > 0 else { return false }
        return tracksSinceLastBreak >= interval
    }
}
```

Invariants worth asserting in tests:
- `interval <= 0` never triggers a break (guards a bad remote/config value).
- An entitled listener returns `false` for every counter value, including absurd ones.
- The counter resets to `0` after a break, so breaks land at N, 2N, 3N — not N, N+1, N+2.
- Entitlement flipping mid-count suppresses immediately without an off-by-one.

---

## 6. Liquid Glass boundary — normative

iOS 26's `glassEffect` is a *navigation-chrome* material. Apple's guidance is explicit that glass must not stack on glass, and must not sit on dense content. This table is the contract; anything not listed is **opaque by default** and requires a decision before it becomes glass.

| Surface | Layer | Treatment |
|---|---|---|
| Tab Bar | chrome | Native `TabView` glass capsule; Search as `Tab(role: .search)` so the system renders it as its own circular element — do not hand-build this |
| Player Bar (mini) | chrome | `.glassEffect(.regular.tint(.honeyAmber).interactive(), in: .capsule)`, inside `GlassEffectContainer` shared with the tab bar |
| Toolbars / nav bars | chrome | System default glass; do not override |
| Sheets / paywall presentation chrome | chrome | System default glass |
| Now Playing background (Liquid Mesh) | **content** | Opaque `MeshGradient`. No glass. |
| Album art + bass glow | **content** | Opaque. No glass. |
| Progress arc | **content** | Opaque stroke. No glass. |
| Transport buttons inside Now Playing | **content** | Opaque symbol buttons — they sit *on* the mesh, which is already a rich surface |
| Track rows / lists | **content** | Opaque. No glass. |
| Ad-Break screen (all of it) | **content** | Opaque sepia. Deliberately non-glass — it must read as a different context |
| Paywall body content | **content** | Opaque over Deep Onyx |

**Player Bar → Now Playing morph.** Both the collapsed bar and the expanded sheet's chrome carry `.glassEffectID(PlayerGlassID.bar, in: namespace)` with a shared `@Namespace`. The transition is a geometry morph of the *chrome only*; the Now Playing content crossfades in independently. Wrapping the content in the morph would drag opaque content through a glass transition and produce exactly the stacking artifact the split above exists to prevent.

**Reduce Transparency.** SwiftUI substitutes a solid material for `.glassEffect` automatically. The plan is to *verify* this on device with the setting enabled, not to hand-roll a parallel code path. The one thing that does need an explicit branch is the Liquid Mesh drift and the bass-reactive glow — those are content-layer motion, and `accessibilityReduceMotion` (separate setting) should freeze the drift to a static gradient.

**Containment rule:** `GlassSurface.swift` is the only file in the codebase permitted to call `.glassEffect()`. A grep for `glassEffect` returning a hit outside that file is a review failure. This makes the "no glass on content" criterion mechanically checkable.

---

## 7. Screen inventory

| Screen | ViewModel | Owns | Notes |
|---|---|---|---|
| **Home / Discover** | `HomeViewModel` | station list, featured | Content shape depends on **D-02** — Feed.fm is station-based, not on-demand |
| **Now Playing** | `PlayerViewModel` | current track, progress, transport | Reads coordinator; sends intents only |
| **Ad-Break** | `AdBreakViewModel` | countdown, ripple amplitude | Presented as `fullScreenCover` bound to `.adBreak` state. Not dismissible by gesture |
| **Library** | `LibraryViewModel` | favorites / followed stations | Scope depends on **D-02** and **D-07** |
| **Paywall** | `PaywallViewModel` | products, purchase state | Consider StoreKit 2's `SubscriptionStoreView` — see D-06 |

---

## 8. Configuration & secrets

```
Shared.xcconfig      →  Info.plist  →  AppEnvironment reads Bundle.main
FEEDFM_TOKEN         →  FeedFMToken
FEEDFM_SECRET        →  FeedFMSecret
```

`Config/Debug.xcconfig` and `Config/Release.xcconfig` are gitignored; `Config/Shared.xcconfig.example` is committed with empty values. CI injects real values from secrets. `AppEnvironment` fails fast with a clear fatal error in DEBUG if either key is empty — a silent no-audio failure is far worse than a crash on the first run after a fresh clone.

**Honest caveat, stated once here and again in D-03:** xcconfig keeps the credentials out of *version control*, which is the stated requirement and a real security gain. It does not keep them out of the *shipped binary* — anyone can extract them from an IPA. Feed.fm's client token/secret pair is designed to be client-side, so this is consistent with the vendor's model, but it should be a conscious acceptance rather than an assumption that the secret is protected.

---

## 9. Testing strategy

Swift Testing (`import Testing`), not XCTest — it is the Xcode 26 default and gives parameterized cases, which suit interval testing well.

| Suite | Covers | Style |
|---|---|---|
| `AdBreakPolicyTests` | every branch of `shouldTriggerBreak`, parameterized over N ∈ {1,2,3,5,10} and both entitlement states | pure, instant |
| `PlaybackCoordinatorTests` | counter increments, reset-after-break, break lands at N/2N/3N, ad-failure fail-open, entitlement flip mid-count | fakes for all three services |
| `EntitlementGatingTests` | `.subscribed` suppresses ads for both tiers; expired subscription does not; `.none` does not | fake entitlement service |

The fakes live in the test target and conform to the same protocols — which is the second reason the protocol boundary exists. Feed.fm, StoreKit, and audio hardware are all absent from the unit test run; nothing in the tested logic touches them.

Not unit-tested (verified manually, listed in the Phase 6 checklist): glass rendering, Reduce Transparency legibility, mesh gradient performance, real purchase flow.
