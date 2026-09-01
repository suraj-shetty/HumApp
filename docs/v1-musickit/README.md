# Hum v1 — MusicKit plan

Planning only. No implementation exists yet.

**This set supersedes `docs/*.md`**, which plans a different app — Feed.fm streaming, an ad-break state machine, and a StoreKit subscription paywall, all three explicitly forbidden by the current brief. Nothing has been deleted; see [M-03](DECISIONS.md#m-03).

Read in this order:

1. **[DECISIONS.md](DECISIONS.md)** — 12 decisions, **all resolved or defaulted**; M-10 deferred. Start here.
2. **[ARCHITECTURE.md](ARCHITECTURE.md)** — layering, the MVVM + reducer choice, concurrency, the three tested reducers, glass boundary, compliance map.
3. **[DEVELOPMENT_PLAN.md](DEVELOPMENT_PLAN.md)** — seven phases with exit gates, plus the risk register.
4. **[DESIGN_SYSTEM.md](DESIGN_SYSTEM.md)** — Amber Glow, **fully reconciled** against `designs/Hum Prototype.html`.

**Blocking decisions: none open.** M-01 (no TCA package), M-02 (no preview engine), M-04 (Add to Library) are resolved. M-10 (bundle ID + MusicKit capability) is deferred and gates every device-validated phase.
