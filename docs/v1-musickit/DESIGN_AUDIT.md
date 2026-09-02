# Phase 7 — iPhone design audit

**Sources:** `designs/Hum-All-Platforms.html`, which bundles
`01-iPhone-Screens-and-UI-System` (screens and tokens),
`02-iPhone-Interactive-Prototype` (**authority on behaviour**), and
`03-iPad-and-Watch-Screens` (Phases 8–9).

**Method:** every divergence recorded before anything is fixed, so the list can
be triaged rather than worked through in discovery order.

**Status:** step 1 complete (sources read, tokens diffed, screens inventoried).
**Triage A — token corrections — done**, see §6. B, C and D open.

---

## 1. Design laws, quoted

Stated once at the top of the UI system and binding on every screen and platform:

- Ground **#0A0A0A** device, **#121214** board
- Accent **#E8A33D** amber — *one accent, no second*
- Warning **#D2714A / #E29070**
- Type **SF Pro Display; weights 200/300/400 only**; `ui-rounded` for the "hum," wordmark; **`ui-monospace` for all timecodes**
- Glass **chrome only** (status bar, dock, toolbars). Content surfaces opaque. Never blur a content surface.
- Targets **44×44pt minimum, always**
- Radius **46 device · 24 sheet · 18 card · 10 art · 22 pill**
- Motion **.3s ease-out rise for entry; no bounce, no spring**
- Copy **what happened → what still works → what to do next. No blame, no apology, no cuteness.**

---

## 2. Token diff

### Colour

| Design | Built | Verdict |
|---|---|---|
| Deep Onyx `#0A0A0A` · content | `deepOnyx 0x0A0A0A` | ✅ |
| Honey Amber `#E8A33D` · accent | `honeyAmber 0xE8A33D` | ✅ |
| **Terracotta `#D2714A` · error** | *absent* | ❌ **missing entirely.** This is why the destructive swipe action is drawn in the accent colour — there was no error token to reach for. Also implicates every error and warning surface: the Home failure rows, `InlineError`, the subscription-gap icon |
| **Slate 900 `#1E1E20` · art plate** | `artworkFill 0x15141A` | ❌ wrong value |
| Amber Glass — chrome tint only | `.glassEffect` tint | ✅ |
| Warning secondary `#E29070` | *absent* | ❌ |

### Type

| Design | Built | Verdict |
|---|---|---|
| Weights **200/300/400 only** | `wordmark` uses `.semibold` (600); `IconButton` defaults `.medium` (500); `PlayerBar` transport uses `.semibold` | ❌ **law broken in at least three places** |
| Title 26 / Light | `titleM` 27 / Light | ⚠️ close, off by one |
| Body 16 / Regular — track titles | `rowTitle` 15.5 / Regular | ⚠️ off by 0.5 |
| **Caption 13.5 — artist, amber 80%** | `rowSubtitle` 13.5 but coloured `textTertiary` (white 52%) | ❌ **wrong colour** — artists should be amber at 80%, not grey |
| Overline 11 / 1.6 tracking | `overline` defaults 13 / varies | ❌ |
| **Nothing below 11pt** | `tabLabel` 10.5 | ❌ |
| `ui-monospace` for **all** timecodes | `.monospacedDigit()` on the system face | ❌ digit-width only, not a monospace face |
| `ui-rounded` wordmark | `.rounded` ✅ but at `.semibold` | ⚠️ right face, illegal weight |

### Radius

| Design | Built | Verdict |
|---|---|---|
| **46 device** | — | n/a (device frame is prototype chrome) |
| **24 sheet** | not set explicitly | ❓ system default |
| **18 card** | `radiusArtLarge 14` | ❌ |
| **10 art** | `radiusArtShelf 10` ✅, but also `radiusArtMedium 12`, `radiusArtSmall 8`, `radiusRowThumb 7` | ❌ the design has **one** art radius; the build invented four |
| **22 pill** | capsules use `.capsule` | ⚠️ needs measuring |

### Motion

| Design | Built | Verdict |
|---|---|---|
| `.3s` ease-out rise | `rise = easeOut(0.32)` | ⚠️ 0.32 vs 0.3 |
| **no bounce, no spring** | `press = .spring(response: 0.24, dampingFraction: 0.7)` | ❌ **law broken** — every pressable button uses a spring |

### Glass discipline

The design states: *"Adjacent glass merges: the player bar and tab bar are **one capsule**, search is its own island."* Section 02 then labels them *"separate glass capsules"*. **The two statements conflict** and `02-iPhone-Interactive-Prototype` is the authority on behaviour — resolve there before touching the tab bar.

This bears directly on the reported tab-bar defect: if the design wants one merged capsule, the current two-capsule arrangement is wrong independent of any width change.

Also unimplemented: **"Reduce Transparency swaps every glass fill for `#1C1A17` at 96%."** The build relies on SwiftUI's automatic substitution and never specifies this value — a concrete, testable Phase 6 item that the design already answers.

---

## 3. Screen inventory — 43 designed, 9 built

### Built

Connect · Home · Search · Library · Detail (album/playlist/artist) · Now Playing · Queue · Settings · the subscription-gap sheet.

### Designed and entirely absent

| | Screen |
|---|---|
| 01 | Splash |
| 02–03 | Onboarding, 1 of 2 and 2 of 2 |
| 25 | Track unavailable |
| 29 | Full-screen error |
| 31 | Track context menu — long press |
| 32 | Add to playlist — sheet |
| 33 | Search — focused, recents + keyboard |
| 34 | Now Playing — lyrics |
| 35 | Output / AirPlay picker |
| 39 | Settings → Audio quality |
| 40 | Settings → Support |
| 41 | Settings → Privacy |
| 42 | New playlist — create |
| 43 | Share — *reference only, and out of scope: sharing MusicKit content is a compliance line* |

Plus an **app icon** in three appearance modes (default, clear, tinted) and a **Hum-mark** with a defined ripple system that scales by size — three ripple pairs at full scale, two at 24pt, one at 16pt.

### Designed as states of built screens, not implemented

Home loading / empty / offline · Search before-typing / no-results / error · Library empty / sync error · Playlist loading / empty · Now Playing buffering · Queue empty ✅ (built) · Detail failed-to-load · **Dynamic Type AX3 list reflow (38)** — the design specifies the reflow, so Phase 6's Dynamic Type item has a target to match rather than a judgement call.

---

## 4. Component divergences already recorded

Carried from the earlier data-audit, now with design context:

1. **Track row art is 56pt in the design; the build uses 52pt.**
2. **Toasts have actions in the design** ("Can't reach Apple Music" + Retry). The build's `ToastView` is text-only.
3. Detail title duplicated between nav bar and header.
4. Nav title lacks scroll-edge material over artwork.
5. Grid subtitles truncate at one line.
6. Fixed hero art clips below 390pt of width.
7. Tab bar capsule changes width with the accessory — see the merged-capsule conflict above.

---

## 5. Recommended triage

**A — Token corrections.** Cheap, mechanical, and they fix real defects: add Terracotta and use it for errors and destructive actions; correct Slate 900; remove the illegal weights; make artists amber; collapse four art radii to one; drop the spring.

**B — States of screens that exist.** Loading, empty and error states are designed for every screen and largely absent.

**C — Missing screens.** Splash, onboarding, context menu, add-to-playlist, AirPlay, lyrics, the three Settings sub-screens, new playlist. **This is a scope question, not an audit finding** — it is roughly as much UI again as exists today, and several items need capabilities the app does not have.

**D — Out of scope.** Share (43) collides with the compliance rule against export of MusicKit content, and should stay unbuilt whatever the design shows.


---

## 6. Triage A — token corrections · **DONE**

Every item in §2 that was a mechanical mismatch is now corrected. Verified in the
Simulator and installed on device.

| Correction | Was | Now |
|---|---|---|
| Terracotta error token added | absent | `terracotta #D2714A`, `terracottaLift #E29070` |
| Errors drawn in the error colour | `InlineError` icon in Honey Amber | Terracotta — amber means "yes" everywhere else, so an error drawn in it read as an invitation |
| Destructive swipe action | inherited the app's amber tint | `.tint(Palette.terracotta)` |
| Art plate | `0x15141A` | Slate 900 `0x1E1E20` |
| Wordmark weight | `.semibold` (600) | `.regular` (400) — the law was broken in the one place the brand is most visible |
| `IconButton` default weight | `.medium` (500) | `.regular` |
| Player bar transport, Now Playing transport, capsule buttons | `.semibold` / `.medium` | `.regular` |
| Track artist | `textTertiary`, white 52% | Honey Amber at 80%, per the type ramp |
| Timecodes | `.monospacedDigit()` on the proportional face | `HumFont.timecode()` on a genuinely monospaced face |
| Track row art | 52pt | 56pt |
| Art radii | four values: 14 / 12 / 10 / 8 / 7 | **one**: `radiusArt = 10`. `radiusCard = 18` added for cards, which the design scales separately |
| Row title | 15.5 | 16 |
| Title M | 27 | 26 |
| Overline default | 13 | 11 |
| Tab label | 10.5 | 11 — the design's floor is "nothing below 11pt" |
| Press animation | `.spring(response: 0.24)` | `.easeOut(0.16)` — "no bounce, no spring" |
| Rise | 0.32s | 0.30s |

**Not addressed by A, deliberately:** the 22pt pill radius needs measuring against
the design rather than guessing, and the sheet radius (24) is currently whatever
the system provides. Both are recorded in §2.

72 tests pass; containment passes; device and Simulator builds are warning-free.


---

## 7. Measured component specs — read from the rendered design

§2 diffed the design's *prose*. This section reads the rendered board's DOM and
computed styles, which is the only way to audit appearance. It immediately
corrected one of my own §6 changes and produced numbers no amount of reading
would have given.

**Authority, stated in the design's own header:** *"Board 01 wins on visual
values. Board 02 wins on behaviour. Board 03 inherits every law from 01."*

### Correction to §6 — the wordmark

Every `hum,` in the design, at every size **including the 30pt one inside the
Home header**, measures `ui-rounded` at **weight 600**, amber. The
"weights 200/300/400" law governs **SF Pro Display**, the UI face; the wordmark
is a brand asset and is exempt. §6 lowered it to Regular on the strength of the
prose — wrong, and now reverted. Its default size is also 30, not 32.

### Chrome — measured

| Element | Design | Built |
|---|---|---|
| **Player bar** | **362 × 64**, radius **26**, border `1px rgba(255,255,255,.16)`, `blur(26) saturate(1.8)` | system `tabViewBottomAccessory`, system capsule |
| **Tab bar** | **288 × 64**, radius **28** — *fixed width, independent of the player bar* | system tab bar, width varies with the accessory |
| **Search island** | **64 × 64 circle**, same glass | `Tab(role: .search)`, system-sized |
| Toast | 362 × 46, radius **26** | capsule |
| Toast with action | 350 × 49, radius 26, carries **Retry** | no action variant exists |
| Offline banner | 362 × 41, radius **20** | not built |
| Search field | 350 × 48, radius **23** | system `.searchable` |
| Context menu | 350 × 372, radius **20** | not built |
| Bottom sheet | 390 × 641, radius **38 38 0 0** | system detent |
| Circular buttons | 64 and 46, radius 50% | mixed |
| Splash mark plate | 172 × 172, radius 38 | not built |

**This answers the tab bar report.** In the design the tab bar is a **fixed 288pt
wide** and the player bar above it is **362pt** — deliberately different widths,
with the tab bar plus the 64pt search island together spanning the player bar's
width. The app's tab bar instead *resizes* when the accessory appears. So the
behaviour you noticed is a genuine divergence, not a system quirk to accept.

The radius law says "24 sheet", but the measured sheet is 38. Board 01 wins on
visual values, so **38**.

### What this implies

The player bar and tab bar are `tabViewBottomAccessory` and the system `TabView`,
which own their own geometry. Matching 362/288/64 and radii 26/28 may not be
expressible through those APIs. That is a **real architectural decision** —
the brief says not to hand-build the tab bar, and the design specifies
measurements the system does not offer. It needs to be taken deliberately, not
discovered halfway through a styling pass.

### Method note

Reading the design as text produced a wrong change to the wordmark and missed
every measurement above. Serving the bundle over `http://` and querying the DOM
produced both. **Audit rendered output, not prose.**
