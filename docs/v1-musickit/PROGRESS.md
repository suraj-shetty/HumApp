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

### Not done in Phase 0, deliberately

Code signing is off (`CODE_SIGNING_ALLOWED = NO`) and the bundle ID is the placeholder `com.hum.app`. Both flip once [M-10](DECISIONS.md#m-10) supplies the real bundle ID, team, and a MusicKit-enabled App ID.

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

## Phase 1 — MusicKit spike · **BLOCKED**

Blocked on [M-10](DECISIONS.md#m-10) (bundle ID, team, MusicKit-enabled App ID) **and** a physical device with an active Apple Music subscription ([M-09](DECISIONS.md#m-09)). Neither is available yet.

**Phase 2 (domain, reducers, the three test suites) is not blocked** and builds entirely against fakes — it is the correct next step while M-10 is outstanding.
