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


---

## 8. Amber Glass — the chrome fill · **DONE**

Decision taken: **keep the native tab bar and accessory**, match the *background*
to the design. Measured recipe, identical on every glass surface the design draws:

```
background   linear-gradient(#E8A33D 17% → #E8A33D 7%)
border       1px  rgba(255,255,255,.16)
highlight    1pt inset along the top edge, rgba(255,255,255,.20)
shadow       rgba(0,0,0,.5) 0 10px 34px
material     blur(26) saturate(1.8)     ← supplied by the system, not us
```

Implemented as `amberGlass(in:)` in `GlassSurface.swift` — a **tint layer over**
the system material, not a second material, which is what the design's
"Amber Glass · chrome tint only" token describes and why it does not breach the
glass-on-glass rule. Applied to the player bar and the toast, the two glass
surfaces Hum controls.

**The measured value had to be halved to match the measured appearance.** The
design's 17% sits over a transparent `backdrop-filter`; the system's Liquid Glass
already tints and darkens what it covers, so laying 17% on top double-counts and
reads brown rather than warm. At 8.5% → 3.5% the result matches the board side by
side. Recorded because it is a judgement, not a measurement: **the design's
number describes an appearance over a different base.**

### What could not be matched

**The tab bar's fill is system-owned.** `TabView` draws its own material and
offers no hook for a tint layer — `.tint` colours the items, not the bar. So the
player bar carries the design's amber and the tab bar does not, and the two do
not read as one family. Matching it means hand-building the bar, which the brief
forbids and which was explicitly ruled out. **Left as a known divergence.**

Also unmatched, and gated on the same constraint: the tab bar's fixed 288pt width
and 28pt radius, the player bar's 362×64 at radius 26, and the 64pt search
island. All are system geometry.


---

## 9. Player bar — measured part by part · **DONE**

The tint alone did not make it match, because almost every *part* diverged.
Measured from the design's own DOM:

| Part | Design | Was | Now |
|---|---|---|---|
| Artwork | **40 × 40, radius 10** — a rounded square | 46pt **circle** | 40pt rounded square |
| Title | 13.5, weight **500**, white | 14.5, Regular | 13.5 Medium |
| Artist | 11.5, weight 400, **amber at 85%** | 12.5, **grey** | 11.5 amber 85% |
| Transport icons | 17 | 19 | 17 |
| Row gap | 11 | 13 | 11 |
| Padding | 9 vertical, 11 horizontal | 10 / 8 | 9 / 11 |

The circular thumbnail was the single most visible error: the design has never
had one. `CircularArtworkView` is now unused by the player bar.

### The weight conflict, resolved once

The design's prose says "weights 200/300/400 only". Its rendering uses **500**
for this title and **600** for the wordmark. Both cannot hold.

**Resolution: the rendering wins for visual values**, per the design's own
authority note, and the prose law is read as describing the *body* ramp rather
than every label. This is recorded here so it is settled once rather than
re-litigated at each component — it has already caused one wrong change and one
revert.

### Still divergent, and system-owned

Container geometry: the design's 362 × 64 at radius **26** is a flatter shape
than the capsule `tabViewBottomAccessory` draws, and the accessory owns its own
size. Unchanged, per the decision to keep native chrome.


---

## 10. Track row · **DONE**

Measured from the design's DOM:

| Part | Design | Was | Now |
|---|---|---|---|
| Row height | 74 (56 art + 9 top + 9 bottom) | 78 | 74 |
| Vertical padding | **9** | 11 | 9 |
| Content inset | **20** | 24 | 20 |
| Art | 56, radius **8** | 56, radius 10 | 56, radius 8 |
| Gap | 14 | 14 | ✅ already |
| Title | 16 / 400 white | 16 / 400 | ✅ already |
| Artist | 13.5 / 400, **amber 80%** | 13.5 amber 80% | ✅ already |

The art radius forced a second exception to the "one art radius" law: rows
measure **8**, the player bar **10**. Per §9's resolution, the rendering wins, so
`radiusArtRow` exists alongside `radiusArt`.

The content inset moved from 24 to 20 **globally** — the design's row is
full-width with 20pt internal padding, so 20 is the content gutter. This is the
first change in this audit to affect every screen at once.

---

## 11. Measured while auditing the row — not yet applied

Two divergences surfaced during the row measurement and are recorded rather than
silently fixed:

1. ~~Section headers~~ — **fixed, see §12.**
2. ~~Shelf cards~~ — **fixed, see §14.**

Next components in order: section header, shelf card, Now Playing transport,
Connect screen.


---

## 12. Section header · **DONE**

Measured consistently across three screens — "Recently played", "Made for you",
"Downloaded":

| | Design | Was |
|---|---|---|
| Size | **19** | 11 |
| Weight | **300 Light** | 400 Regular |
| Colour | **white** | white 56% |
| Case | **sentence** | UPPERCASE |
| Tracking | **-0.2** | +1.4 |

Every attribute was wrong, which is why this read as a different screen rather
than a mis-sized one. `HumFont.sectionTitle` added; `SectionHeader` no longer
uses `overline()`.

**The overline style itself is not wrong — it was applied to the wrong thing.**
The design does use an 11pt tracked overline, for the Home greeting and the
detail meta line. Section headers were simply never it.

### Measured alongside — now done, see §13.


---

## 13. Home header · **DONE**

Measured on the design's Home screen, the header is **three divergences in one
element**, and structural rather than stylistic:

| | Design | Was |
|---|---|---|
| Content | **"Evening"** — part of day only | "WEDNESDAY NIGHT" — weekday included |
| Style | **32 / weight 200 / white / -0.8** | 11.5 uppercase, tracked, grey |
| Structure | greeting **+ profile control, nothing else** | greeting overline **+ `hum,` wordmark** + profile |

An earlier note in §11 recorded the greeting as "16 / 400" — that was a
mis-identified element on another board. Measured on the Home screen itself it
is **32 / 200**, a display title.

### The wordmark is gone from Home — deliberately, and worth a second opinion

The design's Home carries **no wordmark**. It appears on Connect, splash and
onboarding, where the design does use it. Following the design removes Hum's
brand mark from the app's main screen, which is a bigger call than a type
change and is flagged here rather than buried: **if the wordmark should stay on
Home, this is the change to reverse.**

The greeting copy also changed — the weekday is gone, because the design shows
only the part of day.


---

## 14. Shelf card · **DONE**

| Part | Design | Was |
|---|---|---|
| Art | **160**, radius 10 | 148, radius 10 |
| Card height | 208 (160 + 10 + caption) | — |
| Art → caption gap | 10 | 10 ✅ |
| Title | **15** / 400 white | 14.5 |
| Subtitle | 13 / 400, **amber 80%** | 13, grey 52% |
| Title → subtitle gap | **4** | 10 |

The caption pair is now its own stack, because the two gaps differ — 10 from the
art, 4 between the lines. A single `VStack(spacing: 10)` cannot express that, and
the even spacing is why the caption read as two loose labels rather than one
block.

**The amber subtitle is now the third place this colour appears** — row artist,
player bar artist, shelf subtitle. It is the design's consistent treatment for
the secondary line under a title, which the build had as grey everywhere.

### Noted, not applied

The design's card subtitle for a playlist reads **"24 songs"** — a count, not a
curator. Hum shows `collection.subtitle`, which is the artist or curator. One
sample is not enough to generalise, and changing it means changing what
`HumCollection.subtitle` carries. Left alone.

Library's grid still uses a 148pt adaptive minimum and its own card rendering;
it is a separate component in the design and has not been audited yet.


---

## 15. Now Playing transport · **DONE**

| Part | Design | Was |
|---|---|---|
| Controls in the main row | **3** — previous, play, next | **5** — shuffle, previous, play, next, repeat |
| Row spacing | **34** | `Spacer()` between all five |
| Play button | **78**, **solid `#E8A33D`**, glow `rgba(232,163,61,.35) 0 10px 34px`, no border | 76, translucent 30%→13% wash, white border, black shadow |
| Play glyph | 27 | 26.5 (derived from size) |
| Prev / next glyph | 26 | 27 |
| Shuffle / repeat | secondary row, **21pt, white 66%**, amber when active | in the main row, 19pt, `iconInactive` |

The play button was the clearest error: a translucent amber wash with a white
border reads as a *dimmed* control, where the design has the screen's one bright
disc. Solid fill and an amber glow instead of a black drop shadow.

Shuffle and repeat move out of the transport row. The design does not put them
there — it has a secondary utility row below — so keeping them inline was
crowding the primary controls and flattening the hierarchy.

### Measured on the same screen, not applied

The design's Now Playing is ordered **artwork → elapsed/remaining → title and
artist → transport**, where the build runs **artwork → title and artist →
progress → transport**. It also carries two rows Hum does not have: a **volume
slider**, and a bottom utility row of **queue · AirPlay · shuffle** at 21pt with
56 between them. Hum's queue button sits in the top bar instead.

Repeat is kept, though the design's utility row shows only shuffle — dropping it
would remove a capability `QueueReducer` supports and the Queue screen exposes.


---

## 16. Connect · **DONE** — and mostly already right

The first screen that was **close before the audit touched it**. It was built in
Phase 4 by transcribing the prototype rather than inventing, and it shows:

| Part | Design | Was |
|---|---|---|
| Title | 36 / weight 200 / -0.9 | ✅ already exact |
| Body | 16 / 300 / white 66% | ✅ already exact |
| Permission rows | 15.5 / 300 / white 82% | ✅ already exact |
| Button fill | gradient `#E8A33D` 26% → 12% | ✅ already exact |
| Button height | **58** | 56 |
| Button width | **324** | 322 |
| Button label | **17** / 400 | 16 |
| Footnote | 12.5 / 400 / white **62%** | white 66% |

Four deltas of 2pt, 2pt, 1pt and 4%. That is what a screen built *from* the
design looks like, against screens built from a reading of it — and it is the
strongest argument in this document for transcribing rather than interpreting.

**Note:** `HumFont.button` moved 16 → 17, which Detail's Play and Shuffle
buttons also use. Their height is passed explicitly (50) so only the label size
changed there; those buttons have not been measured against the design yet.


---

## 17. Library grid · **DONE**

The design's Library card is **identical to the Home shelf card** — 160 × 208,
art 160 at radius 10, title 15/400 white, subtitle 13/400 amber 80%. Cards sit at
x = 21 and x = 195, so two columns of 160 with **14** between them.

The app had **duplicated the card inline** in `LibraryView` rather than sharing
one. That duplicate kept the old 14.5 title and grey subtitle after §14 corrected
the original — the two drifted apart precisely because they were two. `ShelfCard`
is now shared, and the grid's adaptive minimum moves 148 → 160.

**A judgement, flagged:** the design's mock shows two fixed 160 cards on a 390
frame, leaving 36 of trailing space rather than centring or filling. Hum uses
`.adaptive(minimum: 160)`, so cards fill the row and grow on a wider screen. That
keeps the measured minimum and gap but not the measured trailing margin, which
reads more like an artefact of the mock than an intention. **If the asymmetry is
deliberate, this is the line to change.**

### Pattern worth naming

Three components have now diverged because the same thing was drawn twice —
Library's card against Home's, and Now Playing's transport against the player
bar's. Where the design draws one component, the build should have one view.


---

## 18. Detail header · **DONE** — the largest divergence found

| Part | Design | Was |
|---|---|---|
| Hero art | **full-bleed, screen width, radius 0** | 342 centred card, radius 10, drop shadow |
| Title | 26 / 300 / -0.4, **centred** | 27 / light / -0.5, **leading** |
| Meta line | **14 / 400, amber 80%** | 12.5 uppercase, tracked, grey |
| Play | **113 × 48, radius 24, solid amber, label 16/500 in Deep Onyx** | full-width capsule, translucent amber wash, **white** label |
| Shuffle | **128 × 50, radius 24, transparent, 1px amber 50% border, amber label** | full-width neutral capsule, white label |

The hero was the structural error — the design runs artwork edge to edge, and
the build framed it as a rounded card floating in a 20pt gutter. The buttons were
the second: the design's Play is a **compact solid amber pill with dark text**,
the strongest affordance on the screen. The build's was a wide translucent wash
with a white label, which is the *Connect* button — reused where it did not
belong.

`DetailActionButton` is therefore its own component rather than another
`AmberCapsuleButton` configuration. That is the same lesson as §17 read from the
other end: **where the design draws two different components, the build should
not share one.**

### Loose end

`HumFont.button` was moved 16 → 17 in §16 for Connect, and Detail's buttons
shared it. They now carry their own 16/500 and 16/400, measured, so that token is
back to serving Connect alone.
