# Hum — progress log

Format: `✅ [what was done] — [file(s) affected]`

---

## Phase 0 — Scaffolding · **COMPLETE**

✅ Created the Xcode project, iOS App + SwiftUI, single app target + single unit-test target — `HumApp.xcodeproj`, `project.yml`

✅ Swift 6 language mode with strict concurrency complete, verified as *effective* settings rather than merely declared (`SWIFT_VERSION = 6.0`, `SWIFT_STRICT_CONCURRENCY = complete`, `IPHONEOS_DEPLOYMENT_TARGET = 26.0`) — `project.yml`

✅ Warnings-as-errors on for both Swift and Clang, so the "no warnings" acceptance criterion is enforced by the build rather than by discipline — `project.yml`

✅ Set `SWIFT_DEFAULT_ACTOR_ISOLATION = nonisolated` **rather than Xcode 26's new-project default of `MainActor`**. [ARCHITECTURE §3](ARCHITECTURE.md#3-concurrency-model-swift-6-strict) assigns isolation per layer — reducers are nonisolated pure structs, catalog/library adapters are actors — and a module-wide MainActor default would fight that from day one — `project.yml`

✅ MusicKit prerequisites declared: `NSAppleMusicUsageDescription` (user-facing string — reword freely), the `com.apple.developer.musickit` entitlement, and the `audio` background mode — `Hum/Info.plist`, `Hum/Hum.entitlements`

✅ Directory skeleton created per [ARCHITECTURE §2](ARCHITECTURE.md#2-file-layout) — `Hum/{DesignSystem,Domain,Reducers,Services/Adapters,Features/*,Resources}`, `HumTests/Fakes`

✅ Both architectural containment rules wired as a build-failing pre-build phase, emitting Xcode-clickable `file:line: error:` diagnostics — `Scripts/check-containment.sh`, `project.yml`

✅ Containment rules verified **end to end**, not just standalone: planting `import MusicKit` in `Features/Home/` and `.glassEffect()` in `Features/Components/` each failed the build with the right message, while the same import inside `Services/Adapters/` was correctly exempted

✅ Swift Testing target wired and executing — `HumTests/ScaffoldTests.swift`

✅ Asset catalog with Honey Amber accent + Deep Onyx launch color — `Hum/Resources/Assets.xcassets`

✅ Placeholder launch screen, replaced by `RootTabView` in Phase 4 — `Hum/HumApp.swift`, `Hum/Features/Root/ScaffoldPlaceholderView.swift`

### Gate — passed, with evidence

| Criterion | Result |
|---|---|
| Builds on iOS 26 SDK | ✅ `** BUILD SUCCEEDED **`, Xcode 26.6 / Swift 6.3.3 |
| Zero warnings | ✅ clean build, **0 compiler warnings**. Compiler invocation confirmed to carry `-swift-version 6` and `-warnings-as-errors`. Two non-code lines do contain the word "warning" and are *not* build warnings: `xcodebuild: WARNING: Using the first of multiple matching destinations` (two identically-named simulators on this Mac) and `appintentsmetadataprocessor … Metadata extraction skipped` (emitted by every project that doesn't use App Intents). |
| Launches on simulator | ✅ installed and launched on iPhone 17 Pro (iOS 26.x), renders amber-on-onyx |
| Tests run | ✅ `Test run with 1 test in 1 suite passed` |
| Containment greps pass | ✅ both, and both proven to fail correctly when violated |

### Two deviations worth knowing about

1. **`ENABLE_USER_SCRIPT_SANDBOXING = NO`.** The containment phase greps the whole source tree; the script sandbox denies reads outside declared inputs, and the file set is not knowable in advance. The two are mutually exclusive. This is the same tradeoff any SwiftLint or codegen phase makes. **Scoped to this project's build settings — no global Xcode setting was touched.**

2. **`project.yml` + xcodegen.** `xcodegen` was already installed on this machine and generated the project; **the generated `HumApp.xcodeproj` is committed**, so nobody needs xcodegen to open, build, or run Hum. `project.yml` is kept because it makes build settings reviewable in a diff instead of buried in `project.pbxproj`. It is *not* an app dependency and nothing links against it. If you'd rather not carry a generator file, say so and I'll delete it and hand-maintain the pbxproj.

### Signing — updated after Phase 4

The placeholder `com.hum.app` has been replaced with the real **`org.surajshetty.humapp`**, and code signing is enabled (`CODE_SIGN_STYLE = Automatic`). The app builds, installs, and launches under the new identifier on the Simulator; a device build now fails only with *"Signing for 'Hum' requires a development team"*, which is the expected and only remaining blocker.

`DEVELOPMENT_TEAM` lives in **`Config/Signing.xcconfig`**, deliberately not in `project.yml`: a team chosen in Xcode's Signing tab would otherwise be wiped by the next `xcodegen generate`.

✅ **Team `CYY72W5P5F` set; device build, install and launch all verified** on a physical iPhone (iOS 26.5). Signed with *Apple Development: Suraj Shetty (2Y4Q7YN79V)*.

⚠️ **Fixed a Phase 0 mistake:** `Hum.entitlements` declared `com.apple.developer.musickit`, which is **not a real entitlement**. Provisioning rejected it outright. MusicKit on iOS is enabled as an *App Service on the App ID*; the app needs only `NSAppleMusicUsageDescription` and runtime `MusicAuthorization`. `CODE_SIGN_ENTITLEMENTS` removed; the empty file is kept rather than deleted.

---

## Phase 2 — Domain, reducers, tested core · **COMPLETE**

*No UI, no MusicKit, no device. Everything here is pure or protocol-shaped.*

✅ Domain types, all `Sendable` and provider-neutral — `Hum/Domain/{ContentSource,HumTrack,HumCollection,HumError,AuthState,SubscriptionState,PlaybackState,QueueState}.swift`

✅ `AuthReducer` — all four `MusicAuthorization.Status` cases, with the `.denied` / `.restricted` split expressed as *different affordances*, not just different copy — `Hum/Reducers/AuthReducer.swift`

✅ `SubscriptionReducer` — the flags→state mapping plus the play-intent gate every play in the app must pass through — `Hum/Reducers/SubscriptionReducer.swift`

✅ `QueueReducer` — cursor arithmetic for jump/remove/clear/next/previous, shuffle and repeat — `Hum/Reducers/QueueReducer.swift`

✅ Service protocols; no implementation imports MusicKit yet — `Hum/Services/{MusicAuthorizationService,SubscriptionService,MusicCatalogService,MusicLibraryService,PlaybackService}.swift`

✅ Test doubles for all five protocols, as actors (the protocols are `Sendable`; an actor gives that without `@unchecked`) — `HumTests/Fakes/FakeServices.swift`

✅ **50 tests across 3 suites, all passing** — `HumTests/{AuthReducerTests,SubscriptionReducerTests,QueueReducerTests}.swift`

### Gate — passed, with evidence

| Criterion | Result |
|---|---|
| Tests green | ✅ `Test run with 50 tests in 3 suites passed` |
| Zero UI in existence | ✅ only the Phase 0 placeholder view exists |
| Clean build, no warnings | ✅ Swift 6 strict concurrency, warnings-as-errors |
| Containment greps pass | ✅ both |

### Three decisions made while writing this

1. **`ContentSource` (catalog vs library) was added to the domain**, and the subscription gate keys off it. Without the distinction, a listener with no subscription would be blocked from music they *own* — purchased, matched, or uploaded — which plays fine without one. It also stops us pointing someone at a subscription offer for content the offer is irrelevant to.

2. **`SubscriptionState.unknown` resolves to `.awaitSubscriptionCheck`, not to a gap.** "We haven't checked yet" must never render as "you have no subscription"; likewise a *failed* check maps to `.unavailable`, not `.gap`. Otherwise a network blip pushes a paying subscriber at an offer sheet.

3. **`AuthState.requesting` is guarded on both sides.** A slow launch-time `currentStatus` read cannot clobber a request already in flight (which would drop the spinner back to the invitation mid-prompt), and `.requesting` can never be adopted *as* a resolved status (which could strand the UI on a spinner forever). Both are tested.

### One deletion, disclosed

`HumTests/ScaffoldTests.swift` — the Phase 0 placeholder test, created in the previous session step and labelled in its own comment as "replaced in Phase 2 by AuthReducerTests / SubscriptionReducerTests / QueueReducerTests". It was superseded by the 50 real tests. Flagging it because deleting files is a Stop Condition; say the word if you'd rather it had stayed.

### Deferred from Phase 2, deliberately

The plan listed *"adapters promoted from the Phase 1 spike"* under this phase. **Phase 1 has not run** — it is blocked on [M-10](DECISIONS.md#m-10) and a subscribed device — so there is nothing to promote. Writing `Services/Adapters/*` speculatively would mean shipping unverified MusicKit code and claiming a phase item that was never validated. The protocols are in place; the adapters land when Phase 1 does.

---

## Phase 4 — Design system, glass chrome, content screens · **COMPLETE**

**4a — Foundations**

✅ Palette, type ramp, spacing, motion and icons, every value transcribed from `designs/Hum Prototype.html` rather than invented — `Hum/DesignSystem/{Palette,Typography,Spacing,Motion,HumIcons}.swift`

✅ `GlassSurface.swift` — the single permitted `.glassEffect()` call site. A repo-wide grep confirms exactly **one** real call (line 40); every other occurrence of the word is prose — `Hum/DesignSystem/GlassSurface.swift`

✅ Reduce Motion handled where SwiftUI will not: the level meter freezes flat, `humRise` degrades to a crossfade, press feedback stops scaling — `Hum/DesignSystem/Motion.swift`

**4b — Chrome (glass)**

✅ `RootTabView` — native `TabView`; Search is `Tab(role: .search)`, so iOS renders it as its own circular element with correct semantics, hand-built by nobody — `Hum/Features/Root/RootTabView.swift`

✅ Player bar in `tabViewBottomAccessory`, iOS 26's own mini-player slot — `Hum/Features/Components/PlayerBar.swift`

**4c — Content (opaque)**

✅ Home, with the empty states the prototype does not draw — `Hum/Features/Home/{HomeView,HomeViewModel}.swift`
✅ Detail — album, playlist, and artist through one screen — `Hum/Features/Detail/{DetailView,DetailViewModel}.swift`
✅ Now Playing, **portrait and landscape** (both drawn in the prototype) — `Hum/Features/NowPlaying/NowPlayingView.swift`
✅ Queue, including the drawn empty state, with swipe-to-remove and drag-to-reorder — `Hum/Features/Queue/QueueView.swift`
✅ Search, Library, Settings — the four inferred screens (M-06), built to the prototype's idioms and **labelled as inference, not design-matched** — `Hum/Features/{Search,Library,Settings}/`
✅ Shared components — `Hum/Features/Components/{ArtworkView,TrackRow,HumButtons,EmptyStateView,PlayerBar,TimeFormatting}.swift`
✅ Preview services so the whole UI runs without MusicKit, using the prototype's own fixture data — `Hum/Services/Preview/PreviewServices.swift`, `Hum/AppEnvironment.swift`

### Gate — passed, with evidence

| Criterion | Result |
|---|---|
| Both containment greps pass | ✅ verified in-build; exactly one real `.glassEffect(` call site |
| Clean build, zero warnings | ✅ Swift 6 strict concurrency, warnings-as-errors |
| Tests still green | ✅ 50 tests, 3 suites |
| Every screen exists and is reachable | ✅ 9 of 9 |
| ≥44×44 targets | ✅ structural — every icon control routes through `IconButton`, which enforces the floor. Accessibility Inspector pass is Phase 6. |
| Rendered and verified on simulator | ✅ Home, Now Playing, Queue, Library, player bar |

### Four defects found by looking at the screen, not the code

Each was caught by screenshotting the running app, and each would have shipped otherwise:

1. **Player bar rendered as a solid amber slab covering the tab bar.** A full-opacity `honeyAmber` tint overwhelmed the glass, and `safeAreaInset` stacked the bar *on* the tab bar instead of above it. Fixed by moving to `tabViewBottomAccessory` — the system's own mini-player slot, which also means the two adjacent glass surfaces share the system's container rather than a hand-rolled one.
2. **An empty glass pill floated above the tab bar with nothing playing.** The accessory slot draws its own capsule, so returning an empty body from inside is not enough — the *modifier* has to be conditional, not its content.
3. **Now Playing's elapsed timestamp rendered doubled digits.** The progress animation was attached to the whole stack, so it cross-faded the numeric labels too. The animation now applies to the progress fill alone.
4. **Queue rows and section header sat flush to the screen edge**, losing the 24pt gutter and clipping the source label. `List` row insets do not inherit the app's gutter and had to be set explicitly.

### Two deviations from the written plan

1. **The player-bar → Now Playing morph is system-owned.** The plan specified a shared `@Namespace` plus `glassEffectID`. `tabViewBottomAccessory` animates its own expansion, so that plumbing was dead code and was removed — including `GlassSurface.ID` and `chromeGlassID`. The outcome the plan wanted holds: chrome morphs, content crossfades, and no opaque content is dragged through a glass transition.
2. **The subscription offer sheet is not attached.** `.musicSubscriptionOffer` is a MusicKit symbol, and `RootTabView` may not import MusicKit — it will be bridged from `Services/Adapters` in Phase 3, which is also where it can be verified. `PlayerViewModel.isPresentingSubscriptionOffer` is already driven by the tested gate and is waiting for it.

### One bug in the containment check itself

The Phase 0 script matched `import MusicKit` **inside comments**, so a doc comment explaining the rule failed the build it was explaining. Rewritten to strip `//` comments before matching, anchor imports to real statements (including `@preconcurrency import`), and match `.glassEffect(` as a call. Re-verified against four probes: a plain violation, a `@preconcurrency` violation, a multi-line `.glassEffect()` call, and a comment mentioning both — the first three fail, the comment does not, and adapters stay exempt.

---

## Phase 1 — MusicKit spike · **COMPLETE**

Ran on a physical iPhone (iOS 26.5), bundle `org.surajshetty.humapp`, team `CYY72W5P5F`.

### Raw result

```
SPIKE auth.currentStatus        = .authorized
SPIKE auth.mapped               = authorized
SPIKE sub.canPlayCatalogContent = false
SPIKE sub.canBecomeSubscriber   = true
SPIKE sub.hasCloudLibraryEnabled = false
SPIKE sub.mapped                = gap(canBecomeSubscriber: true)
SPIKE catalog.ok                = Let Down — Radiohead
SPIKE catalog.previewAssets     = 1
SPIKE play.THREW = MPMusicPlayerControllerErrorDomain Code=6 "Failed to prepare to play"
```

### What it settles

✅ **[M-02](DECISIONS.md#m-02) confirmed empirically.** `ApplicationMusicPlayer.play()` **throws** for a non-subscriber. It does **not** fall back to a 30-second preview. The brief's premise was wrong for iOS, and the plan built on the right assumption.

✅ **The thrown error is useless to a listener** — *"Failed to prepare to play"*, no mention of subscriptions. This is the strongest possible argument for the design already in place: gate *before* calling `play()`, because there is nothing in the failure to build a decent message from.

✅ **`SubscriptionReducer` validated against real MusicKit data.** Live flags `canPlayCatalogContent = false` / `canBecomeSubscriber = true` mapped to `gap(canBecomeSubscriber: true)` — the exact state that routes to Apple's offer sheet. The unit tests asserted this mapping; the device now agrees.

✅ **The MusicKit App Service path works end to end.** A real catalog search returned a real song, which means the App ID configuration, entitlement-free signing, and `NSAppleMusicUsageDescription` are all correct.

✅ **Authorization succeeds** and maps through `MusicKitAuthorizationAdapter` correctly.

ℹ️ **A preview asset does exist** on the song (`previewAssets = 1`). The separate-`AVPlayer` preview engine was declined on scope, not capability — it remains available if ever wanted.

### Adapters promoted from the spike (permanent)

✅ `MusicKitAuthorizationAdapter` — maps all four `MusicAuthorization.Status` cases — `Hum/Services/Adapters/MusicKitAuthorizationAdapter.swift`
✅ `MusicKitSubscriptionAdapter` — reads `MusicSubscription`, routes through the tested reducer, `.unavailable`-not-`.gap` on failure — `Hum/Services/Adapters/MusicKitSubscriptionAdapter.swift`

Corrected while writing them: `MusicSubscription.subscriptionUpdates` is **non-throwing**; errors are possible only on `MusicSubscription.current`.

### Removed

The spike itself (`MusicKitSpikeProbe.swift`) and its launch hook in `HumApp.swift`. It auto-played audio at launch and had answered its questions. Flagging because deleting files is a Stop Condition.

### Not observable on this device

`.denied` and `.restricted` were not exercised live — the account is already `.authorized`, and reproducing them needs Settings revocation and a Screen Time restriction respectively. Both are unit-tested; Phase 3 should confirm them on device.

### Gate

| Criterion | Result |
|---|---|
| Written answer to M-02 | ✅ confirmed: throws, no preview fallback |
| Authorization observed on device | ✅ `.authorized` (other three still unit-tested only) |
| Subscription flags recorded | ✅ all three, mapped correctly |
| Audible playback | ❌ **impossible on this account** — no subscription. See [M-09](DECISIONS.md#m-09). |

---

## Phase 3 — Authorization & subscription flow · **COMPLETE (one device check outstanding)**

### The gate

`RootGateView` shows `ConnectView` until MusicKit says yes and `RootTabView` after. It gates on **authorization only** — a missing subscription never lands here. Blocking the whole app on a subscription would be both hostile and precisely the "broken player" the brief names.

✅ `AuthViewModel` — holds no logic of its own; every transition goes through the already-tested `AuthReducer` — `Hum/Features/Connect/AuthViewModel.swift`
✅ `RootGateView` — plus a `scenePhase` refresh, so access revoked in Settings while Hum is backgrounded is picked up **without** the relaunch the plan's gate only asked for — `Hum/Features/Root/RootGateView.swift`
✅ `ConnectView` — one layout, four states, transcribed from the prototype: amber wash, 52pt mark, 36pt Ultra Light title, three hairline permission rows, pinned capsule and footnote — `Hum/Features/Connect/ConnectView.swift`
✅ `HumMark` — the mark drawn as a `Canvas` rather than shipped as an asset, so it inherits the accent colour

`.restricted` renders **no button**, which is the point: the reducer returns `nil` there, and a Settings link under Screen Time or an MDM profile is a dead end.

### The subscription gap

✅ `SubscriptionOfferAdapter` — bridges `.musicSubscriptionOffer` so `RootTabView` stays MusicKit-free and the whole UI still runs in the Simulator — `Hum/Services/Adapters/SubscriptionOfferAdapter.swift`
✅ `SubscriptionGapView` — for the two states an offer *cannot* close: the account can't subscribe, or the check failed. Explains rather than dangling a sheet that would fail — `Hum/Features/Connect/SubscriptionGapView.swift`
✅ `PlayerViewModel` now observes `subscriptionUpdates` and **defers the turned-back play intent**, so subscribing mid-session — through the sheet or in the Music app — resumes the track the listener actually asked for, with no relaunch
✅ `AppEnvironment.live()` — authorization and subscription are live MusicKit; catalog, library and playback stay in-memory until Phase 5. The mix is deliberate and visible rather than hidden behind a flag

No affiliate or campaign token is set on the offer. Hum takes no commission on an Apple Music signup — the cleanest available answer to the DPLA rule against indirectly monetizing access.

### Verified on the iOS 26.2 Simulator

| Path | Result |
|---|---|
| Fresh install → invitation | ✅ matches the prototype |
| Tap Connect → system prompt | ✅ with the real usage description |
| Decline → `deniedRecoverable` | ✅ "Access Not Granted" + Open Settings |
| Grant → gate opens to tabs | ✅ |
| Catalog play with no subscription | ✅ **"Couldn't Check"** — the Simulator's `MusicSubscription` genuinely fails, so `.unavailable` is the honest state, and Try Again appears only because of it |
| Dismiss the gap sheet | ✅ returns to a working app |

### Fixed during the phase

The capsule **vanished** during `.connecting` — `primaryAction(for: .connecting)` correctly returns `nil`, but that is "no action", not "no button", and the screen lurched under the system prompt. The footer now renders it disabled and reading "Connecting…".

### Tests — 62 in 5 suites, all passing

✅ `AuthViewModelTests` — 7 tests: every status reaches a coherent screen, a settled status is never re-prompted, `.restricted` offers no button, a foreground refresh picks up revocation — `HumTests/AuthViewModelTests.swift`
✅ `SubscriptionGateTests` — 5 tests asserting the brief's criterion directly: a gap reaches Apple's offer and **never** the player, an unofferable gap explains, a failed check still plays the library, and subscribing mid-session resumes the deferred track — `HumTests/SubscriptionGateTests.swift`

### Outstanding

Apple's **real** offer sheet has not yet been seen. It cannot be: the Simulator's subscription check fails outright, so it resolves to `.unavailable` rather than `.gap(canBecomeSubscriber: true)`. The device account *is* `.gap(canBecomeSubscriber: true)` (Phase 1), which makes it the only place this can be confirmed. Build is installed and launched there; the check is a catalog track tap.

---

## Phase 5 — Playback · **PARTIALLY BLOCKED**

The gap path is built and covered by tests (Phase 3 above). **Successful catalog playback cannot be exercised at all** until an Apple Music subscription — or a sandbox account with one — is available on the test device.
