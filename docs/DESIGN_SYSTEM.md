# Hum — "Amber Glow" Design System

> **Incomplete pending design import.** This is reconstructed from the written brief only. The Claude Design project (`Hum.dc.html`, `image-slot.js`, `ios-frame.jsx`, `support.js`) could not be read — see [the blocker note](#blocker). Spacing scale, component geometry, exact type ramp, and Ad-Break sepia values are **assumed** below and must be reconciled against the design source before Phase 4.

---

## 1. Color

| Token | Value | Role |
|---|---|---|
| `deepOnyx` | `#0A0A0A` | Content base. Every opaque surface starts here. |
| `honeyAmber` | `#E8A33D` | Glass tint + accent. Primary interactive color. |
| `sepia*` | *not specified* | Ad-Break monochrome ramp — **needs values from design source** |

Amber is used two different ways and the distinction matters: as a **tint** on chrome glass (`.regular.tint(.honeyAmber)`, where the system desaturates and modulates it against what's behind), and as a **solid accent** on content (progress arc, active states), where it renders at full strength. They will not look identical, and that is correct.

**Contrast:** `#E8A33D` on `#0A0A0A` is a high-contrast pairing and passes comfortably for body text. Amber-on-amber and amber-on-mesh-gradient are the risk cases — the Liquid Mesh background is variable by album, so the progress arc and any text over it need a verified minimum against the *lightest* possible mesh state, not the average one. Phase 6 checks this.

---

## 2. Typography

SF Pro Display. Light and Thin weights for headers, per brief.

| Role | Weight | Notes |
|---|---|---|
| Display / Now Playing title | Light or Thin | Thin at small sizes will fail contrast — cap Thin to large display sizes only |
| Section headers | Light | |
| Body / track rows | Regular | Not specified in brief; Light body at list sizes is a legibility risk |
| Labels / metadata | Regular | |

All type scales with Dynamic Type. Thin weights degrade badly at accessibility sizes — the plan is to step weight up as size increases rather than let Thin stretch to 60pt.

---

## 3. The glass / opaque split

This is the load-bearing rule of the whole system, restated from [ARCHITECTURE.md §6](ARCHITECTURE.md#6-liquid-glass-boundary--normative):

**Glass (chrome only):** Tab Bar · Player Bar · toolbars · sheet chrome
**Opaque (everything else):** Now Playing background & art & progress · Ad-Break (entirely) · lists & track rows · paywall body

Enforced mechanically: `.glassEffect()` may only be called inside `DesignSystem/GlassSurface.swift`.

Rationale, so it survives future contributors: Apple's iOS 26 guidance treats Liquid Glass as a material for the floating navigation layer. Glass on glass compounds refraction into mud; glass over dense or colorful content (album art, a mesh gradient) destroys the content's legibility and the glass's own read. The Ad-Break screen is opaque *on purpose* — its whole job is to feel like a different context, and matching the chrome material would undercut that.

---

## 4. Component specs

### Tab Bar
Inset horizontal glass capsule. **Search is a separate circular glass element**, not merged into the main capsule — achieved with SwiftUI's `Tab(role: .search)`, which the system renders this way natively on iOS 26. Do not hand-build a second capsule; the native role also carries the correct accessibility semantics and the scroll-minimize behaviour.

### Player Bar (mini)
- `.glassEffect(.regular.tint(.honeyAmber).interactive(), in: .capsule)`
- Shares a `GlassEffectContainer` with the tab bar (adjacent glass **must** share a container).
- Carries `.glassEffectID(PlayerGlassID.bar, in: namespace)` for the morph.
- Content: artwork thumb, title/artist, play-pause. All targets ≥44×44pt.

### Player Bar → Now Playing morph
Shared `@Namespace` + `glassEffectID` so the bar's chrome geometry morphs into the expanded sheet's chrome. **Chrome morphs; content crossfades independently.** Dragging opaque content through a glass morph produces exactly the stacking artifact this system exists to avoid.

### Now Playing (all opaque)
- **Liquid Mesh background** — SwiftUI `MeshGradient` seeded from 2–3 dominant album-artwork colors blended toward Honey Amber, drifting at **0.5× speed**. Frozen static under Reduce Motion.
- **Album art** — circular, **non-spinning**, with a bass-reactive glow shadow. *Reactivity is contingent on D-09* — if the Feed.fm SDK exposes no audio tap, this falls back to a tempo-driven or static pulse, and that substitution gets stated plainly rather than passed off as reactive.
- **Progress** — arc-based ring, **not a line**. Amber stroke on the mesh.
- Transport controls sit on the mesh as opaque symbol buttons.

### Ad-Break (all opaque, deliberately non-glass)
- Monochrome **sepia** field. *(Values needed from design source.)*
- **Ripple visualizer.**
- **Waning-moon countdown** — the moon wanes as the ad elapses.
- Not dismissible by gesture. VoiceOver announces the context and the remaining time.

### Track Row (opaque)
Artwork thumb, title, artist, duration. **Display-only** — D-02 resolved to the station model, so rows render the current track and history and are not play triggers. They should not present affordances (chevrons, play glyphs) that imply tappability.

---

## 5. Accessibility

| Setting | Behavior |
|---|---|
| **Reduce Transparency** | SwiftUI substitutes a solid material for `.glassEffect` automatically. **Verify on device; do not hand-roll a parallel path.** The work is confirming amber-on-solid stays legible, not rebuilding the surface. |
| **Reduce Motion** | Freeze Liquid Mesh drift and the album-art glow pulse. This is *content-layer* motion and SwiftUI will not handle it for you — it needs an explicit branch. |
| **Dynamic Type** | Full support. Step header weight up as size increases; Thin does not survive accessibility sizes. |
| **Touch targets** | ≥44×44pt everywhere, verified with Accessibility Inspector. |
| **VoiceOver** | Ad-Break needs a deliberate announcement — a decorative ripple and a moon glyph convey nothing without labels. |

Reduce Transparency and Reduce Motion are **separate settings**. A listener may enable either alone. Both paths need checking independently.

---

## 6. Blocker

The Claude Design MCP could not authorize in this session:

> DesignSync needs design-system authorization, and `/design-login` cannot run in this non-interactive session.

To unblock, run once from an interactive Claude Code terminal on this machine:

```bash
/design-login
```

Then the project at `46b4b0ca-fcb3-4ecb-ad50-1954beaf3ac7` becomes readable and this document can be reconciled against `Hum.dc.html` and its imports. Nothing in Phases 0–3 depends on it; **Phase 4 does.**

### What the import is expected to settle
- [ ] Spacing scale and layout grid
- [ ] Exact type ramp — sizes, weights, line heights
- [ ] Sepia ramp values for Ad-Break
- [ ] Ripple visualizer and waning-moon geometry
- [ ] Corner radii, capsule proportions, player bar height
- [ ] Icon set
- [ ] Whether `image-slot.js` / `ios-frame.jsx` imply artwork aspect/placeholder rules
- [ ] Any states in the design not named in the brief (empty, loading, error, offline)
