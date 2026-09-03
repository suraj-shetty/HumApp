# Hum — "Amber Glow" Design System

**Reconciled against `designs/Hum Prototype.html`** — the design source the previous version of this document was blocked on is now readable, and every value below is extracted from it rather than assumed.
**Supersedes** [`docs/DESIGN_SYSTEM.md`](../DESIGN_SYSTEM.md).

---

## 1. Color — extracted

| Token | Value | Role |
|---|---|---|
| `deepOnyx` | `#0A0A0A` | Device/content base |
| `boardBackground` | `#121214` | Prototype board only — **not an app color** |
| `honeyAmber` | `#E8A33D` | Accent, artist names, active tint, progress fill, logo |
| `honeyAmberHover` | `#F2B75C` | Link/pressed lift |
| `surfaceRaised` | `#1C1A18` | Avatar chip, raised circles |
| `artworkPlaceholderA` | `#16151A` / `#15141A` | Artwork slot fill |
| `artworkGradient` | `linear(145°, #26241F → #16151A)` | Track-row art placeholder |
| `artworkGradientWarm` | `linear(145°, #332E26 → #17161B)` | Player-bar art placeholder |
| `hairline` | `rgba(255,255,255,.07)` | Row dividers, artwork borders |
| `hairlineStrong` | `rgba(255,255,255,.09)` | Section rules |

**Text ramp** (white at opacity — one scale, used consistently throughout the prototype):

| Token | Value | Used for |
|---|---|---|
| `textPrimary` | `#FFFFFF` | Titles, track names |
| `textSecondary` | `rgba(255,255,255,.66)` | Body copy |
| `textMuted` | `rgba(255,255,255,.62)` | Durations, timecodes, tracked overlines, captions, metadata |
| `iconInactive` | `rgba(255,255,255,.60)` | Inactive tab, inactive shuffle/repeat |

**Amber alphas** (the accent is used at four strengths, deliberately):

| Context | Value |
|---|---|
| Ambient wash — Connect | `radial(70% 45% at 50% 30%, rgba(232,163,61,.13), transparent 70%)` |
| Ambient wash — Now Playing portrait | `radial(78% 50% at 50% 26%, rgba(232,163,61,.16), transparent 72%)` |
| Ambient wash — Now Playing landscape | `radial(60% 90% at 22% 50%, rgba(232,163,61,.16), transparent 72%)` |
| Primary button fill | `linear(180°, rgba(232,163,61,.26) → rgba(232,163,61,.12))` |
| Play button fill (76pt) | `linear(180°, rgba(232,163,61,.30) → rgba(232,163,61,.13))` |
| Secondary/outline button | `rgba(232,163,61,.16)` fill, `rgba(232,163,61,.40)` border |

**Contrast:** `#E8A33D` on `#0A0A0A` measures **9.18:1** — passes AA and AAA. `textMuted` on the same ground is `#A2A2A2`, **7.76:1** — also passes both.

The ramp previously carried a `textTertiary` at 52% and a `textQuaternary` at 40%. Both were removed: neither value appears in the design (52% occurs zero times in the prototype, 40% once), and the 40% step measured 3.77:1, failing AA on every duration in the app. `textMuted` is the design's actual value for that role.

The remaining contrast risk is amber text over the brightest part of the radial wash — still owed a check, since it depends on the album artwork.

---

## 2. Typography — extracted

The prototype uses **two families**, which the earlier doc did not capture:

| Family | Where | SwiftUI |
|---|---|---|
| **SF Pro Rounded**, Semibold (600) | The `hum,` wordmark only — 30–32pt, `letter-spacing: -.8px` | `.system(size:32, weight:.semibold, design:.rounded)` |
| **SF Pro Display** | Everything else | `.system(design: .default)` |

Weights run **light**: the prototype's heaviest non-wordmark weight is 400.

| Role | Size | Weight | Tracking | Example |
|---|---|---|---|---|
| Display | 36 | 200 (Ultra Light) | −0.9 | "Connect / Apple Music" |
| Title L | 30 | 300 | −0.5 | Landscape now-playing title |
| Title M | 27 | 300 | −0.5 | Album title |
| Title S | 23 | 400 | −0.3 | Now Playing track title |
| Body L | 16–17 | 300 | 0 | Connect body, buttons |
| Row title | 15.5 | 400 | 0 | Track rows |
| Row subtitle | 13.5 | 400 | 0 | Artist |
| Caption | 12.5–13 | 400 | 0 | Durations, timestamps |
| **Overline** | 11–13 | 400 | **+1.4 to +1.8**, UPPERCASE | "RECENTLY PLAYED", "UP NEXT", "PLAYING NOW" |
| Tab label | 10.5 | 400 | +0.6 | Home / Search / Library |

The uppercase-wide overline is the system's most distinctive typographic move — it appears on every screen and should be a single reusable modifier, not re-specified per site.

**Dynamic Type:** weight 200 at 36pt is the fragile case. Step weight **up** as size grows (200 → 300 → 400 across the accessibility sizes) rather than letting Ultra Light stretch. The 10.5pt tab labels and 11pt overlines need a floor — they are already near the legibility limit at default size.

---

## 3. Spacing & geometry — extracted

| Token | Value | Notes |
|---|---|---|
| Screen gutter | **24pt** | Universal. Detail/Now Playing use **34pt** for hero content. |
| Nav gutter | 18pt | Back/overflow rows sit wider than body content |
| Status bar inset | 54pt | Content begins below |
| Tab bar height | **92pt** (12pt top pad) | |
| Player bar | **64pt tall, 32pt radius**, inset 20pt, **bottom: 104pt** (sits above the tab bar) | |
| Bottom scroll padding | **190pt** | Clears player bar + tab bar |
| Row vertical padding | 11pt (home) / 12pt (queue) / 13pt (album) | |
| Row gap | 14–16pt | |

**Corner radii:** artwork 10–14 · track-row thumb 7 · queue/player thumb 8 · player-bar thumb 23 (circular) · buttons fully rounded (capsule) · avatar 22 (circular).

**Artwork sizes:** shelf card 148 · detail hero 342 · now-playing 322 · queue/expanded 56/52 · track row 52 · player bar 46.

**Tap targets:** the prototype already respects 44×44 — every icon button is `min-width:44px; height:44px`, transport prev/next are 52, play is 76. Carry these through verbatim; the criterion is met by construction, not by retrofit.

---

## 4. Motion — extracted

| Name | Prototype | SwiftUI |
|---|---|---|
| `humRise` | `opacity 0→1, translateY 14px→0`, 0.30–0.34s ease-out | `.transition(.opacity.combined(with: .offset(y: 14)))`, `.easeOut(duration: 0.32)` |
| `humSpin` | 1s linear infinite — Connect spinner | `ProgressView` or rotation |
| `humBar` | `scaleY .35↔1`, 1s ease-in-out, staggered **0.22s** across 3 bars — the "playing now" level meter | 3 bars, `.repeatForever(autoreverses: true)`, phase-offset |
| Press | `scale(.98)` buttons / `scale(.94–.96)` transport | `.scaleEffect` on `isPressed` |

**Reduce Motion:** freeze `humBar` flat (the Dynamic Island note in the prototype already says "amber bars freeze flat when paused" — the same static state serves both cases), and drop `humRise` to a plain crossfade. This is content-layer motion; SwiftUI will not handle it automatically.

---

## 5. Components

### Tab bar — 3 tabs
Home · Search · Library. Active = `#E8A33D`, inactive = `rgba(255,255,255,.6)`. Built with native `TabView`; **Search uses `Tab(role: .search)`** so iOS 26 renders it as its own element with correct accessibility semantics and scroll-minimize behaviour. Glass. Do not hand-build.

> **Note:** the prototype's Library tab navigates to Album Detail, because it's a click-through demo. Library is a real screen in the build.

### Player bar (glass)
64×full-width-minus-40, 32pt radius, at `bottom: 104`. Artwork 46 circular · title 14.5 · artist 12.5 · play/pause 44 · next 44. Shares a `GlassEffectContainer` with the tab bar — two adjacent glass elements outside a shared container is the specific failure Apple's guidance names. Carries `.glassEffectID` for the morph into Now Playing.

Visible only when something is loaded — prototype: `(screen is home|album) && (playing || pos > 0)`.

### Now Playing (opaque)
Portrait, from the top: chevron-down close (44) · source overline · queue button (44) → artwork 322 at 34pt gutter, radius 14, `shadow 0 26 60 rgba(0,0,0,.6)` → title 23/400 + artist 17 amber, with the add-to-library button right-aligned ([M-04](DECISIONS.md#m-04) — the prototype draws a heart; MusicKit has no love API) → **linear** progress bar, 5pt tall, 3pt radius, amber fill on `rgba(255,255,255,.14)`, with elapsed / −remaining beneath → transport row: shuffle 44 · prev 52 · **play 76 (opaque amber gradient, see [M-07](DECISIONS.md#m-07))** · next 52 · repeat 44 → footer: AirPlay · "UP NEXT · n" · share.

> The progress indicator is a **linear bar**, not the arc ring the superseded doc described. The prototype is the source of truth.

**Landscape** is fully drawn and is a real layout, not a stretch: 56pt left rail (close / vertical source label / queue) · 322pt artwork · right column with metadata, progress, and a left-aligned transport row.

### Album / Playlist detail (opaque)
Back-to-Home (amber, with label) + overflow → 342pt hero artwork → title 27/300, artist 16 amber, meta overline → **Play** and **Shuffle** side by side, 50pt tall, capsule (Play = amber gradient, Shuffle = `rgba(255,255,255,.07)`) → numbered track list. The currently-playing row turns **both its number and title amber** — that's the only selection affordance, no separate indicator.

### Queue (opaque)
Back-to-Now-Playing (amber) + Clear → "Playing now" header card with the animated 3-bar amber level meter → "UP NEXT" overline with source on the right → rows with a leading drag handle, tappable title block (`jump`), trailing × (`remove`) → **empty state** (drawn, and reusable): 34pt amber outline glyph, 19pt/300 headline, 14.5pt body capped at 250pt width, then a 46pt outline capsule action.

### Track row (opaque)
Two variants: **home/queue** (artwork thumb + title/artist + duration) and **album** (index number + title/artist + duration). Divider `rgba(255,255,255,.07)` under every row. Hover/press `rgba(255,255,255,.03)`.

Unlike the superseded Feed.fm plan, **rows here are play triggers** — MusicKit supports on-demand playback, so `onTap` exists and starts the collection at that index.

---

## 6. Screens with no design — flagged, not silently invented

The prototype covers Connect · Home · Album Detail · Now Playing (portrait + landscape) · Queue. It does **not** cover, and these will be built by inference from the idioms above (see [M-06](DECISIONS.md#m-06)):

- **Search** — `.searchable` + home-style result rows
- **Playlist detail** — album layout, different meta line
- **Artist detail** — lowest confidence; header + top songs + album grid
- **Settings** — grouped list: auth status, subscription status, version, revoke-access link
- **Auth `denied` / `restricted` states** — Connect layout, different copy and action
- **Subscription-gap state** — Connect layout, action = Apple's offer sheet
- **Home empty states** — new accounts have no recently-played and no recommendations; derived from the Queue empty state, which *is* drawn

Each will be marked *designed-by-inference* in the progress log rather than presented as design-matched.

---

## 7. Accessibility

| Setting | Behaviour |
|---|---|
| **Reduce Transparency** | SwiftUI substitutes solid material for `.glassEffect` automatically. Verify amber-on-solid legibility for the tab bar and player bar; do not hand-roll a parallel path. |
| **Reduce Motion** | Explicit branch: freeze `humBar` flat, `humRise` → crossfade. Content-layer motion is not handled for you. |
| **Dynamic Type** | Full support. Step weight up as size increases; 200-weight and the 10.5pt tab labels are the failure cases. |
| **Touch targets** | ≥44×44 throughout — already true in the prototype's geometry. Verify with Accessibility Inspector. |
| **VoiceOver** | The animated level meter is decorative → `.accessibilityHidden(true)`. Progress bar needs a value + a seek action. The queue's drag handle and × need labels. Artwork needs the album name, not "image". |
