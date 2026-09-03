# Hum v1 (MusicKit) — Development Plan

**Supersedes** [`docs/DEVELOPMENT_PLAN.md`](../DEVELOPMENT_PLAN.md) (Feed.fm + ads + StoreKit — obsolete).
**Preconditions:** [M-01](DECISIONS.md#m-01), [M-02](DECISIONS.md#m-02) and [M-04](DECISIONS.md#m-04) are **resolved** — MVVM + reducer core with no package, no preview engine, Add-to-Library instead of love.

**Phases 0, 2 and 4 are unblocked and build against fakes.** **Phases 1, 3, 5 and 6 need [M-10](DECISIONS.md#m-10)** (bundle ID, team, MusicKit-enabled App ID — deferred to you) **and a physical device with an active Apple Music subscription** ([M-09](DECISIONS.md#m-09)).

Seven phases, each with a demonstrable exit gate. No phase starts before the previous gate passes. The ordering front-loads the two things that can invalidate finished work: the MusicKit authorization/subscription reality (Phase 1) and the glass boundary (Phase 4).

Progress format from Phase 0 onward: `✅ [what was done] — [file(s) affected]`

---

## Phase 0 — Scaffolding
*No blockers. Can start immediately.*

1. Create `HumApp.xcodeproj` — iOS App, SwiftUI, **Swift 6 language mode**, deployment target **iOS 26.0**.
2. **Strict concurrency = complete** from day one. Retrofitting it is materially harder than starting with it.
3. `SWIFT_TREAT_WARNINGS_AS_ERRORS = YES` — the acceptance criterion is "no warnings", so let the build enforce it rather than relying on discipline.
4. `NSAppleMusicUsageDescription` in Info.plist; MusicKit entitlement in `Hum.entitlements`. Placeholder bundle ID `com.hum.app` pending M-10.
5. Add `HumTests` target (Swift Testing).
6. Create the directory skeleton from [ARCHITECTURE.md §2](ARCHITECTURE.md#2-file-layout).
7. Add the two containment greps as a **Run Script build phase** that fails the build. Rules nobody can check are wishes:
   ```
   ! grep -rln "import MusicKit" Hum/ | grep -qv "Services/Adapters/"
   ! grep -rn  "glassEffect"      Hum/ | grep -qv "GlassSurface.swift"
   ```

**Gate:** empty app builds and launches on the iOS 26.5 simulator. Zero warnings. Both greps pass.

---

## Phase 1 — MusicKit spike (de-risk before building on it)
*Blocked on [M-10](DECISIONS.md#m-10) + a subscribed device. Deliberately throwaway-tolerant — its job is to answer questions.*

1. `MusicAuthorization.request()` on device. Observe **all four** statuses for real: grant it, deny it, and confirm what `.restricted` actually reports (Screen Time → Content Restrictions can produce it).
2. `MusicSubscription.current` and `MusicSubscription.subscriptionUpdates`. Record the exact flag combination for: active subscriber · lapsed · never-subscribed · not signed in.
3. **Confirm [M-02](DECISIONS.md#m-02) empirically:** with no subscription, call `ApplicationMusicPlayer.shared.play()` on a catalog song and record the exact error. Confirm it does *not* silently produce a 30s preview. If this assumption is wrong, M-02 reopens before any UI depends on it.
4. `ApplicationMusicPlayer.State` bridging: prove the `ObservableObject` → `AsyncStream<PlaybackSnapshot>` bridge, and settle the `playbackTime` polling rate.
5. Queue mutation: prove `ApplicationMusicPlayer.Queue` entries can be reordered/removed live, which the Queue screen depends on.
6. Confirm lock-screen / Dynamic Island media controls appear with no code ([M-05](DECISIONS.md#m-05)).
7. Write the `PreviewMusicService` fakes — Phases 2–4 depend on building UI without hardware.

**Gate:** a written spike report answering M-02 and the four-status question, plus audible playback on a physical device. If MusicKit cannot satisfy the brief's playback model, **stop** — there is no fallback provider, by design.

---

## Phase 2 — Domain, reducers, and the tested core
*No UI in this phase. All of it is unit-testable; none of it needs a device.*

1. `Domain/` — `HumTrack`, `HumCollection`, `AuthState`, `SubscriptionState`, `PlaybackState`, `QueueState`, `HumError`.
2. `Reducers/AuthReducer` — all four statuses, with the `.denied` / `.restricted` split ([ARCH §5a](ARCHITECTURE.md#5a-authreducer--all-four-musicauthorizationstatus-cases)).
3. `Reducers/SubscriptionReducer` — the four-row gate table ([ARCH §5b](ARCHITECTURE.md#5b-subscriptionreducer--the-subscription-gap)).
4. `Reducers/QueueReducer` — every invariant in [ARCH §5c](ARCHITECTURE.md#5c-queuereducer--queue-state-management).
5. Service protocols; adapters promoted from the Phase 1 spike.
6. Fakes for every protocol, in the test target.
7. **All three test suites written here, not at the end.** These are the brief's three named test criteria.

**Gate:** `swift test` green. All three acceptance-criteria suites pass. Zero UI in existence. Both containment greps still pass.

---

## Phase 3 — Authorization & subscription flow, end to end
*The first thing a user sees, and the criterion most builds fumble.*

1. `ConnectView` + `AuthViewModel` — built from the prototype's Connect screen, with the three permission bullets and the spinner state it draws.
2. The `denied` and `restricted` variants ([M-06](DECISIONS.md#m-06)) — same layout, different copy, and **no dead-end Settings button on `.restricted`**.
3. Subscription check on authorization success; `SubscriptionGapView`.
4. Wire `.musicSubscriptionOffer(isPresented:options:)` — Apple's trial-membership entry point. Confirm it presents, and that declining it returns to a working app rather than a dead screen.
5. `RootTabView` gated on `.authorized`.

**Gate:** on device, all four authorization paths reach a coherent screen. A non-subscribing account sees Apple's offer sheet, not a broken player. Revoking access in Settings and relaunching lands on the right state.

---

## Phase 4 — Design system, glass chrome, content screens
*The largest phase. Chrome first, content second — the boundary is easier to hold when the chrome already exists as a finished thing you are deliberately not extending.*

**4a — Foundations**
1. `Palette`, `Typography`, `Spacing`, `HumIcons` — values transcribed from [DESIGN_SYSTEM.md](DESIGN_SYSTEM.md) §§1–3.
2. `GlassSurface.swift` — the only `.glassEffect()` call site. Vends `chromeGlass()` and nothing else.
3. `Motion.swift` — `humRise` / `humBar` / press, with the Reduce Motion branch built in from the start.

**4b — Chrome (glass)**
4. `RootTabView` — `TabView` with `Tab(role: .search)`.
5. `PlayerBar` — glass capsule, amber tint, `.interactive()`.
6. Tab bar + player bar in a **single** `GlassEffectContainer`.
7. `glassEffectID` + `@Namespace` for the bar → Now Playing morph. Chrome morphs; content crossfades.

**4c — Content (opaque)**
8. `HomeView` — recently-played shelf + made-for-you list, **plus the empty states the prototype doesn't draw** ([M-12](DECISIONS.md#m-12)).
9. `DetailView` — album, then playlist, then artist (descending design confidence).
10. `NowPlayingView` portrait **and** `NowPlayingLandscapeView` — both drawn in the prototype.
11. `QueueView` including the drawn empty state.
12. `SearchView`, `LibraryView`, `SettingsView` — the inferred four, marked as such in the progress log.

**Gate:**
- Both containment greps pass.
- Visual pass on device against the boundary table in [ARCH §6](ARCHITECTURE.md#6-liquid-glass-boundary--normative).
- ≥44×44 verified with Accessibility Inspector.
- Every screen in the brief's list exists and is reachable.

---

## Phase 5 — Playback, queue, transport
*Deliberately after the UI. The reducers were proven in Phase 2; this wires effects to them.*

1. `ApplicationMusicPlayerAdapter` — the sole playback surface. `play` / `pause` / `skipToNextEntry` / `skipToPreviousEntry` / `playbackTime`, and nothing else.
2. Snapshot stream → `PlayerViewModel`; progress at ~4 Hz.
3. Queue mutation: `QueueReducer` decides, adapter mirrors onto `ApplicationMusicPlayer.shared.queue`.
4. Shuffle / repeat via the player's own modes.
5. Every play intent routed through the `SubscriptionReducer` gate — a `.gap` state can never reach `play()`.
6. Verify system lock-screen and Dynamic Island controls stay correct throughout.

**Gate:** on device with a subscriber account — play from Home, from a detail screen, and from the queue; skip forward and back; reorder and remove queue entries mid-playback without desync; seek. Then repeat the play attempts on a **non-subscriber** account and confirm every one lands on the offer sheet rather than an error.

---

## Phase 6 — Accessibility, compliance, acceptance sweep · *partly done*

0. ~~Design audit against real MusicKit data~~ — **superseded by Phase 7.** The pass that was done found and fixed four real defects (see PROGRESS.md), but it audited the screens against *data*, not against the designs. The gap that matters turned out to be a different one.
1. **Reduce Transparency on** — walk every screen; verify SwiftUI's solid fallback stays legible with amber-on-onyx. Fix contrast; do not hand-roll a parallel glass path.
2. **Reduce Motion on** — level meter flat, `humRise` → crossfade.
3. Dynamic Type through the accessibility sizes. The 200-weight display and the 10.5pt tab labels are the known failure cases.
4. VoiceOver pass — decorative meter hidden, progress bar has value + seek action, artwork labelled with the album not "image".
5. ✅ **Compliance sweep** — passed, evidence in PROGRESS.md.
6. ✅ **Zero-warning build** with warnings-as-errors on.
7. Walk the brief's Acceptance Criteria one by one, recording pass/fail **with evidence**.

**Gate:** every acceptance box checked with evidence, or explicitly listed as not-met with a reason.

---

## Phase 7 — Complete iPhone design audit · **NEXT**

*Added after the first device sessions. The implemented UI diverges from the designs substantially — not in ones and twos, but across screens. Everything before this built against a prototype read once, in Phase 4, and re-read only in fragments since.*

**Source of truth:** `designs/Hum-All-Platforms.html`, which bundles three documents:

| Source | Authority for |
|---|---|
| `01-iPhone-Screens-and-UI-System` | screens, tokens, the UI system |
| `02-iPhone-Interactive-Prototype` | **behaviour** — the authority when static and interactive disagree |
| `03-iPad-and-Watch-Screens` | companion platforms (Phases 8 and 9) |

1. **Read all three sources properly first**, and write down the token set before touching code. The bundle names at least one token the implementation does not have — `warning #D2714A`, distinct from the amber accent — which alone resolves the open finding about the destructive swipe action rendering in the affirmative colour.
2. **Screen-by-screen diff, design against build**, for all nine iPhone screens. Record every divergence before fixing any of it, so the list can be triaged rather than worked through in discovery order.
3. **Fix in priority order**, and re-verify each on device with real content — the fixtures hide too much, as the Phase 6 pass proved.
4. **Re-check the two glass boundary rules hold** after the changes; the containment script makes this cheap.

**Known divergences already recorded** (in PROGRESS.md, not yet triaged): the detail title duplicated between nav bar and header; the nav title lacking scroll-edge material over artwork; grid subtitles truncating; the destructive swipe action drawn in the accent colour; fixed hero art that clips below 390pt of width; and **the tab bar changing appearance when the now-playing capsule appears** — system-owned morphing between the accessory and the tab bar, which the design may or may not intend.

**Gate:** every screen matched to the design or its divergence recorded with a reason.

---

## Phase 8 — iPad

Per `03-iPad-and-Watch-Screens`. The target already builds for iPad (`TARGETED_DEVICE_FAMILY = "1,2"`) and all four orientations are declared, so what exists today is the iPhone layout stretched. Scope to be set from the design; expect the navigation shape and the detail/queue layouts to differ rather than scale.

**Gate:** to be written once the design has been read.

---

## Phase 9 — Apple Watch

Per `03-iPad-and-Watch-Screens`. A new target, a new extension, and a `WatchConnectivity` or independent-MusicKit decision that has not been made. The design notes a distinct ground colour for the watch (`#000`, not `#0A0A0A`), so the token set is not simply inherited.

**Note:** this is a new platform, not a refinement — it needs its own architecture pass before any code, and it is the first thing in this plan that adds a target.

**Gate:** to be written once the design has been read.

---

## Phase 10 — Handoff
1. `README.md` — setup, MusicKit capability, the device+subscription requirement, how to run tests.
2. Fold spike findings and any defaults-taken-under-silence back into [DECISIONS.md](DECISIONS.md) as resolved.
3. Known-gaps list — including the two open defects carried from Phase 5 (drag-to-reorder hangs during playback; the UI does not follow automatic track advance).

*Deliberately last: a handoff written before the platforms exist would need rewriting for each of them.*

---

## Risk register

| Risk | Likelihood | Impact | Handled by |
|---|---|---|---|
| **No device with an active Apple Music subscription** | Medium | **Critical** — nothing past Connect can be validated | M-09; raise now, not in Phase 3 |
| Brief's "30s previews for non-subscribers" isn't how iOS works | **Certain** | **High** — changes the service layer's shape | **M-02 resolved: not implemented.** Phase 1 confirms the behaviour empirically |
| ~~TCA requested but forbidden by the Stop Conditions~~ | — | — | **Closed** — M-01 resolved, no package added |
| `ApplicationMusicPlayer.State` is `ObservableObject`, not `@Observable` | **Certain** | Medium | Adapter bridges to `AsyncStream`; proven in Phase 1 |
| `playbackTime` has no change notification | **Certain** | Low | Timer in the adapter, ~4 Hz |
| Four screens have no design at all | **Certain** | Medium | M-06; built by inference and labelled as such |
| Prototype puts glass on content-layer buttons | **Certain** | Low | M-07; opaque gradient, keeps the grep rule honest |
| Prototype's heart has no MusicKit API | **Certain** | Low | M-04; retitle to Add to Library |
| Queue live-mutation misbehaves on the real player | Medium | High | Proven in Phase 1 spike, before the Queue screen exists |
| MusicKit capability / bundle ID not provisioned | **Certain (deferred)** | **High** | M-10; blocks Phases 1, 3, 5, 6 — i.e. most acceptance criteria. Becomes critical path once Phase 0 closes |
| iOS 26 glass APIs shift in a point release | Low | Medium | All glass funnels through one file |
| **Implemented UI diverges from the designs across screens** | **Certain — observed** | **High** — the app does not look like the thing that was designed | Phase 7, a full audit against all three design sources rather than fragments |
| **Drag-to-reorder hangs during playback** | **Certain — observed** | High | Open defect, six failed attempts, recorded in PROGRESS.md with the untried approaches |
| **UI does not follow automatic track advance** | **Certain — observed** | **Major** — the player shows the wrong song on every screen whenever playback runs unattended | Open. One fix attempted (stale queue observer) and **disproved on device**; two candidates left and a one-line experiment to split them, in PROGRESS.md |
| Apple Watch adds a target, an extension and a connectivity decision | **Certain** | Medium | Phase 9 gets its own architecture pass before any code |

---

## What this plan deliberately excludes

Per *"only make changes directly requested"*: no ad system, no StoreKit or paywall of any kind, no non-MusicKit content source (all three explicitly forbidden); and no analytics, crash reporting, onboarding carousel, offline caching, CarPlay, widgets, custom Live Activity ([M-05](DECISIONS.md#m-05)), account system, server component, CI pipeline, or localization beyond system defaults. Each is a reasonable thing to want; none was asked for.
