# Hum v1 (MusicKit) — Decisions

**Status:** proposed, nothing implemented.
**Supersedes** the Feed.fm-era decision set in [`docs/DECISIONS.md`](../DECISIONS.md), which is obsolete for this brief.

Each entry is **BLOCKING** (work cannot start without your answer), **DEFAULTED** (I proceed as stated unless you say otherwise), or **RESOLVED**.

---

## M-01 — TCA is a dependency, and dependencies are a Stop Condition ✅ RESOLVED

> **Decision: Option A.** TCA was a recommendation, not a requirement — so the Stop Condition is not fired and no package is added. The build uses **MVVM + a pure reducer core**: `@MainActor @Observable` ViewModels over `(State, Action) -> State` reducers with side effects lifted into services.
>
> This keeps the dependency count at **zero** and still gives the exhaustive-transition testing that makes the three named test criteria cheap. `AuthReducer`, `SubscriptionReducer` and `QueueReducer` are the TCA-shaped part; nothing else borrows from it.
>
> **Reversal cost if you later want real TCA:** low. The reducers are already `(State, Action) -> State`; adopting `@Reducer`/`Store` is a mechanical lift of the same functions, and the ViewModels are the only layer that changes.


The brief asks for "several design patterns like MVVM, TCA etc." Two lines later the Constraints say **"Follow MVVM"**, and the Stop Conditions say **stop before "adding any dependency beyond Apple's native MusicKit framework."**

The Composable Architecture is `pointfreeco/swift-composable-architecture` — a third-party SPM package. Adopting it *is* the Stop Condition firing. These two instructions cannot both be honoured.

| Option | What it means | Cost |
|---|---|---|
| **A. MVVM + TCA-shaped core** *(default — I proceed with this)* | `@MainActor @Observable` ViewModels, plus a pure `PlaybackReducer`-style state machine: `(State, Action) -> State` with side effects lifted out. Unidirectional data flow, exhaustively testable state transitions, no package. | Zero new deps. Gets ~80% of what TCA is wanted for. Not TCA. |
| **B. Real TCA** | Add `swift-composable-architecture`. `@Reducer`, `Store`, `TestStore`. | **Fires the Stop Condition.** Needs your explicit written approval. Adds a large dependency, its own Swift 6 migration surface, and a learning tax for anyone maintaining this. |
| **C. MVVM only** | Plain ViewModels, no reducer layer. | Simplest. Loses the exhaustive-transition testing that makes the queue/auth/subscription acceptance criteria cheap to satisfy. |

**Default: A.** It satisfies "MVVM" literally, gives you the reducer discipline "TCA" is shorthand for, and keeps the dependency count at zero. Say the word and I'll switch to B — but I need that in writing, because it is a named Stop Condition.

---

## M-02 — `ApplicationMusicPlayer` does not fall back to 30-second previews ✅ RESOLVED

> **Decision: Option A — no preview engine.** A non-subscriber who tries to play is routed to Apple's own `MusicSubscriptionOffer` sheet at the point of need. Library and on-device content still plays. No second `AVPlayer` path, no second transport state.
>
> **Accepted consequence, stated plainly:** the brief's line *"catalog tracks play 30-second previews only"* is **not implemented**, because iOS MusicKit does not support it without a parallel playback engine. What ships instead satisfies the criterion the line exists to serve — *"surface this clearly rather than silently failing."* Phase 1 confirms the underlying behaviour empirically before any UI depends on it.


The brief's compliance rule reads: *"if the user has no active Apple Music subscription, catalog tracks play 30-second previews only; surface this clearly rather than silently failing."*

That describes MusicKit-JS behaviour, not the iOS framework. On iOS:

- `ApplicationMusicPlayer.shared` plays **full catalog tracks only, and only for an active subscriber.** With no subscription, `play()` throws — it does not silently degrade to a preview.
- 30-second previews exist as `Song.previewAssets` → `[PreviewAsset]` with a `url`. Playing one means a **separate `AVPlayer` path** alongside `ApplicationMusicPlayer`, with its own audio session handling, its own transport state, and its own now-playing info.

So "previews for non-subscribers" is a second playback engine, not a flag.

| Option | What it means |
|---|---|
| **A. No preview engine** *(default)* | Non-subscribers get the `MusicSubscriptionOffer` sheet (Apple's own trial entry point) at the moment they try to play. The library tab still works for on-device/purchased content. This is the smaller, more compliant build, and it satisfies "surface this clearly rather than silently failing." |
| **B. Add the AVPlayer preview path** | A second `PreviewPlaybackService` behind the same protocol. Real scope: audio session arbitration between two players, a distinct transport state, and a "you're hearing a preview" affordance on every surface. Roughly a full extra phase. |

**Default: A**, because it is what the framework actually supports and because B doubles the playback surface for a degraded experience. If B is a hard requirement, say so now — it changes the service layer's shape, and retrofitting it after Phase 4 is expensive.

---

## M-03 — The `docs/` planning set describes a different app ✅ RESOLVED (by this document)

`docs/ARCHITECTURE.md`, `docs/DEVELOPMENT_PLAN.md`, `docs/DECISIONS.md` and `docs/DESIGN_SYSTEM.md` plan a **Feed.fm** app with an **ad-break state machine** and a **StoreKit 2 subscription paywall**. This brief forbids all three explicitly:

> *No ad system, no subscription/paywall, no third-party streaming provider — MusicKit is the only content source.*

**Decision:** treat the `docs/*.md` set as superseded. This `docs/v1-musickit/` set is the plan of record. Nothing has been deleted — deleting files is a Stop Condition. **Tell me if you want the Feed.fm set removed or moved to `docs/archive/`.**

The Feed.fm docs still contain two things worth keeping, which I have carried forward: the Liquid Glass boundary table (§6) and the `glassEffect`-lives-in-one-file containment rule.

---

## M-04 — The prototype's "love" heart has no MusicKit API behind it ✅ RESOLVED

> **Decision: Option A — "Add to Library."** Backed by `MusicLibrary.shared.add(_:)`. The heart glyph is replaced with `plus` / `checkmark` (filled state = already in library), and the accessibility label says "Add to Library", not "Love".
>
> Recorded as a **deliberate, visible deviation** from `designs/Hum Prototype.html`, not an oversight.


`designs/Hum Prototype.html` puts a heart toggle on Now Playing. MusicKit on iOS exposes **no public API to set a love/favorite rating** on a catalog song. `MusicLibrary.shared.add(_:)` (add to library) is the nearest real capability, and it means something different.

| Option | What it means |
|---|---|
| **A. Retitle it "Add to Library"** *(default)* | Real API (`MusicLibrary.shared.add(song)`), honest affordance, filled state = in library. Swap the heart glyph for `plus`/`checkmark`. |
| **B. Keep the heart as local-only state** | Persisted on-device, means nothing to Apple Music, does not sync. A heart that doesn't travel with the user's account will read as broken. |
| **C. Drop it** | Cleanest. Design loses an element. |

**Default: A.** Flagging because it is a visible deviation from the supplied design.

---

## M-05 — Dynamic Island / Live Activity is in the design, not in the brief ⚠️ DEFAULTED — out of scope

The prototype includes compact Dynamic Island, expanded Dynamic Island, and lock-screen Live Activity mockups. The brief's screen list does not include them, and the Constraints say *"only make changes directly requested — no features, abstractions, or files beyond what's asked."*

A Live Activity is also **a second target** (Widget Extension + ActivityKit), which is a materially larger change than a screen.

**Default: not built.** Note that `ApplicationMusicPlayer` already gives you the system Now Playing lock-screen controls and Dynamic Island media presentation *for free* — the standard media chrome appears without any code. The prototype's mockups are close to what you get by default. Say so if you want the custom ActivityKit build; it's roughly its own phase.

---

## M-06 — Design/brief screen gaps ⚠️ DEFAULTED

The brief names nine screens. The prototype draws five. The delta:

| Screen | In brief | In prototype | Plan |
|---|---|---|---|
| Connect Apple Music | ✅ | ✅ | Build from prototype. **Prototype only draws the `notDetermined` state** — I will derive `denied`, `restricted`, and the subscription-gap variants from the same layout (same icon, headline, body, single action). |
| Home | ✅ | ✅ | Build from prototype ("Recently played" shelf + "Made for you" list). |
| Search | ✅ | tab exists, **no screen drawn** | Build to the prototype's Home/track-row idiom: `.searchable` + `Tab(role: .search)`, results as the same rows. Flagging that the visual is inferred, not given. |
| Album Detail | ✅ | ✅ | Build from prototype. |
| Playlist Detail | ✅ | ❌ | Same layout as Album, different header meta. Prototype's shelf already shows a "Playlist · 24 tracks" card, so the idiom is implied. |
| Artist Detail | ✅ | ❌ | **No design.** Inferred: header + top songs + albums grid. Lowest-confidence screen in the build. |
| Now Playing | ✅ | ✅ portrait **and landscape** | Build both. Landscape is a bonus the brief didn't ask for but the design supplies. |
| Queue | ✅ | ✅ incl. empty state | Build from prototype. |
| Settings | ✅ | ❌ | **No design.** Inferred: grouped list — authorization status, subscription status, Reduce Transparency note, version, link to system Settings for revoking access. |

**Default:** build all nine, marking the four inferred ones (`Search`, `Playlist`, `Artist`, `Settings`) in the progress log as *designed-by-inference* rather than passing them off as design-matched.

---

## M-07 — Prototype puts glass on content-layer buttons ⚠️ DEFAULTED

The brief's boundary is explicit: *"Glass applies only to: Player Bar, Tab Bar, toolbars, Toasts, sheets. Content views render opaque — never glass."*

The prototype uses `backdrop-filter: blur(24px) saturate(180%)` on three **content-layer** controls:
1. The Connect screen's "Connect Apple Music" button
2. Album Detail's "Play" button
3. Now Playing's 76pt play/pause button

**Default resolution:** these render as **opaque amber-gradient capsules** — same gradient, same border, same inner highlight, no `.glassEffect()`. On a dark opaque background at these sizes the visual difference is nearly nil, and it keeps the brief's acceptance criterion mechanically checkable (`grep glassEffect` outside `GlassSurface.swift` returns nothing). Flag if you want the exception carved out instead.

---

## M-08 — Scrubbing vs "standard, unmodified transport" ⚠️ DEFAULTED

The prototype's progress bar is tappable-to-seek. The brief says playback must use *"standard, unmodified media controls (play/pause/skip) that the user initiates."*

Seeking via `ApplicationMusicPlayer.shared.playbackTime` **is** a standard, first-party MusicKit control, and it is user-initiated. It does not alter playback behaviour, skip content, or bypass licensing. **Default: implement it.** Called out because "play/pause/skip" is an exhaustive-sounding list and I am adding a fourth verb deliberately, not by accident.

---

## M-09 — MusicKit does not work in the Simulator ⚠️ DEFAULTED — affects acceptance

The Simulator has no Apple Music account and no playback stack. In the Simulator:
- `MusicAuthorization.request()` returns, but there is no real account behind it
- `MusicSubscription.current` is unreliable
- `ApplicationMusicPlayer.play()` does not produce audio

The acceptance criterion *"builds and runs on simulator with iOS 26 SDK"* is satisfiable — the app launches, chrome renders, glass renders. **Everything downstream of authorization must be verified on a physical device with an active Apple Music subscription.**

Two consequences you should agree to now:
1. **A device with an Apple Music subscription is required** for Phases 2–6. If one isn't available, the build cannot be validated past the Connect screen.
2. Simulator development needs a **`PreviewMusicService` fake** behind the service protocol so the UI phases aren't blocked on hardware. This is why the protocol boundary exists at all in a MusicKit-only app.

---

## M-10 — MusicKit capability & bundle identifier ✅ RESOLVED

> **Supplied:** bundle identifier **`org.surajshetty.humapp`**, with the MusicKit app service enabled on the App ID. Wired into the project; the app builds, installs, and launches under it.
>
> **Team ID: `CYY72W5P5F`**, set in `Config/Signing.xcconfig` (an xcconfig rather than `project.yml`, so `xcodegen generate` cannot overwrite it).
>
> **Verified end to end:** the app builds for `generic/platform=iOS`, signs with *Apple Development: Suraj Shetty (2Y4Q7YN79V)* under team `CYY72W5P5F`, and installs and runs on a physical iPhone (iOS 26.5).
>
> **Correction made along the way — MusicKit has no entitlement.** `Hum.entitlements` had declared `com.apple.developer.musickit`, which is not a real entitlement key; provisioning rejected it with *"Entitlement com.apple.developer.musickit not found and could not be included in profile."* MusicKit on iOS is enabled as an **App Service on the App ID** in the developer portal, and the app itself needs only `NSAppleMusicUsageDescription` plus runtime `MusicAuthorization`. `CODE_SIGN_ENTITLEMENTS` has been removed from the build; the now-unused file is kept as an empty placeholder rather than deleted.


Before the app can authorize on device you need, in the Apple Developer portal:
- The **MusicKit** app service enabled for the App ID
- A bundle identifier — I will scaffold `com.hum.app` as a placeholder
- `NSAppleMusicUsageDescription` in Info.plist (I'll write the string; you may want to reword it — it is user-facing)

> **What remains:** device *builds and runs* are unblocked. Validating MusicKit itself still needs the second half of [M-09](#m-09) — **an active Apple Music subscription on the signed-in account** — since that is what Phases 1, 3 and 5 actually exercise.

---

## M-11 — Library persistence ⚠️ DEFAULTED — nothing persisted

The brief scopes data models to *"local auth/playback/library state."* MusicKit already persists the user's library on Apple's side, and re-fetching is cheap.

**Default: no local store. No SwiftData, no UserDefaults beyond trivial UI preference.** Everything is fetched from MusicKit on demand and held in memory. This also keeps us clear of the compliance rule against caching MusicKit content.

---

## M-12 — Recently-played source ⚠️ DEFAULTED

The prototype's Home shelf says "Recently played." MusicKit provides `MusicRecentlyPlayedContainerRequest` for this. **Default: use it.** "Made for you" below it maps to `MusicPersonalRecommendationsRequest`. Both are first-party and require an authorized user; both are empty for a brand-new account, so **both need designed empty states that the prototype does not supply** — I'll derive them from the Queue screen's empty state, which is drawn.

---

## Summary

| | |
|---|---|
| ✅ **Resolved** | **M-01** (MVVM + reducer core, no TCA package) · **M-02** (no preview engine; offer sheet instead) · M-03 (Feed.fm docs superseded) · **M-04** (Add to Library, not love) |
| ⚠️ **Defaulted, proceeding** | M-05, M-06, M-07, M-08, M-09, M-11, M-12 |
| ✅ **Resolved** | **M-10** — bundle ID `org.surajshetty.humapp`, team `CYY72W5P5F`; builds, installs and runs on device |
| 🚫 **Still open** | none |

**Nothing blocks Phase 0, Phase 2, or Phase 4** — those build against fakes.
**Device builds are unblocked.** The one thing still outstanding is from [M-09](#m-09): an **active Apple Music subscription** on the account signed into the test device. Phases 1, 3 and 5 exercise exactly that, so without it the build still cannot be validated past the Connect screen.
