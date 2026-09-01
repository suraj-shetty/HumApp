# Hum v1 (MusicKit) — Architecture

**Status:** proposed. Nothing implemented.
**Target:** iOS 26.0+, Swift 6 (strict concurrency = complete), SwiftUI, MVVM + a pure reducer core.
**Toolchain verified on this machine:** Xcode 26.6 · Swift 6.3.3 · iOS 26.5 simulator runtime.
**Supersedes** [`docs/ARCHITECTURE.md`](../ARCHITECTURE.md) (Feed.fm + ads + StoreKit — obsolete for this brief).

---

## 1. Pattern choice, stated plainly

The brief asks for "MVVM, TCA etc." TCA is a third-party package, and packages are a Stop Condition. **Resolved in [M-01](DECISIONS.md#m-01): TCA was a recommendation, not a requirement — no package is added.** What ships is **MVVM with a TCA-shaped core**, which is three concrete things:

1. **Views are dumb.** Zero business logic, zero `import MusicKit`. They read `@Observable` state and send intents.
2. **ViewModels own state and orchestration.** `@MainActor @Observable final class`. They talk to protocols, never to MusicKit.
3. **The parts that are hard to get right are pure functions.** Authorization gating, subscription gating, and queue mutation are expressed as `(State, Action) -> State` reducers with no I/O. This is the one idea borrowed from TCA, and it is why the three named unit-test criteria are cheap to satisfy — a reducer test needs no simulator, no device, no account. If TCA is ever wanted, these functions lift into `@Reducer` mechanically.

Layer map:

```
┌──────────────────────────────────────────────────────────────┐
│ View (SwiftUI) — no logic, no MusicKit import                │
│ RootTabView · ConnectView · HomeView · SearchView            │
│ DetailView(album|playlist|artist) · NowPlayingView           │
│ QueueView · SettingsView · PlayerBar · TrackRow              │
└───────────────▲──────────────────────────────────────────────┘
                │ reads @Observable, sends intents
┌───────────────┴──────────────────────────────────────────────┐
│ ViewModel (@MainActor @Observable)                           │
│ AuthViewModel · HomeViewModel · SearchViewModel              │
│ LibraryViewModel · DetailViewModel · PlayerViewModel         │
│ QueueViewModel · SettingsViewModel                           │
└───────────────▲──────────────────────────────────────────────┘
                │ dispatches Actions, observes State
┌───────────────┴──────────────────────────────────────────────┐
│ Pure reducers (Sendable structs — NO I/O, NO async)          │
│ AuthReducer · SubscriptionReducer · QueueReducer             │
│  ← the three named unit-test criteria live entirely here     │
└───────────────▲──────────────────────────────────────────────┘
                │ fed by
┌───────────────┴──────────────────────────────────────────────┐
│ Service protocols                                            │
│ MusicAuthorizationService · SubscriptionService              │
│ MusicCatalogService · MusicLibraryService · PlaybackService  │
└──────┬─────────────────────────────────────┬─────────────────┘
       │                                     │
┌──────▼──────────────────────┐  ┌───────────▼─────────────────┐
│ Adapters/  — the ONLY files │  │ Test + Preview fakes        │
│ that `import MusicKit`      │  │ (no MusicKit, no hardware)  │
└─────────────────────────────┘  └─────────────────────────────┘
```

**Two mechanically-checkable containment rules.** Both are grep-able, which is the point — an architectural rule nobody can verify is a wish.

| Rule | Check |
|---|---|
| Only `Services/Adapters/*` may `import MusicKit` | `grep -rln "import MusicKit" Hum/ \| grep -v "Services/Adapters/"` → empty |
| Only `DesignSystem/GlassSurface.swift` may call `.glassEffect()` | `grep -rn "glassEffect" Hum/ \| grep -v GlassSurface.swift` → empty |

The first rule is what makes the whole UI buildable in the Simulator against fakes, despite MusicKit not working there ([M-09](DECISIONS.md#m-09)).

---

## 2. File layout

Single app target, single unit-test target. No SPM sub-modules — the layering is held by the two grep rules above, and a multi-module split exceeds the requested scope.

```
HumApp/
├── HumApp.xcodeproj
├── Hum/
│   ├── HumApp.swift                  # @main — composition root
│   ├── Info.plist                    # NSAppleMusicUsageDescription
│   ├── Hum.entitlements              # MusicKit capability
│   ├── AppEnvironment.swift          # wires live adapters vs fakes
│   │
│   ├── DesignSystem/
│   │   ├── Palette.swift             # tokens from the prototype
│   │   ├── Typography.swift          # SF Pro Display ramp
│   │   ├── Spacing.swift             # 24pt gutter, 14pt row rhythm
│   │   ├── HumIcons.swift            # SF Symbol mapping
│   │   └── GlassSurface.swift        # THE ONLY .glassEffect() call site
│   │
│   ├── Domain/                       # provider-neutral, Sendable, no MusicKit
│   │   ├── HumTrack.swift
│   │   ├── HumCollection.swift       # album | playlist | artist, one shape
│   │   ├── AuthState.swift
│   │   ├── SubscriptionState.swift
│   │   ├── PlaybackState.swift
│   │   ├── QueueState.swift
│   │   └── HumError.swift
│   │
│   ├── Reducers/                     # pure. no I/O. 100% of the test criteria
│   │   ├── AuthReducer.swift
│   │   ├── SubscriptionReducer.swift
│   │   └── QueueReducer.swift
│   │
│   ├── Services/
│   │   ├── MusicAuthorizationService.swift   # protocol
│   │   ├── SubscriptionService.swift         # protocol
│   │   ├── MusicCatalogService.swift         # protocol
│   │   ├── MusicLibraryService.swift         # protocol
│   │   ├── PlaybackService.swift             # protocol
│   │   └── Adapters/                         # ONLY these import MusicKit
│   │       ├── MusicKitAuthorizationAdapter.swift
│   │       ├── MusicKitSubscriptionAdapter.swift
│   │       ├── MusicKitCatalogAdapter.swift
│   │       ├── MusicKitLibraryAdapter.swift
│   │       └── ApplicationMusicPlayerAdapter.swift
│   │
│   ├── Features/
│   │   ├── Root/RootTabView.swift
│   │   ├── Connect/{ConnectView,AuthViewModel}.swift
│   │   ├── Home/{HomeView,HomeViewModel}.swift
│   │   ├── Search/{SearchView,SearchViewModel}.swift
│   │   ├── Library/{LibraryView,LibraryViewModel}.swift
│   │   ├── Detail/{DetailView,DetailViewModel}.swift
│   │   ├── NowPlaying/{NowPlayingView,NowPlayingLandscapeView,PlayerViewModel}.swift
│   │   ├── Queue/{QueueView,QueueViewModel}.swift
│   │   ├── Settings/{SettingsView,SettingsViewModel}.swift
│   │   └── Components/{PlayerBar,TrackRow,ArtworkView,EmptyStateView,SubscriptionGapView}.swift
│   └── Resources/Assets.xcassets
└── HumTests/
    ├── AuthReducerTests.swift          # criterion 1
    ├── SubscriptionReducerTests.swift  # criterion 2
    ├── QueueReducerTests.swift         # criterion 3
    └── Fakes/{FakeAuthService,FakeSubscriptionService,FakePlaybackService,FakeCatalogService}.swift
```

---

## 3. Concurrency model (Swift 6 strict)

MusicKit is a modern Swift framework, so the friction here is far lower than the Feed.fm plan budgeted for. The real edges:

| Component | Isolation | Note |
|---|---|---|
| Views | `@MainActor` (implicit) | — |
| ViewModels | `@MainActor @Observable final class` | drive UI directly |
| Reducers | `struct: Sendable` | pure, no isolation |
| Domain types | `struct: Sendable, Equatable` | free to cross boundaries |
| `MusicAuthorizationService` | `protocol: Sendable`; adapter `@MainActor` | `MusicAuthorization.request()` is `@MainActor` |
| `SubscriptionService` | `protocol: Sendable`; adapter is an `actor` | `MusicSubscription.current` is `async throws`; `subscriptionUpdates` is an `AsyncSequence` |
| `PlaybackService` | `protocol: Sendable`; adapter `@MainActor` | `ApplicationMusicPlayer.shared` is main-actor-bound; its `.state` is an `ObservableObject`, **not** `@Observable` |
| Catalog / Library adapters | `actor` | request execution is async and off-UI |

**Three known frictions to budget for:**

1. **`ApplicationMusicPlayer.State` is an `ObservableObject`, not `@Observable`.** It will not participate in `@Observable` tracking. The adapter must bridge it — subscribe to its `objectWillChange` (or poll `playbackStatus` on a timer for `playbackTime`) and republish as a `Sendable` `PlaybackSnapshot` through an `AsyncStream`. Do not try to hand the raw `State` to a SwiftUI view; that leaks MusicKit past the adapter and mixes two observation systems.
2. **`playbackTime` has no change notification.** Progress must be driven by a `MainActor` timer in the adapter (or a `TimelineView` in the view reading a snapshot). Plan for ~4 Hz; 60 Hz is wasted work.
3. **MusicKit's `MusicItemCollection` types are `Sendable`, but map them to `HumTrack` at the adapter boundary anyway** — inside the same function that received them. This keeps the type-erasure honest and keeps `MusicKit` out of every layer above.

---

## 4. Core contracts

```swift
// Domain — nothing MusicKit-shaped leaks upward.
struct HumTrack: Sendable, Identifiable, Equatable {
    let id: String                  // MusicItemID.rawValue
    let title: String
    let artist: String
    let albumTitle: String?
    let duration: TimeInterval
    let artworkURL: URL?            // resolved via Artwork.url(width:height:)
    let isPlayable: Bool            // catalog track + no subscription => false
}

enum AuthState: Sendable, Equatable {
    case notDetermined
    case requesting
    case authorized
    case denied                     // user said no — recoverable via Settings
    case restricted                 // MDM / parental — NOT user-recoverable
}

enum SubscriptionState: Sendable, Equatable {
    case unknown                    // not yet checked
    case active                     // canPlayCatalogContent == true
    case gap(canBecomeSubscriber: Bool)   // no sub; offer the trial if true
    case unavailable(reason: String)      // check failed
}

enum PlaybackState: Sendable, Equatable {
    case idle
    case loading
    case playing(HumTrack)
    case paused(HumTrack)
    case failed(HumError)
}
```

```swift
// Services — protocols only. Views and ViewModels see nothing else.
protocol MusicAuthorizationService: Sendable {
    var current: AuthState { get async }
    func request() async -> AuthState
}

protocol SubscriptionService: Sendable {
    var current: SubscriptionState { get async }
    var updates: AsyncStream<SubscriptionState> { get }
}

protocol PlaybackService: AnyObject, Sendable {
    var snapshots: AsyncStream<PlaybackSnapshot> { get }
    func play(_ tracks: [HumTrack], startingAt index: Int) async throws
    func resume() async throws
    func pause() async
    func skipToNext() async throws
    func skipToPrevious() async throws
    func seek(to time: TimeInterval) async          // see M-08
    func setQueue(_ tracks: [HumTrack]) async throws
}

struct PlaybackSnapshot: Sendable, Equatable {
    let state: PlaybackState
    let elapsed: TimeInterval
    let duration: TimeInterval
    let queue: [HumTrack]
    let currentIndex: Int?
    let shuffleEnabled: Bool
    let repeatMode: RepeatMode
}
```

---

## 5. The three tested reducers

These are the acceptance criteria, expressed as pure functions. Every branch is reachable from a unit test with no device, no account, no MusicKit.

### 5a. `AuthReducer` — all four `MusicAuthorization.Status` cases

```
.notDetermined  →  Connect screen, primary action = "Connect Apple Music"
.requesting     →  Connect screen, spinner (prototype draws this)
.authorized     →  root tabs; kick off the subscription check
.denied         →  Connect screen, copy changes, action = open Settings.app
.restricted     →  Connect screen, copy explains it is device-managed,
                   NO action button (a Settings deep-link is a dead end here —
                   the user genuinely cannot grant it)
```

The `.denied` / `.restricted` split is the part most builds get wrong: they show the same "go to Settings" button for both, and for `.restricted` that button leads nowhere. Tested explicitly.

### 5b. `SubscriptionReducer` — the subscription gap

Input is `MusicSubscription`'s three flags; output is what the UI does.

| `canPlayCatalogContent` | `canBecomeSubscriber` | Result | UI |
|---|---|---|---|
| `true` | — | `.active` | Normal. Play freely. |
| `false` | `true` | `.gap(canBecomeSubscriber: true)` | **`.musicSubscriptionOffer(isPresented:options:)`** — Apple's own trial-membership sheet. This is the criterion's "trial-membership prompt". |
| `false` | `false` | `.gap(canBecomeSubscriber: false)` | Explain, don't offer. Offering a trial that can't be taken is worse than saying nothing. Library-only content still plays. |
| check threw | — | `.unavailable` | Degrade to library-only; do not block the app. |

**Invariant under test:** a `.gap` state never produces a broken player. Play intents in `.gap` route to the offer sheet or the explanation — never to `ApplicationMusicPlayer.play()`, which would throw ([M-02](DECISIONS.md#m-02)).

**Compliance note:** the offer sheet is Apple's, presented at the point of need. It is not a paywall — Hum charges nothing and gates nothing of its own. That distinction is what keeps this inside the DPLA rule against monetizing access to Apple Music.

### 5c. `QueueReducer` — queue state management

The prototype's Queue screen defines the required actions: `jump(to:)`, `remove(at:)`, `clear()`, `refillFromCollection()`, plus `next` / `previous` / `shuffle` / `repeat`.

```swift
struct QueueReducer: Sendable {
    static func reduce(_ state: QueueState, _ action: QueueAction) -> QueueState
}
```

Invariants worth asserting:
- `currentIndex` stays valid after any `remove` — removing *below* the cursor shifts it down; removing *at* the cursor advances to the next entry; removing the last entry leaves `nil`.
- `clear()` empties up-next but **does not stop the current track** (the prototype's empty state says "when this track ends, playback stops" — so clear is non-destructive to what's audible).
- `jump(to:)` on an out-of-range index is a no-op, not a crash.
- `next` at the end with repeat off → `nil` current, `.idle`; with repeat on → wraps to 0.
- Shuffle changes presentation order without losing the current track's identity.
- Every reduction is idempotent in the sense that reducing over the same action twice never produces an index outside `0..<count`.

The reducer is pure; the adapter then mirrors the resulting order onto `ApplicationMusicPlayer.shared.queue`. Keeping the *decision* pure and the *effect* in the adapter is what makes this testable without a player.

---

## 6. Liquid Glass boundary — normative

Carried forward from the Feed.fm plan (the one part of it that survives), reconciled against the prototype. Anything not listed is **opaque by default**.

| Surface | Layer | Treatment |
|---|---|---|
| Tab Bar (Home · Search · Library) | chrome | Native `TabView`; **`Tab(role: .search)`** so the system renders Search as its own element with correct semantics. Do not hand-build. |
| Player Bar capsule | chrome | `.glassEffect(.regular.tint(.honeyAmber).interactive(), in: .capsule)`, in a `GlassEffectContainer` shared with the tab bar |
| Nav bars / toolbars | chrome | System default. Do not override. |
| Sheets (subscription offer, queue if presented modally) | chrome | System default |
| Toasts (e.g. "Skip unavailable") | chrome | `.glassEffect(in: .capsule)` |
| Connect screen body | **content** | Opaque onyx + radial amber wash |
| Album / playlist / artist artwork | **content** | Opaque |
| Now Playing background | **content** | Opaque `#0A0A0A` + radial amber gradient, per prototype |
| Progress bar + transport buttons | **content** | Opaque — including the 76pt play button, see [M-07](DECISIONS.md#m-07) |
| Track rows, lists, grids | **content** | Opaque |
| Queue screen | **content** | Opaque |
| Empty / error / subscription-gap states | **content** | Opaque |

**Player Bar → Now Playing morph.** Both carry `.glassEffectID(PlayerGlassID.bar, in: namespace)` on a shared `@Namespace`. The **chrome** morphs; the Now Playing **content crossfades independently**. Dragging opaque content through a glass morph produces exactly the stacking artifact this split exists to prevent.

**Reduce Transparency.** SwiftUI substitutes a solid material for `.glassEffect` automatically. The work is *verifying* amber-on-solid stays legible — not hand-rolling a parallel path. **Reduce Motion** is a separate setting and needs an explicit branch for the Queue screen's animated level bars and the `humRise` entry animations.

---

## 7. Compliance, mapped to code

Each DPLA rule from the brief, and the specific place it is honoured or checked.

| Rule | Where it lives |
|---|---|
| No monetization of Apple Music access | No StoreKit, no ads, no gating. The only commerce surface is Apple's own `MusicSubscriptionOffer`. Checkable: `grep -r "import StoreKit" Hum/` → empty. |
| Standard, user-initiated transport only | `ApplicationMusicPlayerAdapter` is the sole playback surface; it calls `play/pause/skipToNextEntry/skipToPreviousEntry/playbackTime` and nothing else. No auto-play on launch, no forced playback. |
| No download / cache / export of MusicKit content | [M-11](DECISIONS.md#m-11) — no local store at all. Artwork uses `AsyncImage` on `Artwork.url(...)` (system URL cache only). No share/export affordance anywhere. |
| Art & metadata only alongside playback/library | Artwork appears only on Home/Detail/Now Playing/Queue/PlayerBar. No marketing screen, no onboarding carousel using catalog art. |
| Check `MusicSubscription.current` before playback | `SubscriptionReducer` (§5b) gates every play intent. The `.gap` → offer-sheet path is unit-tested. |

---

## 8. Testing strategy

Swift Testing (`import Testing`), Xcode 26 default — parameterized cases suit the reducer tables well.

| Suite | Covers | Style |
|---|---|---|
| `AuthReducerTests` | all four `MusicAuthorization.Status` cases → correct screen, correct action, `.restricted` has **no** Settings button | pure, instant |
| `SubscriptionReducerTests` | the four-row table in §5b; play-intent-in-gap never reaches the player; check-failure degrades rather than blocks | pure, instant |
| `QueueReducerTests` | every invariant in §5c, parameterized over queue lengths and cursor positions | pure, instant |

Not unit-tested — verified manually and listed in the Phase 6 checklist: glass rendering, Reduce Transparency legibility, real authorization prompt, real subscription detection, audible playback, lock-screen controls. All of these need a device ([M-09](DECISIONS.md#m-09)).
