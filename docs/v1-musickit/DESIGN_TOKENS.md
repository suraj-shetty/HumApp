# Design tokens — the written-down set

**Phase 7, step 1.** Written *before* touching code, so the screen-by-screen diff has something to be measured against.

**Method:** the bundle is JavaScript-driven — the markup in `designs/Hum-All-Platforms.html` is inert until rendered — so every number here was read from **computed styles on the rendered page**, not from the design's prose. Where the two disagree the measurement wins. This is the correction from the Phase 6 audit, which read prose and produced a wrong change.

Served with `python3 -m http.server` from `designs/`, measured via the browser's computed styles.

---

## Palette — authoritative, five named colours

| Token | Hex | Design's own role label | In `Palette.swift` |
|---|---|---|---|
| Deep Onyx | `#0A0A0A` | content ground | ✅ `deepOnyx` |
| Honey Amber | `#E8A33D` | accent | ✅ `honeyAmber` |
| Terracotta | `#D2714A` | **error** | ✅ `terracotta` |
| Slate 900 | `#1E1E20` | art plate | ✅ `artworkFill` |
| Amber Glass | — | chrome tint **only** | ✅ `amberGlassTint` |

> **Correction to DEVELOPMENT_PLAN.md.** Phase 7's step 1 recorded this token as `warning #D2714A`. The design labels it **error**. The distinction matters for the open swipe-action finding: an error colour on a destructive action is straightforwardly right, where a warning colour would have been a compromise.

Reduce Transparency substitute: **`#1C1A17` at 96%**, amber ring kept as the only edge. Note `Palette.surfaceRaised` is `#1C1A18` — one digit off the fallback's `#1C1A17`. One of the two is a typo; resolve in step 2.

---

## Type — SF Pro Display. Nothing below 11pt.

Thin/Light for headers, Regular for content.

| Design sample | Measured | Nearest token | Match |
|---|---|---|---|
| section header "Recently played" | 40 / 200 / -1.0 | `screenTitle` 32/200/-0.8 | scale sample, not a token |
| Title | 26 / **300** / -0.4 | `titleM` 26/light/-0.4 | ✅ |
| Body — track titles | 16 / **400** | `rowTitle` 16/regular | ✅ |
| Caption — artist | 13.5 / 400, **amber 80%** | `rowSubtitle` + `honeyAmber.opacity(0.8)` | ✅ |
| Overline | 11 / 400, tracking **1.6**, uppercase, white 62% | `overline` 11, tracking **1.4** | ⚠️ tracking short by 0.2 |
| Wordmark | 600, tracking −2.5 at 88px, `ui-rounded`, amber | `wordmark` 30/semibold/rounded/−0.8 | ✅ weight confirmed 600 |

⚠️ `bodyL` is 16/**light** while the design's 16pt body is **regular**. `rowTitle` (regular) is what track rows use, so this may be a token used only off the body ramp — check its call sites in step 2 before changing it.

**Minimum body ink: white at 62%** (≥4.5:1 on Deep Onyx). Amber on onyx is 8.9:1. Disabled controls are the only text permitted below 62%.

---

## Chrome geometry — measured, not quoted

| Element | Measured | Implemented |
|---|---|---|
| Player capsule | **362 × 64, radius 26** | — |
| Tab capsule | **288 × 64, radius 28** | — |
| Toast | 390 × 47, radius 26 | — |
| Glass fill | `blur(26px) saturate(1.8)`, border `1px rgba(255,255,255,0.16)` | ✅ `glassHairline` = white 16% |
| Safe inset | 14pt · dock bottom 22pt | — |
| Gap capsule → island | 10pt | — |
| Search island | 64 × 64 circle | — |
| Selection pill | 50pt tall, radius 25 | — |
| Sheet | corner radius 38pt, grabber 38 × 5 | — |

> **This settles the logged tab-bar divergence.** The player capsule is **362** wide and the tab capsule **288** — measured, on two separate elements, at different radii (26 vs 28). The design does **not** want them the same width. The reported behaviour, the tab bar expanding to match the accessory above it, is therefore a real divergence and not the design's intent.
>
> Whether it is *fixable* is a separate question: on iOS 26 `tabViewBottomAccessory` and the tab bar share a system-owned container, and matching the design may require hand-building the tab bar, which the brief forbids. Record the divergence; do not hand-roll the bar to close it.

---

## Action hierarchy — one rule per tier

| Tier | Treatment |
|---|---|
| Full-screen state, **primary** | glass capsule 322 × 56, radius 28, amber tint .26 → .12 |
| Full-screen state, **secondary** | plain 16pt label at 66% white, 52pt tall, no border |
| **On content** (detail headers) | solid amber fill, onyx label, 48pt tall |
| **Inline** empty / error | amber outline pill, 48pt, radius 24 |
| **Inside a card** | amber outline pill, 44pt, radius 22 |

State rings: 112pt full-screen, 96pt inline; amber at 35%, terracotta at 38%.

Applies to Onboarding, Connect, Not Subscribed, Denied, Track Unavailable, full error.

---

## Glass discipline

- Glass lives on **chrome**: dock, toolbars, sheets, toasts.
- Content — lists, art, Now Playing, empty states — stays **opaque onyx**.
- Adjacent glass merges; **search is its own island**.

Enforced already as a build error by `Scripts/check-containment.sh`.

---

## Motion

| | |
|---|---|
| Content | spring, response 0.42, damping 0.82 |
| Chrome | system glass morph — **do not re-time it** |
| Player capsule → Now Playing | matched geometry on the artwork, square 40pt → circle 262pt |
| Toasts | 0.25s in, hold 3s, 0.2s out |
| Pull-to-refresh ripples | 2.2s loop, 3 rings, 0.73s stagger |
| Reduce Motion | every spring → 0.2s cross-fade; ripple freezes at one ring |

---

## Accessibility contract

- Every control ships a **44 × 44pt** hit area. Filter chips are 38pt tall with 3pt slop; the search clear glyph is 18pt inside a 44pt target.
- VoiceOver: the player capsule is **one element** — "Now playing, Slow Weather, Neela Vance" — with play and skip as **separate actions**.

---

## Already-stale finding

**"The destructive swipe action renders in Honey Amber"** (PROGRESS.md, open finding 0) is **no longer true**: `QueueView.swift:151` already tints `Palette.terracotta`. With the design labelling terracotta *error*, this is now correct by the design's own rule and the finding can close without a decision.
