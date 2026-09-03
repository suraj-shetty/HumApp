# Hum — Design QA Audit

**Date:** 2026-09-03 · **Branch:** `feat/ui-revamp` · **Commit:** `4f8b4c1`
**Device:** iPhone 17 Pro, iOS 26.5 Simulator (402 × 874 pt, @3x)
**Design source:** `designs/Hum-All-Platforms.html` — the Claude-Design prototype, identical in content to the [Figma file](https://www.figma.com/design/8DgzM3iIfq0AprGO00bChi/Humapp). **42 iPhone screens**, plus the shared components `Dock`, `TrackRow`, `ArtPill`, `StatusBar`.
**Code-side token source:** `Hum/DesignSystem/` (`Palette`, `Metrics`, `HumTextStyle`, `GlassSurface`, `Motion`)

> **Note on method.** The Figma file's remote MCP hit the Starter-plan call limit partway through this audit. Since Figma and the local prototype are the same design, all values below are read directly from the local HTML's inline styles — which is a *better* source: it carries exact CSS (blur radii, gradients, shadows) that Figma's export flattens away. Nothing in this report is estimated from a screenshot.

> ### Status update — 2026-09-03, after the audit
>
> **17 findings, across 10 changes, are fixed since this report was written.**
>
> - **C-1, C-2** (chrome glass) — all three surfaces now call `chromeGlass` before `amberGlass`, and both bars share one `ChromeGlassContainer`. `shots/11-AFTER-chrome-glass-fix.png`
> - **M-5** (text ramp) — `textTertiary`/`textQuaternary` removed, replaced by `textMuted` at the design's 62%.
> - **C-3** (Now Playing crash) — cause was **not** the `MPVolumeView` this report guessed at. `VolumeRow` rendered itself, overflowing the stack; it is not Simulator-specific. See §2.
> - **M-1** (Detail hero) and **M-7** (Now Playing glow). `shots/13-`, `shots/14-`
> - **NP-1** (play glyph contrast) — now `#0A0A0A` on `#E8A33D`, measured off the rendered pixels at **9.18:1**, up from 2.16:1. `shots/17-AFTER-play-glyph-contrast.png`
> - **Q-1** (Queue card) — the now-playing block now carries the design's `#141416` card fill (new `Palette.surfaceCard` token), 14pt radius and inset margins, instead of a bare full-width row.
> - **Q-2** (Clear tint) — "Clear" is amber when enabled and a new `Palette.textDisabled` (white 25%) when the queue is empty, instead of the same grey in both states. `shots/18-AFTER-queue-card-fix.png`
> - **NP-2, NP-6, NP-7, NP-8** (control placement) — all four settled as one change. Header trailing is now an overflow menu (Add to Library moved there from the title row, which is centred with nothing else in it); the bottom row now holds queue, shuffle, repeat and AirPlay, matching the design's row count. Repeat and AirPlay stay — they are real, tested controls the design simply doesn't draw here, and removing them was never asked for. Lyrics stays out — screen 34 is unbuilt, and a dead button is worse than no button. `shots/19-AFTER-nowplaying-control-placement.png`
>
> - **CT-1, CT-2** (Connect denied/restricted layout, floating-CTA glass) — the denied and restricted screens now render screen 06's own layout (terracotta icon halo, centred heading, and — denied only — a "Where to look" info card) instead of reusing the invitation's; `.deniedRecoverable` also gains the "Try again" secondary action the design draws, wired to a real re-check rather than left decorative. `AmberCapsuleButton` (Connect's CTA, the subscription gap's retry) now carries real glass via a new, narrowly-scoped `floatingActionGlass`, resolving `DECISIONS M-07` the way it was left open to be resolved — see §9 and `DECISIONS.md`. `shots/27-`, `28-AFTER-connect-*-CT1.png`
>
> - **Q-12** (Queue empty-state button) — `EmptyStateView`'s action button now uses a new `AmberOutlineButton` (border only, no fill, amber label — screen 27's actual recipe) instead of the misleadingly-named `OutlineCapsuleButton`, which filled and labelled in white. `OutlineCapsuleButton` itself is untouched — it still serves `SubscriptionGapView`'s "Continue Without It", where **SG-4 remains open**: the two screens that used to share this one component wanted two different treatments, which is why a second component exists now rather than one shared fix. Built to screen 27's own height (48) too, closing that half of Q-14 as a side effect of building the button correctly; Q-14's headline-size delta is untouched. `shots/30-AFTER-queue-empty-Q12.png`
> - **Q-13** (empty-state icon ring) — every screen `EmptyStateView` backs (Home, Search, Library, Queue, Now Playing's "Nothing playing") now draws the design's 96×96 amber-35% ring around a full-strength icon, instead of no ring and an icon dimmed to 70%. Measured off screen 27 (Queue) and confirmed identical on screens 14 (Search) and 17 (Library); Home's own screen (10) rings at 112×112, 16pt larger — close enough not to fork the shared component over, named here rather than silently rounded away. Regression-checked on Search's empty state, which shares the component but passes no action button. `shots/31-AFTER-queue-empty-Q13.png`
>
> With NP-1 fixed, **no known contrast failure remains** in the audited screens. With the control-placement round, **no known layout finding remains open on Now Playing or Queue** except the icon halo (Q-13) and headline size (part of Q-14), both still open. With CT-1/CT-2, **no known Major finding remains open in the Connect/subscription-gap family** — SG-2, SG-3 and SG-4 are still open, since that pass only touched `ConnectView`.
>
> **Also fixed, tooling rather than a finding:** the manual `AppEnvironment.live()` ⟷ `.preview()` edit every screenshot in this report required is retired. `HumApp.swift` now reads a `#if DEBUG`-gated launch argument instead — see B-1.
>
> Fixing C-3 made Now Playing and Queue reachable, and **§8 is their audit** — 22 further findings. Everything else below still stands.

---

## 1. Summary

| Metric | Count |
|---|---|
| Screens in app nav graph | 11 |
| Fully audited (screenshot + code + design) | 11 |
| Audited from code + design only (timing- or OS-blocked, not source-blocked) | 1 |
| Screens in the design | 42 |
| **Total issues** | **60** |

| Severity | Count | IDs |
|---|---|---|
| **Critical** | 3 | C-1 … C-3 |
| **Major** | 18 | M-1 … M-9 · NP-1, NP-2 · Q-1, Q-2, Q-12 · CT-1, CT-2 · SG-2, SG-4 |
| **Minor** | 39 | m-1 … m-16 · NP-3 … NP-11 · Q-3 … Q-11, Q-13, Q-14 · CT-3, CT-4 · SG-3 |

§5 covers the first pass; **§8 covers Now Playing and Queue**, audited later once C-3 was fixed.

### The headline

**The entire chrome layer is missing its material.** The design's glass recipe is explicit —
`backdrop-filter: blur(26px) saturate(180%)` under an amber gradient. The app applies the gradient and never the blur, so list content reads through the tab bar and mini-player at full contrast (C-1, C-2). Compounding it, the amber tint was deliberately *halved* to compensate for a system material that is not actually there.

Second: **opening Now Playing crashes the app** (C-3), which also blocked capture of Now Playing and Queue.

Third: **the text ramp is systematically off.** The design's workhorse secondary is white **62%** (133 uses); the palette has no such token, and its `textTertiary` (52%) and `textQuaternary` (40%) appear in the design **zero and one** times respectively. The 40% token is what fails WCAG AA on every duration in the app (M-5).

---

## 2. Corrections to the first pass

Two findings from my initial report were wrong, and the design file settles both against me:

- **M-1 (Detail Play button) — RETRACTED.** I flagged the flat amber Play pill as ignoring the `Palette.amberButton` gradient. The design specifies the Play pill as **flat `#E8A33D`, 48 pt tall, radius 24, label `#0A0A0A` 16px/500** — exactly what `DetailView.swift:197` does. `amberButton`'s 26%→12% gradient belongs to the **322 × 56 full-width CTA** on Connect, where `HumButtons.swift:37` uses it correctly. The only defect is `Palette.swift:87`'s comment claiming the token is for "album Play" (now m-11).
- **m-4 (search island selected state) — RETRACTED.** I flagged the island for having no selected fill while the tab pills do. `Dock.dc.html` shows this is by design: the island only swaps its icon stroke (`searchInk`) from `#fff` to `#E8A33D`. The app matches.

---

## 3. Blockers and caveats

### B-1 · Screenshots required a temporary source change, since reverted — now resolved

`HumApp.swift` wired `AppEnvironment.live()`, and MusicKit returns nothing in the Simulator (`DECISIONS M-09`), so every screen rendered empty. Every screenshot through this audit's addendum (§8 and the fix-verification shots) required switching that line to `AppEnvironment.preview()`, rebuilding, capturing, then reverting.

**The tree stayed clean through all of it.** `Hum/HumApp.swift` was checked back to its baseline sha after every capture, verified by `git status` showing only the untracked `design-audit/`.

**Resolved:** item 8 of §7 is done. `HumApp.swift` now resolves `.preview()` vs `.live()` from a `#if DEBUG`-gated launch argument — `xcrun simctl launch <device> <bundle-id> -HumUsePreviewServices YES` — so no future audit needs to touch this file at all. Verified both directions: the flag present renders the populated fixtures (`shots/20-AFTER-launch-argument-hook.png`); the flag absent falls back to `.live()` exactly as before. Debug and Release both build clean, so the flag cannot reach a Release binary.

### B-2 · States that could not be reached

| State | Why |
|---|---|
| ~~Now Playing · Queue~~ | Was blocked by the C-3 crash (`05-`/`07-CRASH-after-tapping-playerbar.png`). **Now resolved and audited — see §8.** |
| ~~Connect — 4 states~~ · ~~Subscription gap~~ | Was blocked by preview services granting authorization immediately with no way to force a state. **Now resolved and audited — see §9**, using the `-HumPreviewAuthState` / `-HumPreviewSubscriptionState` launch arguments added for this. One sub-state (`.connecting`, the mid-request spinner) resolves in 1.2s, faster than the capture tool's round-trip — verified from code instead of a screenshot; not a design gap. |
| Toast | Still unreached — needs a gated play intent to fail differently from the two `SubscriptionGapView` paths already captured. |
| Reduce Transparency ON | `simctl` toggle did not take (`10-…-DID-NOT-APPLY.png`); the app's own Settings screen still read `Off`. **Fallback path untested** — reported as neither passing nor failing. |
| Dynamic Type AX3 · smallest/largest device | Not exercised. The design specifies a full AX3 reflow (screen 38) — worth a dedicated pass. |

### B-3 · Device-size mismatch

The design is drawn at **390 × 844** (iPhone 13/14 class). The app runs at **402 × 874**. Absolute values (gutters, radii, type, component heights) transfer directly and are compared as-is. Width-derived constants do not — see m-9.

---

## 4. Screen inventory

The design has **42 screens**; the app implements 11. Every app screen has a design counterpart — my first pass wrongly reported Library, Detail, Now Playing, Queue and Settings as undesigned, which was an artifact of sampling only 13 Figma frames.

| App screen | Source | Captured | Design screen |
|---|---|---|---|
| Home — populated | `Home/HomeView.swift` | ✅ `01-home.png` | 08 |
| Home — empty | `Home/HomeView.swift` | ✅ | 10 |
| Library | `Library/LibraryView.swift` | ✅ `02-library.png` | 16, 17 |
| Playlist / Album detail | `Detail/DetailView.swift` | ✅ `03-detail.png` | 19, 21 |
| Search — empty | `Search/SearchView.swift` | ✅ `08-search.png` | 12 |
| Settings | `Settings/SettingsView.swift` | ✅ `09-settings.png` | 39–41 (as sub-screens) |
| Bottom chrome | `Root/HumTabBar.swift`, `Components/PlayerBar.swift` | ✅ `06-home-playerbar.png` | `Dock.dc.html` |
| Now Playing | `NowPlaying/NowPlayingView.swift` | ✅ `15-nowplaying.png` | 23 |
| Queue — populated | `Queue/QueueView.swift` | ✅ `16-queue.png` | 26 |
| Queue — empty | `Queue/QueueView.swift` | ✅ `29-queue-empty.png` | 27 — see §10 |
| Connect — invitation | `Connect/ConnectView.swift` | ✅ `21-connect-invitation.png` | 04 |
| Connect — connecting | `Connect/ConnectView.swift` | ⚠️ verified from code, not captured | 04 (spinner variant) |
| Connect — denied | `Connect/ConnectView.swift` | ✅ `23-connect-denied.png` | 06 (closest analog — see §9) |
| Connect — restricted | `Connect/ConnectView.swift` | ✅ `24-connect-restricted.png` | 06 (closest analog — see §9) |
| Subscription gap — no offer | `Connect/SubscriptionGapView.swift` | ✅ `25-subscription-gap.png` | no direct screen — see §9 |
| Subscription gap — check failed | `Connect/SubscriptionGapView.swift` | ✅ `26-subscription-unavailable.png` | no direct screen — see §9 |

### Designed, no counterpart in the nav graph → **M-8**

01 Splash · 02–03 Onboarding (×2) · 09 Home-loading · 11 Home-offline · 15 Search-error · 18 Library-sync-error · 20 Playlist-loading · 22 Artist detail · 24 Now Playing-buffering · 25 Track unavailable · 29 Full-screen error · 31 Track context menu · 32 Add to playlist · 33 Search-focused/recents · 34 Now Playing-lyrics · 35 AirPlay picker · 36 Playlist-empty · 37 Detail-failed · 39–41 Settings sub-screens · 42 New playlist

Screens **30** (chrome reference), **38** (Dynamic Type reference) and **43** (system share sheet) are reference boards, not screens to build.

---

## 5. Findings

### 🔴 Critical

**C-1 · Tab bar and search island render with no glass material**

| | |
|---|---|
| **Screen** | Bottom chrome (all tabs) · **Category** Liquid Glass / materials |
| **Expected** | `backdrop-filter: blur(26px) saturate(180%)` under `linear-gradient(180deg, rgba(232,163,61,.17), rgba(232,163,61,.07))`, border `1px rgba(255,255,255,.16)`, shadow `0 10px 34px rgba(0,0,0,.5)` + `inset 0 1px 0 rgba(255,255,255,.2)` — `Dock.dc.html` |
| **Actual** | Tint only. `.amberGlass(…)` paints the gradient at **8.5% → 3.5%** and a hairline. No `.glassEffect()` is ever applied. |
| **Delta** | Blur **26px → 0**; saturate **180% → none**; tint alpha **halved** |
| **Location** | `Hum/Features/Root/HumTabBar.swift:51` (capsule), `:112` (search island) |

`GlassSurface.swift:82-86` states `amberGlass` "Lays the design's Amber Glass tint **over a surface the system has already given a material**." No material is ever supplied, so the tint composites onto raw content.

**Evidence:** `06-home-playerbar.png` — rows "Low Ceiling / Ana Roele / 5:04" and "Quiet Room, Late / … / 3:29", their thumbnails and hairlines, all read at full contrast through the tab capsule and collide with the "Home" label.

**The halving compounds it.** `Palette.swift:100-108` halved the tint from the design's 17%→7% to 8.5%→3.5%, reasoning that the system's Liquid Glass "already tints and darkens what it covers, so laying the measured value on top double-counts." That reasoning is sound *only if a material is present*. It is not — so the chrome is both unblurred **and** at half the intended tint. Restoring `.glassEffect()` and re-checking the tint must happen together.

**Counter-example in-repo:** `ToastView` (`PlayerBar.swift:91-92`) calls `.chromeGlassCapsule(tint: nil)` before `.amberGlass(…)`. The correct two-call pattern exists and is used exactly once.

---

**C-2 · Mini-player renders with no glass material**

| | |
|---|---|
| **Screen** | Player bar · **Category** Liquid Glass / materials |
| **Expected** | Same glass recipe as C-1 (`Dock.dc.html`, mini-player) |
| **Actual** | Tint only |
| **Delta** | Blur **26px → 0**; tint alpha halved |
| **Location** | `Hum/Features/Components/PlayerBar.swift:71` |

This rests on a **stale premise**. `PlayerBar.swift:5-10` and `GlassSurface.swift:26-29` both state the material comes from `TabView`'s `tabViewBottomAccessory`. `RootTabView.swift:13-16` records the opposite:

> "The player bar no longer uses `tabViewBottomAccessory`. That slot draws its own capsule at its own width…"

When the bar moved into a hand-built `safeAreaInset`, the material went with it and the comments were never updated.

**Evidence:** `04-detail-playing-playerbar.png` — the mini-player's "Slow Water / Ana Roele" and the list row beneath it are both fully legible, overlapping.

---

**C-3 · App terminates when opening Now Playing**

| | |
|---|---|
| **Screen** | Now Playing · **Category** Stability |
| **Actual** | Process terminates; Simulator returns to home screen. **Reproduced 3/3.** |
| **Location** | Suspected `NowPlaying/SystemAudioControls.swift:13-32` (`MPVolumeView`) / `:38-48` (`AVRoutePickerView`), reached via `NowPlayingView.swift:100` → `VolumeRow()` |

```
launchd_sim … UIKitApplication:org.surajshetty.humapp … service has crashed 1 times in a row
```

**Caveat — not a confirmed production defect.** Both suspects are UIKit audio-route views with no route to control in a Simulator; `SystemAudioControls.swift:11` already notes "It renders empty in the Simulator." No `.ips` and no Swift runtime message were captured, so the frame is inferred from the view tree. **Needs a device check before any code change.**

Relatedly: the design does **not** use a system volume control. Screen 23 draws a custom track — `height 4px, radius 2, background rgba(255,255,255,.14)`, fill `rgba(232,163,61,.85)`. The code's choice of `MPVolumeView` is a defensible engineering trade (it is the only way to set system volume), but it is a divergence, and it is the suspected crash site.

---

### 🟠 Major

**M-1 · Detail hero artwork is full-bleed and square-cornered**

| | |
|---|---|
| **Expected** | **206 × 206**, `border-radius: 14px`, inset and centred (24px page padding → 92px side margins), `box-shadow: 0 18px 44px rgba(0,0,0,.6)` — design 19 & 21 |
| **Actual** | Edge-to-edge at full screen width (402 pt), `cornerRadius: 0`, no shadow |
| **Delta** | **+196 pt width · −14 pt radius · shadow absent** |
| **Location** | `Detail/DetailView.swift:23` |

The design is unambiguous: "hero artwork is 206×206 r14, inset — never full-bleed; only Artist detail is full-bleed." `Metrics.artDetailHero = 342` is *also* wrong (design: 206) and is unreferenced anyway (m-3).

---

**M-2 · Search field renders above the screen title**

| | |
|---|---|
| **Expected** | Design 12's top block is a column, `gap: 18px`: **[title + avatar row] → [search field] → [Browse]** |
| **Actual** | System field on top, "Search" title beneath |
| **Location** | `Search/SearchView.swift:117-126` (title hand-drawn in content, `.navigationTitle("")`) + `:129` (`.searchable`) |

Related divergence: the design's field is a **custom glass control** — `height 46, radius 23, padding 0 16, gap 10`, idle fill `linear-gradient(180deg, rgba(255,255,255,.13), rgba(255,255,255,.05))` + `blur(24px) saturate(180%)`, focused fill amber `.18→.07` with border `rgba(232,163,61,.5)` and focus ring `0 0 0 3px rgba(232,163,61,.16)`. The app uses the system `.searchable` bar, which is why neither the geometry nor the amber focus state appears.

---

**M-3 · Search "Browse" genre grid missing**

| | |
|---|---|
| **Expected** | Design 12: `grid-template-columns: 1fr 1fr`, `gap: 12px`, tiles `height 96, radius 12, padding 14`, label `16px/300 #fff`, bottom-aligned. Six tiles — Ambient `#26211C`, Jazz `#1C2124`, Classical `#242028`, Folk `#1E1E20`, Electronic `#211C26`, Soul `#1C2420` |
| **Actual** | A centred magnifier icon, headline and one line of copy |
| **Location** | `Search/SearchView.swift:71-72` |

---

**M-4 · Search results filter chips missing**

| | |
|---|---|
| **Expected** | Design 13: chip row `gap 8`, chips `height 38, radius 19, padding 0 16, font 13.5`; selected `rgba(232,163,61,.16)` + `1px rgba(232,163,61,.45)` + `#E8A33D`; unselected `#161618` + `rgba(255,255,255,.6)`. Plus `TOP RESULTS` / `ALBUMS` section headers. |
| **Actual** | No chips, no section headers |
| **Location** | `Search/SearchView.swift` |

`Metrics.chipHeight/chipRadius/chipSpacing` and `Palette.chipSelectedFill/chipSelectedStroke/chipFill` already match these values exactly and are used by Library — the components exist and simply were not adopted here.

---

**M-5 · The text ramp diverges systematically from the design**

| | |
|---|---|
| **Category** | Color · Typography · Accessibility |
| **Location** | `DesignSystem/Palette.swift:36-44` |

Counting every white alpha in the design:

| Design alpha | Uses | Code token | Verdict |
|---|---|---|---|
| **.62** | **133** | *(none)* | design's workhorse secondary — **no token exists** |
| .66 | 24 | `textSecondary` .66 | ✅ |
| .72 / .64 / .60 | 13 / 13 / 14 | — | minor scale members, unmodelled |
| **.52** | **0** | `textTertiary` .52 | **invented** |
| **.40** | **1** | `textQuaternary` .40 | **effectively invented** |

The concrete failure: **track durations and Now Playing timecodes.** Design specifies `13px rgba(255,255,255,.62)` (TrackRow) and `12px rgba(255,255,255,.62)` (screen 23). The app uses `Palette.textQuaternary` = white 40%.

- Design 62% → `#A2A2A2` on `#0A0A0A` = **7.76:1** — passes AA and AAA.
- Code 40% → `#6C6C6C` = **3.77:1** — **fails WCAG AA (4.5:1).**

So the contrast failure is not an accepted trade-off, as `Palette.swift:41-44` frames it — it is a transcription error. Adopting the design's 62% fixes the contrast and the color in one move.

**Locations:** `Components/TrackRow.swift:58`, `:87`; `NowPlaying/NowPlayingView.swift` (`TimecodeRow`).

---

**M-6 · Library is missing two filter chips and the Liked Songs row**

| | |
|---|---|
| **Expected** | Design 16: four chips — Playlists / Albums / **Artists** / **Liked** — plus a pinned "Liked Songs" row above the grid (art `56×56 r8`, fill `linear-gradient(150deg,#E8A33D,#8a5a16)`, heart glyph `24×24 #0A0A0A`) |
| **Actual** | Two chips; no Liked Songs row |
| **Location** | `Library/LibraryView.swift:53-56` |

**Already self-documented** at `LibraryView.swift:43-44` ("Two of the design's four chips are missing: Artists and Liked, along with the pinned Liked Songs row"), attributed to `MusicLibraryService` not yet exposing them. Recorded here for completeness, not as a discovery.

---

**M-7 · Now Playing artwork carries a black drop shadow instead of the design's amber glow**

| | |
|---|---|
| **Expected** | `box-shadow: 0 0 68px 6px rgba(232,163,61,.22)` — a centred **amber bloom**, no offset (design 23) |
| **Actual** | `.shadow(color: .black.opacity(0.6), radius: 30, y: 26)` — a **black** shadow offset 26 pt down |
| **Delta** | Hue amber→black · offset 0→26 pt · spread lost |
| **Location** | `NowPlaying/NowPlayingView.swift:91` |

This is the visual centrepiece of the screen; the design's warm halo is what makes the disc read as lit rather than as a card floating on black.

The surrounding geometry is **exactly right** and worth noting: ring box 322, ring r152 (⌀304) at stroke-width 3, disc 262, knob 13 — all four match `Metrics.artNowPlaying / artNowPlayingRing / artNowPlayingDisc / progressRingWidth / progressKnob` precisely.

---

**M-8 · Twenty designed screens have no counterpart in the nav graph**

See §4. Notable functional gaps rather than polish items: Splash, Onboarding (×2), Artist detail, Now Playing–lyrics, AirPlay picker, Add-to-playlist, Track context menu, New playlist, and the three Settings sub-screens. Loading/error/empty variants (09, 11, 15, 18, 20, 24, 25, 29, 36, 37) are a second cluster.

Flagged, not judged — whether these are descoped is a product call.

---

**M-9 · Toast has only one variant; the design specifies three**

| | |
|---|---|
| **Expected** | Design 30: `padding 13px 18px`, `radius 26`, `blur(24px) saturate(180%)`, border `1px rgba(255,255,255,.16)`, shadow `0 8px 26px rgba(0,0,0,.45)` + `inset 0 1px 0 rgba(255,255,255,.2)`, label `14.5px`. Three fills — **success** amber `.18→.08`, **error** terracotta `rgba(210,113,74,.22→.09)` with an `#E29070` icon and a `Retry` action, **neutral** white `.14→.05` |
| **Actual** | One amber-tinted capsule, no icon, no action, `padding 20h/12v` |
| **Location** | `Components/PlayerBar.swift:82-94` |

A playback failure and a success confirmation currently render identically — the terracotta error language exists in `Palette` but never reaches the toast.

---

### 🟡 Minor

| ID | Screen | Category | Expected (design) | Actual (code) | Delta | Location |
|---|---|---|---|---|---|---|
| **m-1** | Detail | Layout | Play **and** Shuffle both `height 48` | Play 48, Shuffle 50 | 2 pt | `DetailView.swift:194` |
| **m-2** | Detail | Layout | Play `padding 0 30`, Shuffle `padding 0 26` | both 22 | 8 / 4 pt | `DetailView.swift:193` |
| **m-3** | Global | Design system | Tokens referenced | **9 tokens, 0 call sites:** `artDetailHero`, `amberTransport`, `chromeWidth`, `tabCapsuleWidth`, `playerBarRadius`, `playerBarInset`, `playerBarBottomOffset`, `radiusCard`, `tabBarHeight` | dead | `Spacing.swift`, `Palette.swift` |
| **m-4** | Chrome | Layout | Chrome row is **62 pt** tall (island 62×62; capsules = 6+50+6) | `chromeHeight = 64` on all three | 2 pt × 3 surfaces | `Spacing.swift:45`, `:60` |
| **m-5** | Chrome | Layout | Tab capsule inner padding **6** | `tabCapsulePadding = 7` | 1 pt | `Spacing.swift:59` |
| **m-6** | Chrome | Layout | Capsule↔island gap **12** (right:88 − 14 − 62); vertical gap 10 | `chromeGap = 10` used for both | 2 pt horizontal | `Spacing.swift:48` |
| **m-7** | Chrome | Iconography | Player bar `border-radius: 26` | `Capsule()` → radius 32 at h64 | 6 pt | `PlayerBar.swift:71` |
| **m-8** | Chrome | Component states | Selected pill carries `inset 0 0 0 1px rgba(232,163,61,.36)` | fill only, no inset stroke | stroke absent | `HumTabBar.swift:87-89` |
| **m-9** | Global | Layout | Design frame 390 wide | App 402; `chromeWidth = 362` (= 390−28) stale | +12 pt | `Spacing.swift:44` — no live impact (token dead) |
| **m-10** | Home | Typography | Screen title weight **200** | `.ultraLight` (100) | 1 weight step | `Typography.swift:38` |
| **m-11** | Global | Docs | `amberButton` is the 322×56 CTA fill | doc says "Connect, **album Play**" — Play is flat amber | doc error | `Palette.swift:87` |
| **m-12** | Home | Iconography | Avatar **38×38**, bg `#1E1E20`, border `1px rgba(232,163,61,.35)`, glyph 14px `#E8A33D` | 44×44, `surfaceRaised`, **no border**, glyph 20px `textSecondary` | +6 pt, border + amber tint absent | `HomeView.swift:58-61` |
| **m-13** | Library | Layout | Grid `gap: 22px 14px` (row 22, **column 14**) | `libraryGridSpacing = 22` on both axes | 8 pt column | `LibraryView.swift:61-62`, `:131` |
| **m-14** | Settings | Color | Cards `#141416`, `radius 16`, separator `rgba(255,255,255,.07)` inset 18 (52 with leading icon) | `.listStyle(.insetGrouped)` — system fill (≈`#1C1C1E`), system radius | ~`#080805` lighter; radius ~10 vs 16 | `SettingsView.swift:95` |
| **m-15** | Detail | Typography | Album artist **15px**, meta **13px** `rgba(255,255,255,.62)` | 16px and 14px | 1 pt each | `DetailView.swift:76`, `:83` |
| **m-16** | Chrome | Materials | Reduce-Transparency bars: `#1C1A17` + border **`rgba(255,255,255,.14)`**; only the RT *toast* uses the amber edge `rgba(232,163,61,.35)` | `glassOpaqueEdge` (amber .35) applied to every RT surface | wrong edge on bars | `Palette.swift:113`, `GlassSurface.swift:77` |

---

## 6. Per-screen check tables

Legend: ✅ pass · ❌ fail · ⚠️ partial · 🚫 not verified

### 6.1 Home — populated · `01-home.png`

| Category | Result | Notes |
|---|---|---|
| Layout & spacing | ✅ | Header `14/20/22` and section/carousel `gap 14`, `padding 0 20` match the design **exactly** |
| Typography | ⚠️ | `sectionTitle` 19/300/−.2 exact; screen title weight off by one step (**m-10**) |
| Color | ✅ | `#0A0A0A`, `#E8A33D` confirmed |
| Liquid Glass | ❌ | **C-1, C-2** |
| Iconography | ⚠️ | ArtPill 160 art / r10 / gap 10 / title 15 / sub 13 amber .8 — **exact match**; avatar diverges (**m-12**) |
| Component states | ⚠️ | Populated + empty verified; loading (09) and offline (11) unimplemented (**M-8**) |
| Responsiveness | 🚫 | Not exercised |
| Accessibility | ⚠️ | 44 pt targets enforced; **M-5** contrast |
| Motion | ✅ | `rise` .3s ease-out and `levelBar` 1s ease-in-out + .22 stagger match `humRise`/`humBar` exactly |

### 6.2 Library · `02-library.png`

| Category | Result | Notes |
|---|---|---|
| Layout & spacing | ⚠️ | Chips exact (38/19/0 16/13.5, gap 8); grid column spacing wrong (**m-13**) |
| Typography | ✅ | On-ramp |
| Color | ✅ | Chip fills/strokes match `rgba(232,163,61,.16/.45)` and `#161618` exactly |
| Liquid Glass | ❌ | **C-1** |
| Component states | ❌ | **M-6** — 2 of 4 chips, no Liked Songs row |
| Accessibility | ✅ | — |

### 6.3 Playlist / Album detail · `03-detail.png`

| Category | Result | Notes |
|---|---|---|
| Layout & spacing | ❌ | **M-1** hero; **m-1**, **m-2** buttons |
| Typography | ⚠️ | Title 26/300/−.4 exact; **m-15** |
| Color | ✅ | Play pill flat `#E8A33D` on `#0A0A0A` label — **matches design** (see §2) |
| Liquid Glass | ❌ | **C-1, C-2**; the design's 44 pt nav buttons are also glass (`blur(20px)`, white `.14→.05`) — the app's are flat |
| Iconography | ❌ | **M-1** radius 0 vs 14 |
| Component states | ⚠️ | Album variant should be Play + circular ＋ + circular ♥ with **no Shuffle**; app shows Play + Shuffle for both |
| Accessibility | ✅ | Label contrast 9.74:1 |

### 6.4 Search — empty · `08-search.png`

| Category | Result | Notes |
|---|---|---|
| Layout & spacing | ❌ | **M-2** |
| Typography | ✅ | `screenTitle` correct |
| Color | ✅ | On-token |
| Liquid Glass | ❌ | **C-1**; field should be its own glass control (**M-2**) |
| Component states | ❌ | **M-3**, **M-4** |
| Accessibility | ⚠️ | — |

### 6.5 Settings · `09-settings.png`

| Category | Result | Notes |
|---|---|---|
| Layout & spacing | ✅ | Group rhythm and gutters consistent |
| Typography | ✅ | `groupLabel` 11.5/1.5/uppercase — **exact match** to the design's group header |
| Color | ⚠️ | **m-14** system card fill vs `#141416`. Note `SettingsView.swift:121,135` hardcodes `opacity(0.62)` — the design's correct value, which the palette lacks (**M-5**) |
| Liquid Glass | ❌ | **C-1** (tab bar behind) |
| Component states | ✅ | Live values; the Reduce Transparency row served as the oracle for B-2 |
| Accessibility | ✅ | ≥ 5.66:1 |
| **Overall** | **Cleanest screen** — one color issue, no layout defects |

### 6.6 Bottom chrome · `06-home-playerbar.png`

| Category | Result | Notes |
|---|---|---|
| Layout & spacing | ⚠️ | Insets 14 / bottom 22 exact; **m-4**, **m-5**, **m-6** |
| Typography | ✅ | Title 13.5/500, artist 11.5 amber .85, label 13.5/500 — **all exact** |
| Color | ⚠️ | Tint halved (**C-1**); **m-8** inset stroke |
| Liquid Glass | ❌ | **C-1, C-2** — the headline |
| Iconography | ✅ | Art 40/r10, glyphs 17, active 21, idle 22 @ white .68, island icon 23 — **all exact** |
| Component states | ⚠️ | **m-8**; search island correct (see §2) |
| Accessibility | ✅ | 44 pt floor (`HumButtons.swift:130`); VoiceOver labels on every control incl. icon-only tabs (`HumTabBar.swift:97-99`) |
| Motion | ✅ | `matchedGeometryEffect`, honors Reduce Motion (`HumTabBar.swift:65`) |

### 6.7 Now Playing (code + design only)

| Category | Result | Notes |
|---|---|---|
| Layout & spacing | ✅ | Ring 322 / r152 / sw3 / disc 262 / knob 13, hero gutter 34, title-artist gap 7, transport 78 & 52 — **all exact** |
| Typography | ✅ | Title 27/300/−.4, artist 16 `#E8A33D` — exact |
| Color | ❌ | **M-7** disc shadow; **M-5** timecode |
| Liquid Glass | ✅ | Correctly opaque — content layer, per `ARCHITECTURE.md §6` |
| Component states | ⚠️ | Buffering (24) and Track-unavailable (25) unimplemented (**M-8**) |
| Stability | ❌ | **C-3** |

### 6.8 Now Playing · 6.9 Queue

✅ **Both audited** — see §8, added after C-3 was fixed and the screens became reachable.

### 6.10 Connect · 6.11 Subscription gap

🚫 **Not captured** (B-2). The design specs are extracted and in hand (screens 04–07), but both states need a way to force the authorization/subscription path — the preview services grant immediately.

---

## 7. Recommended next steps

Ordered by leverage. **This audit made no code changes; everything below is a proposal.**

1. **C-1 / C-2 — restore the chrome material.** Adopt the `ToastView` pattern (`PlayerBar.swift:91-92`) at `HumTabBar.swift:51`, `:112` and `PlayerBar.swift:71`. Then **re-evaluate the halved tint together with it** — with a real material beneath, the design's 17%→7% may now be correct as measured. Update the stale comments in both files.
2. **M-5 — fix the text ramp.** Add a 62% token, repoint durations/timecodes at it. Single highest-value change: corrects a systematic color error and the only WCAG AA failure at once.
3. **C-3 — reproduce Now Playing on device** before touching `SystemAudioControls`.
4. **M-1, M-7** — two small, high-visibility fixes (hero geometry; amber bloom).
5. **M-2, M-3, M-4** — the Search screen is the least-complete surface in the app.
6. **m-1, m-2, m-5, m-6, m-8, m-10, m-12, m-13, m-15** — small, independent, mechanical.
7. **M-8** — confirm with product which of the 20 undesigned-in-app screens are descoped.
8. ~~Add a launch-argument hook~~ — **done.** See B-1.

---

## 8. Addendum — Now Playing and Queue

Added after the C-3 recursion fix made both screens reachable. Captured on the same device and compared against design screens **23** (Now Playing) and **26 / 27** (Queue). **22 further findings: 4 Major, 18 Minor.**

Screenshots: `shots/15-nowplaying.png`, `shots/16-queue.png`.

### 8.1 What matches exactly

Worth recording, because it is most of both screens. Now Playing's entire hero geometry and transport are correct to the pixel: ring box **322**, ring **⌀304** at stroke **3** with a round cap, track at white **9%**, disc **262**, knob **13**; play disc **78** with a **27** glyph on solid `#E8A33D` under `amber .35 / radius 17 / y 10`; three transport controls with **26** glyphs at **34** apart; the secondary row at **21** and **56** apart in white **66%**. Type is exact too — title 27/300/−0.4, artist 16 amber, gap 7, header overline 11.5/1.6/uppercase at white 62%, timecodes 12pt tabular at white 62%. Queue's track rows are the shared `TrackRow`, already verified in §6.

### 8.2 Now Playing

| ID | Severity | Category | Expected (design 23) | Actual | Delta | Location |
|---|---|---|---|---|---|---|
| **NP-1** | **Major** | Accessibility / Color | Play glyph `#0A0A0A` on amber — **9.18:1** | `Palette.textPrimary` (white) on amber — **2.16:1** | **fails WCAG 3:1 for graphical objects** | `NowPlayingView.swift:565` |
| **NP-2** | **Major** | Layout | Title/artist block **centred**, no control in it | Left-aligned with a trailing add-to-library button | alignment + extra control | `NowPlayingView.swift:112-126` |
| **NP-3** | Minor | Iconography | Knob carries `0 0 14px 3px rgba(232,163,61,.7)` | No shadow — flat amber dot | glow absent | `NowPlayingView.swift:322-325` |
| **NP-4** | Minor | Layout | Header padding `8px 24px 0` | `Metrics.navGutter` = 18 | 6 pt | `NowPlayingView.swift:272` |
| **NP-5** | Minor | Layout | Time row inset **46** | `Metrics.heroGutter` = 34 | 12 pt | `NowPlayingView.swift:102` |
| **NP-6** | Minor | Component states | Header trailing control is an overflow **⋮** (20×20); queue lives in the bottom row | Header trailing control is the queue button | control swapped | `NowPlayingView.swift:264-270` |
| **NP-7** | Minor | Component states | Bottom row is **queue · lyrics · shuffle** | **shuffle · repeat** | repeat is not in the design; lyrics is screen 34, unbuilt | `NowPlayingView.swift:528+` |
| **NP-8** | Minor | Layout | Two bottom rows: volume `bottom 96`, actions `bottom 40` | Three: secondary controls, volume, then an "Up next · N" + AirPlay footer | extra row | `NowPlayingView.swift:96-107` |
| **NP-9** | Minor | Color | Chevron stroke `rgba(255,255,255,.7)` | `Palette.textSecondary` (66%) | 4 pp | `NowPlayingView.swift:253` |
| **NP-10** | Minor | Design system | Ring track = white 9% | Correct value, but hardcoded as `Color.white.opacity(0.09)` rather than `Palette.hairlineStrong` (same value) | token bypass | `NowPlayingView.swift:307` |
| **NP-11** | Minor | Component states | Custom volume track — `height 4, radius 2`, ground white **14%**, fill amber **85%** | `MPVolumeView` (system control, renders empty in Simulator) | custom control replaced by system one | `SystemAudioControls.swift:13-32` |

**NP-1 is the one to fix first.** It is the primary control on the app's centrepiece screen, and at 2.16:1 the glyph fails the 3:1 floor for graphical objects. The design's near-black is not a stylistic preference — it is what makes the control legible. This is the second contrast failure the audit has turned up, after the text ramp.

**NP-2, NP-6, NP-7, NP-8** are all the same underlying decision: the app redistributed Now Playing's secondary controls (add-to-library into the title row, queue into the header, repeat into the secondary row, "Up next" into a footer) where the design keeps the title block clean and gathers actions into one bottom row. Worth settling as a group rather than one at a time.

### 8.3 Queue

| ID | Severity | Category | Expected (design 26) | Actual | Delta | Location |
|---|---|---|---|---|---|---|
| **Q-1** | **Major** | Layout | Now-playing block is a **card**: `margin 0 20 8`, `padding 14`, `radius 14`, fill `#141416` | Plain full-width row with a divider under it — no fill, no radius, no inset | card treatment absent | `QueueView.swift:87-117` |
| **Q-2** | **Major** | Color | "Clear" enabled is `#E8A33D`; disabled `rgba(255,255,255,.25)` | Tinted `Palette.textSecondary` (white 66%) in both states | reads as disabled when it is not | `QueueView.swift:78` |
| **Q-3** | Minor | Iconography | Card art **52** at radius **8** | `artQueueHeader` 56 at `radiusArt` 10 | 4 pt / 2 pt | `QueueView.swift:91-92` |
| **Q-4** | Minor | Color | "Now playing" label `rgba(232,163,61,.9)` | `Palette.honeyAmber` at 100% | 10 pp | `QueueView.swift:98` |
| **Q-5** | Minor | Component states | Card is label + title + meter | Adds an artist line | extra element | `QueueView.swift:103-106` |
| **Q-6** | Minor | Materials | "Done" / "Clear" are plain 16px text | iOS 26 toolbar renders them as glass capsules | unrequested chrome | `QueueView.swift:69-81` |
| **Q-7** | Minor | Component states | Section header row carries an **18×18 shuffle** on the right | Absent | control missing | `QueueView.swift:39-58` |
| **Q-8** | Minor | Layout | Bottom fade — 120 pt `rgba(10,10,10,0)` → `#0A0A0A` | Absent | fade missing | `QueueView.swift:29-64` |
| **Q-9** | Minor | Layout | Section header padding `16px 20px 8px` | top 12 | 4 pt | `QueueView.swift:52` |
| **Q-10** | Minor | Design system | — | Section header hardcodes `textPrimary.opacity(0.62)`; `Palette.textMuted` now exists at exactly that value | token bypass | `QueueView.swift:47` |
| **Q-11** | Minor | Iconography | Meter bars **2.5** wide, **2.5** gap, container **16**, heights 7/14/10 | 3 wide, 3 gap, height 20 | 0.5 / 0.5 / 4 pt | `Motion.swift:53-69` |

**Now verified:** design **27** (Queue — empty) — see §10, added after clearing the queue to drain it to zero.

### 8.4 Check tables

| Category | Now Playing | Queue |
|---|---|---|
| Layout & spacing | ⚠️ NP-2, NP-4, NP-5, NP-8 | ⚠️ Q-1, Q-8, Q-9 |
| Typography | ✅ exact throughout | ✅ |
| Color | ❌ NP-1, NP-9 | ❌ Q-2, Q-4 |
| Liquid Glass / materials | ✅ correctly opaque — content layer | ⚠️ Q-6 |
| Iconography & imagery | ⚠️ NP-3 | ⚠️ Q-3, Q-11 |
| Component states | ⚠️ NP-6, NP-7, NP-11 | ⚠️ Q-5, Q-7; empty state now audited — see §10 |
| Responsiveness | 🚫 not exercised | 🚫 not exercised |
| Accessibility | ❌ **NP-1**; ring is a proper adjustable element with spoken value | ✅ card combines into one element with a spoken label |
| Motion | ✅ arc animates alone; honours Reduce Motion | ✅ meter honours Reduce Motion |

---

## 9. Addendum — Connect and the Subscription Gap

Added after extending the launch-argument hook (`3730122`) with two more flags built specifically to unblock this: `-HumPreviewAuthState <case>` and `-HumPreviewSubscriptionState <case>`, forcing the exact `AuthState` / `SubscriptionState` each screen needs. Captured against design screens **04–07** — with one mapping correction below that changes what "the design" for this family actually means.

Screenshots: `shots/21-connect-invitation.png`, `23-connect-denied.png`, `24-connect-restricted.png`, `25-subscription-gap.png`, `26-subscription-unavailable.png`. **8 new findings: 4 Major, 3 Minor, plus one unscored note (SG-1).**

### 9.1 A mapping correction before the findings

Design screen **05** ("Not subscribed") reads "You're signed in, but there's no subscription," with a **"Try Apple Music free"** primary CTA. That copy and action don't belong to `SubscriptionGapView` — they describe `.gap(canBecomeSubscriber: true)`, and `SubscriptionReducer.resolve` sends that case straight to `presentSubscriptionOffer`, Apple's own native `MusicSubscriptionOffer` sheet (wired in `RootTabView.swift`). `SubscriptionGapView`'s own doc comment already says as much: "`.gap(canBecomeSubscriber: true)` never reaches this view." **Screen 05 is that system sheet's design intent, not a screen this app draws.** Apple owns that sheet's exact pixels, so there's nothing to audit there beyond confirming the routing is correct — which I did, functionally, in §9.3.

What I captured instead — `.gap(canBecomeSubscriber: false)` and `.unavailable` — has **no numbered design screen at all**. `SubscriptionGapView.swift` already says so: "Designed by inference (DECISIONS M-06) from the Connect layout." I audited it against its closest analog, screen **06** (Authorization denied), which the view's own structure clearly borrows from — icon, headline, body, primary CTA, plain-text secondary, in that order.

### 9.2 Connect — invitation, denied, restricted

**What matches exactly**, worth recording before the deltas: the permission-row text (15.5px/300/`rgba(255,255,255,.82)`), the body copy color (white 66%), every hairline divider (`Palette.hairlineStrong` = white 9%, matching all three of the design's `rgba(255,255,255,.09)` row borders), the footnote (12.5px/white 62%), the `HumMark` logo at 52×52, and the invitation heading (36px, tracking −0.9). The `.restrictedNoRecourse` screen correctly renders **no primary button** — `AuthReducer.primaryAction` returns `nil` there by design, and the screenshot confirms it: a plain gap where a dead Settings link would otherwise sit.

| ID | Severity | Category | Expected (design) | Actual | Delta | Location |
|---|---|---|---|---|---|---|
| **CT-1** | **Major** | Layout / Component states | Denied and restricted each get a **distinct** centered layout — screen 06: a 112×112 icon halo (terracotta `rgba(210,113,74,.38)` border), a 44px padlock, and a "Where to look" info card (`#141416`, radius 16) in place of the permission-row list | Both states reuse the **invitation's own layout** verbatim — left-aligned title, the same three generic library/play/lock permission rows, no halo, no info card, no terracotta anywhere | entire layout family swapped for the wrong one | `ConnectView.swift` (one `body` for all four `screen` cases) |
| **CT-2** | **Major** | Liquid Glass / materials | Primary CTA is a **floating glass capsule** — `backdrop-filter: blur(24px) saturate(180%)` under the amber `.26→.12` gradient, on all of screens 04–07 | `AmberCapsuleButton` paints the gradient only; no material | blur absent | `HumButtons.swift:37` (`Palette.amberButton`, no `.glassEffect`) |
| **CT-3** | Minor | Layout | Content block top padding **56px** | `.padding(.top, 72)` | +16 pt | `ConnectView.swift:62` |
| **CT-4** | Minor | Iconography | Permission-row icons **22×22**, stroke-width 1.4 | Rendered at `humFont(17, …)` — a 17pt glyph in a 24pt frame | −5 pt | `ConnectView.swift:196` |

**CT-1's caveat, stated plainly:** `ConnectView.swift:12-14` already discloses this — "The `.denied` and `.restricted` variants have no design and are built by inference from that layout (DECISIONS M-06)." That was true when it was written. It no longer is: screen 06 exists in the recovered design and draws something else entirely. This is reported as a finding because the audit's job is to compare against the design regardless of why the gap exists, not because anyone hid it.

**CT-2 sits in real tension with `ARCHITECTURE.md §6`**, which lists "paywall body" under content that must stay opaque. But the design's floating-glass CTA recipe (`.26/.12` gradient, `blur(24px)`, `rgba(255,255,255,.2)` border, that exact shadow) appears identically on screens 04, 05, 06, and 07's disabled "Connecting…" state — it reads as the design system's standard *primary-action* treatment on content screens, not as "the screen is chrome." Whether the architecture rule should carve out floating CTAs, or the design's floating-glass buttons should be simplified to match the rule, is a call for whoever owns that document — not one this audit makes for them. Flagged, not resolved.

### 9.3 Subscription gap

| ID | Severity | Category | Expected (closest analog — screen 06) | Actual | Delta | Location |
|---|---|---|---|---|---|---|
| **SG-1** | *(note, unscored)* | Coverage | Screen 05's "Try Apple Music free" copy and CTA belong to `.gap(canBecomeSubscriber: true)` | That case never reaches this view — it goes to Apple's native offer sheet, correctly, per `SubscriptionReducer.resolve` | — routing verified correct | `RootTabView.swift` (`.subscriptionOffer`) |
| **SG-2** | **Major** | Iconography | 112×112 icon halo — `border: 1px solid rgba(232,163,61,.35)` (amber, since this isn't an error) around a 46px glyph | Bare 38pt SF Symbol, `Palette.honeyAmber.opacity(0.8)`, no ring at all | halo entirely absent | `SubscriptionGapView.swift:28` |
| **SG-3** | Minor | Typography | Headline 30px / weight 200 (→ `.ultraLight`, the app's own established mapping for CSS 200 elsewhere) | `HumTextStyle(size: 27, weight: .light, …)` | −3 pt, **and** a weight-mapping inconsistent with the app's own convention | `SubscriptionGapView.swift:34` |
| **SG-4** | **Major** | Component states | The secondary action ("Continue without it" / "Try again," both screens 05 and 06) is **plain text** — no fill, no border, white 62% | `OutlineCapsuleButton` — a bordered, amber-outline capsule | wrong component family, not just a color slip | `SubscriptionGapView.swift:58` |

**SG-4 is systemic, not local to this screen.** `OutlineCapsuleButton` is Hum's one secondary-action component, used consistently everywhere a secondary action appears. The design, across this entire screen family, draws secondary actions as unstyled text links instead. That's either a deliberate simplification for visual consistency across the app, or a divergence nobody has revisited since `OutlineCapsuleButton` was built — the report can't tell which from the code alone.

**The play-intent gate itself works.** I verified the routing functionally, not just by reading the reducer: with subscription forced to `.gap(canBecomeSubscriber: false)`, Home correctly hides its catalog shelves entirely (the same `catalogUnavailable` empty state normally shown with no subscription at all) — so I reached a catalog track through Search instead, where browsing isn't gated, only playback is. Tapping a result correctly opened the gap sheet reading "Apple Music Needed," with only "Continue Without It" (no retry — correct, this isn't a failed check). Forcing `.unavailable` produced "Couldn't Check," this time with both "Try Again" and "Continue Without It" — matching `SubscriptionGapView.swift:52`'s `if let onRetry` exactly. `.gap(canBecomeSubscriber: true)` was not separately re-tested against the live offer sheet — see SG-1.

**Not captured:** the connection-failed toast, design screen 07. Its spec models a *network* failure mid-`request()` — a terracotta toast reading "Can't reach Apple Music," retry action, the invitation screen dimmed to 55% behind it, spinner still running. `MusicAuthorizationService.request() async -> AuthState` is non-throwing, and `MusicAuthorization.request()` is a local system permission sheet, not a network call — there is no failure mode in the current protocol for this screen to represent. This may be a screen the design imagined for a networked OAuth-style flow that doesn't describe how `MusicAuthorization` actually works, rather than a build gap. Worth a product conversation before anyone builds toward it.

### 9.4 Check tables

| Category | Connect (invitation/denied/restricted) | Subscription gap |
|---|---|---|
| Layout & spacing | ⚠️ CT-3 | ✅ matches its closest analog on the measures that transfer |
| Typography | ✅ exact on invitation; not applicable to denied/restricted's borrowed layout | ⚠️ SG-3 |
| Color | ✅ every color checked matches exactly | ✅ body/secondary colors match; icon tint correct (amber, not terracotta — this isn't an error state) |
| Liquid Glass / materials | ❌ **CT-2** | ❌ same gap, not re-scored — see CT-2 |
| Iconography & imagery | ⚠️ CT-4 | ❌ **SG-2** |
| Component states | ❌ **CT-1** | ❌ **SG-4**; routing verified correct (SG-1) |
| Responsiveness | 🚫 not exercised | 🚫 not exercised |
| Accessibility | ✅ permission rows combine into one VoiceOver element each | ✅ icon/headline/body combine into one element |
| Motion | ✅ `ConnectSpinner` holds still under Reduce Motion, button copy still reads "Connecting…" | 🚫 not applicable — no motion in this view |

---

## 10. Addendum — Queue Empty State

Design screen **27**, audited by clearing a five-track queue to zero (§8's populated state, `shots/16-queue.png`, drained via "Clear") and capturing the result. Screenshot: `shots/29-queue-empty.png`. **3 new findings — 1 Major, 2 Minor — plus two unscored notes.**

### 10.1 The structural note first

Design screen 27 shows **no "Now Playing" card at all** — its empty block sits alone under the header, describing a player that is fully idle: nothing playing, nothing queued. The app's `nowPlayingCard` renders `if let current = player.currentTrack`, and `RootTabView` only offers a route into `NowPlayingView` — and from there, into `QueueView` — when a track is already playing (`PlayerBar` itself only renders under the same condition). **The empty state design screen 27 draws is not reachable through the app's own navigation.** The state that *is* reachable — queue drained while something plays — always carries the now-playing card design 27 omits.

This reframes the button-copy difference below (Q-N2) as a consequence of this, not a separate miss: the app's "Fill from this album" is contextually correct for the only state it can actually be in (something is always playing), where design 27's static "Browse library" fits the idle state it draws instead. Neither screen is wrong for the state it describes; they describe different states, and only one of the two is ever reachable.

### 10.2 Findings

| ID | Severity | Category | Expected (design 27) | Actual | Delta | Location |
|---|---|---|---|---|---|---|
| **Q-12** | **Major** | Color / Component states | "Browse library": **no fill**, `border: 1px solid rgba(232,163,61,.5)`, label `#E8A33D` | `OutlineCapsuleButton`: filled `Palette.amberOutlineFill` (amber 16%), label `Palette.textPrimary` (white) | wrong fill, wrong label color | `EmptyStateView.swift:37`, `HumButtons.swift` (`OutlineCapsuleButton`) |
| **Q-13** | Minor | Iconography | 96×96 icon ring, `border: 1px solid rgba(232,163,61,.35)`, icon stroke 100% | No ring at all; icon at `Palette.honeyAmber.opacity(0.7)` | ring absent; icon dimmed 30pp | `EmptyStateView.swift:18-22` |
| **Q-14** | Minor | Typography / Layout | Headline **21px**; button height **48** | Headline `19px` (`HumTextStyle` size 19); button height `46` | −2 pt each | `EmptyStateView.swift:25`, `HumButtons.swift:106` |

**Q-12 is the one to fix first, and it isn't new** — it is `SG-4` again, on the same shared component, failing in the *opposite* direction. `SubscriptionGapView`'s "Continue Without It" (SG-4) should be plain text and gets a bordered pill instead; here, "Browse library" should be a bordered-but-unfilled pill and gets a filled one, with the wrong label color on top. **`OutlineCapsuleButton` cannot satisfy both call sites as one recipe — the two design screens that use it want two different secondary-button treatments**, and the correct *unfilled* version already exists elsewhere in the app: `DetailActionButton`'s `.outlined` style (Detail's Shuffle button) is `Capsule().strokeBorder(Palette.honeyAmber.opacity(0.5), lineWidth: 1)` with no fill at all — the exact recipe design 27 specifies, already built and already verified correct, one file away.

### 10.3 A second unscored note

**Q-N2**, following from §10.1: the button's copy and behavior ("Fill from this album," calling `player.refillFromCurrentSource()`) is a context-aware action the design's static "Browse library" doesn't specify — arguably a real improvement given the state is always reached with something playing, not a straightforward miss. Recorded for completeness, not scored.

### 10.4 What matches exactly

The headline copy is verbatim: "Nothing after this one" is the app's own string and design 27's, identically. The body copy is a close paraphrase carrying the same meaning, adjusted for the different button it leads into. The icon glyph — list lines with a play mark in the design's SVG — is reasonably matched by `HumIcon.library` (`music.note.list`), though an exact glyph-for-glyph comparison isn't possible from measured CSS alone.

---

## 11. Provenance

- **Screenshots:** captured with `xcrun simctl io … screenshot` on iPhone 17 Pro / iOS 26.5 and referenced throughout as `shots/…`. **Not committed** — they are ~14 MB of PNGs and were left out of the repo deliberately, so the `design-audit/shots/` paths cited above resolve only in the working tree they were captured in.
- **Design values:** extracted from inline CSS in `designs/Hum-All-Platforms.html`, unpacked from its bundler manifest (gzip+base64) into `01-iPhone-Screens-and-UI-System.dc.html` (42 screens) plus `Dock`, `TrackRow`, `ArtPill`, `StatusBar` components. Every number is quoted from a style attribute, not measured off a raster.
- **Contrast:** WCAG 2.1 relative luminance, alpha-composited over `#0A0A0A`.
- **Alpha census:** regex count of every `rgba(255,255,255,α)` and `rgba(232,163,61,α)` in the design source.
- **Token usage:** `grep` across `Hum/`, excluding declarations.
- **Launch arguments:** `-HumPreviewAuthState` and `-HumPreviewSubscriptionState`, added to `HumApp.swift` alongside the existing `-HumUsePreviewServices` for this addendum — see §9. Debug-only, `#if DEBUG`-gated, same as the flag they extend.
- **Source tree:** every screenshot before §9 required no source edit (B-1). §9's two new launch-argument flags are a genuine, intentional change to `HumApp.swift`, not a capture-then-revert — committed as tooling, the same as `-HumUsePreviewServices` itself.
