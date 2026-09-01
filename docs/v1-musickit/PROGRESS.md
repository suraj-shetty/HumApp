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

`DEVELOPMENT_TEAM` lives in **`Config/Signing.xcconfig`**, deliberately not in `project.yml`: a team chosen in Xcode's Signing tab would otherwise be wiped by the next `xcodegen generate`. Verified that the xcconfig value reaches the build settings.

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

## Phase 1 — MusicKit spike · **BLOCKED**

Blocked on the **Team ID** ([M-10](DECISIONS.md#m-10) — bundle ID and MusicKit service are now supplied) **and** a physical device with an active Apple Music subscription ([M-09](DECISIONS.md#m-09)).

Phases 0, 2 and 4 are complete and built entirely against preview services. **Phase 3 (authorization flow) and Phase 5 (real playback) are the remaining work, and both need the device.**
