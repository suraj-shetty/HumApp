# Screen-by-screen diff — design against build

**Phase 7, step 2.** Every divergence recorded **before** any of it is fixed, so the list can be triaged rather than worked in discovery order.

**Method.** Measured from computed styles on the rendered `designs/Hum-All-Platforms.html`, screen by screen, against the implementation source. Numbers below are *measured*, not quoted from the design's prose. See [DESIGN_TOKENS.md](DESIGN_TOKENS.md) for the token set and the method note.

**On the Figma file.** `figma.com/design/8DgzM3iIfq0AprGO00bChi` is an **html.to.design (free version) import of this same HTML bundle** — one flat 1920×21296 DOM mirror, every frame named `div`, auto-derived variables (`stroke weight/0_9166666865348816`, `Tulip Tree`, `Raw Sienna`). It is a derived copy, so the HTML remains the authority. It is useful as corroboration and independently confirms `corner radius/26` + `corner radius/28` as distinct tokens, `letter spacing/1_6`, and `#1c1a17`. **One trap:** the import substituted **Inter** for `-apple-system`. The design is SF Pro. Never take type from the Figma values.

---

## The good news first

After Phase 7's component work, most of the ramp is already right. Verified matching, measured:

| | Design | Build |
|---|---|---|
| Screen titles | 32 / 200 / −0.8 | ✅ `screenTitle` |
| Section titles | 19 / 300 / −0.2 | ✅ `sectionTitle` |
| Shelf card title / subtitle | 15 / 400 · 13 / 400 amber 80% | ✅ `humFont(15)` / `humFont(13)` |
| Track row title / artist / duration | 16 / 400 · 13.5 / 400 amber 80% · 13 / 400 white 62% | ✅ |
| Player bar title / artist | 13.5 / 500 · 11.5 / 400 amber 85% | ✅ |
| Player capsule | 362 × 64, r26, art 40 r10 | ✅ |
| Detail title / meta | 26 / 300 / −0.4 · 14 / 400 amber 80% | ✅ |
| Settings group headers | 11.5 / 1.5 uppercase white 62% | ✅ `groupLabel` |
| Queue "NOW PLAYING" / "NEXT FROM" | 11 / 1.5 · 11.5 / 1.5 | ✅ |
| Connect primary button | 322 × 56 + 1px border, r28, 17pt | ✅ height 58 |
| Library grid card | 169 wide | ✅ `.adaptive(minimum: 160)` resolves to ~168 |

**The tab architecture is right.** The design's bottom chrome is a **288-wide tab capsule holding two 135 × 50 pills** plus a **separate 64 × 64 circular search island** at x=313. That is exactly what `Tab("Home")`, `Tab("Library")` and `Tab(role: .search)` render as on iOS 26. The structure was correct before this audit.

---

## Divergences — triage list

### D-1 · Detail carries a nav title the design does not have · ✅ **FIXED**
`DetailView.swift:39` sets `.navigationTitle(collection.title)`. **The design's detail screen has no nav-bar title** — measured: the only title on screen 19 is the header at 26/300. This confirms the previously-logged "detail title appears twice" finding *with design evidence*, and settles it: the nav title goes.

### D-2 · Now Playing title and artist are oversized · ✅ **FIXED**
| | Design (screen 23) | `NowPlayingView.swift:187,191` |
|---|---|---|
| Track title | **27** / 300 / −0.4 | 30 / light / −0.5 |
| Artist | **16** / 400 amber (full) | 18 |

### D-3 · Settings has no Disconnect row · **decide, then fix**
The design's Settings (screen 28) carries **"Disconnect Apple Music" at 15 / 400 in terracotta `#D2714A`** — the destructive action, in the error colour. The build has no such row.

⚠️ **Platform tension, not a simple omission.** MusicKit authorization cannot be revoked from inside the app; it is a Settings.app permission. Implementing this honestly means deep-linking to Settings, not "disconnecting". Needs a decision before it is built.

### D-4 · Settings groups do not match · **decide**
Design: **Apple Music · PLAYBACK** (Crossfade, Play over cellular, Audio quality) **· ABOUT** (Support, Privacy).
Build: Apple Music · **Appearance** · About.

"Appearance" is not in the design; Playback is not in the build. Note Audio quality, Support and Privacy are three of the known-missing sub-screens (39, 40, 41), so this overlaps the missing-screens scope decision.

### D-5 · `overline` tracking is short · ✅ **RESOLVED — the token was dead**
`Typography.swift:66` — `overline` is tracking **1.4**; the design's overline is **1.6** (corroborated independently by the Figma import's `letter spacing/1_6`). **Correction to this entry.** `overline` turned out to be referenced **only in comments** — nothing rendered through it, so its tracking never reached the screen, and it could not have been merged with Now Playing's 11.5/1.6 inline style as this entry originally suggested (different sizes: 11 vs 11.5). The token was deleted rather than corrected: a dead token carrying a wrong value is an invitation to use it later.

### D-6 · `tabLabel` is a dead token · ✅ **FIXED — deleted**
`Typography.swift:57` declares `tabLabel` at 11pt. **It is used nowhere.** The design's tab label measures 13.5 / 500, but the native `TabView` owns its own label typography, so neither value is reachable without hand-building the bar — which the brief forbids. Deleted, with a comment left in `Typography.swift` recording why neither it nor `overline` exists.

### D-7 · `surfaceRaised` is the wrong colour · ✅ **FIXED**
**This entry's premise was wrong.** `surfaceRaised` is not the glass fallback at all — its single call site is the Home avatar plate (`HomeView.swift:56`), and the design measures that plate at `rgb(30, 30, 32)` = **`#1E1E20`**, Slate 900. So `#1C1A18` was neither the fallback nor the plate; it matched nothing in the design.

Retinted to `#1E1E20`. It now shares a value with `artworkFill` and keeps its own name, since one is a control's ground and the other is missing artwork.

### D-8 · `bodyL` weight · **check call sites, then decide**
`bodyL` is 16 / **light**; the design's 16pt body is **regular**. Track rows use `rowTitle` (regular) and are correct, so this only affects wherever `bodyL` is actually used. Check before changing.

### D-9 · Search "Browse" genre grid missing · **scope decision**
Design screen 12 shows, before typing, a **2-column Browse grid: 169 × 96 cards, r12, labels 16 / 300** — Ambient, Jazz, Classical, Folk, Electronic, Soul. The build's Search has no Browse state. Part of the missing-screens scope decision, not a defect.

### D-10 · Tab bar width under the accessory · **divergence, likely not fixable**
Design: player capsule **362** wide, tab capsule **288** — different by intent, at different radii (26 vs 28). Observed on device: the tab capsule expands to match the accessory above it. So this is a real divergence and *not* the design's intent, as the earlier note left open.

**But** `tabViewBottomAccessory` and the tab bar share a system-owned container on iOS 26; matching the design likely means hand-building the tab bar, which the brief forbids. **Recommend accepting and recording it.** Do not hand-roll the bar to close it.

---

## Step 3 progress

Five fixed in one pass (D-1, D-2, D-5, D-6, D-7): clean device build, zero warnings, 72 tests passing, containment clean. **Not yet confirmed on device** — all five are visual and want eyes.

Still open and needing decisions: **D-3** (Disconnect row), **D-4** (Settings groups), **D-9** (Browse grid). **D-10** recommended for acceptance rather than fixing. **D-8** needs its call sites checked.

---

## Closed without action

**"The destructive swipe action renders in Honey Amber"** — stale. `QueueView.swift:151` already tints `Palette.terracotta`, and the design labels terracotta the *error* colour, confirmed again by Settings' terracotta Disconnect row. Correct as built.

---

## Not covered by this pass

- **Screens measured:** Home (08), Search-before-typing (12), Library (16), Playlist detail (19), Now Playing (23), Queue (26), Settings (28), Connect (04) — eight.
- **Not measured in depth:** the loading / empty / error variants of each (09–11, 14–15, 17–18, 20, 27, 37), and Album/Artist detail (21–22). These share components with the screens above, so most divergences should already be caught, but that is an assumption, not a measurement.
- **The fourteen entirely-missing screens** are catalogued in PROGRESS.md and remain a scope decision, not a diff finding.
