# Hum — Development Plan

**Precondition:** D-01, D-02, D-03 are resolved in [DECISIONS.md](DECISIONS.md). **D-12 — Feed.fm credentials — is still outstanding and is the only thing blocking Phase 1.** Phase 0 can start now.

Seven phases. Each has an exit gate — a demonstrable, checkable state. No phase starts before the previous one's gate passes. Phases 1 and 4 carry the real risk; the ordering exists to hit both early enough that a surprise doesn't invalidate finished UI work.

---

## Phase 0 — Project scaffolding
*No blocking decisions needed. Can start immediately.*

1. Create `HumApp.xcodeproj` — iOS App, SwiftUI, Swift 6 language mode, deployment target iOS 26.0.
2. Turn on **strict concurrency = complete** from day one. Retrofitting it onto a written codebase is materially harder than starting with it.
3. Set `SWIFT_TREAT_WARNINGS_AS_ERRORS` for the app target — the acceptance criterion is "no warnings," so make the build enforce it rather than relying on discipline.
4. Create `Config/{Shared,Debug,Release}.xcconfig` + committed `Shared.xcconfig.example`; add the real ones to `.gitignore`; wire `FeedFMToken` / `FeedFMSecret` into `Info.plist`.
5. Add the `HumTests` unit test target (Swift Testing).
6. Create the directory skeleton from [ARCHITECTURE.md §2](ARCHITECTURE.md).

**Gate:** empty app builds and launches on the iOS 26 simulator, zero warnings.

---

## Phase 1 — Feed.fm spike (de-risk before anything is built on it)
*Blocked on D-12 (credentials). D-02 and D-03 resolved.*

This phase is deliberately throwaway-tolerant. Its job is to answer questions, not to produce polished code.

1. Add the Feed.fm iOS SDK (SPM if offered, otherwise CocoaPods). **This is the only approved dependency.**
2. Confirm it links and initializes against Swift 6 strict concurrency. Expect to need `@preconcurrency import`. Record what was required.
3. Prove the minimum loop headlessly: authenticate → fetch stations → tune → play → hear audio → observe track-change notifications.
4. **Answer D-09:** inspect the SDK for any audio tap / `AVAudioEngine` / metering surface. Write the finding down.
5. Verify skip behaviour and how a denied skip is reported.
6. Confirm background audio + `AVAudioSession` category interaction, and what happens when we pause Feed.fm to play our own ad audio and then resume — this is the exact mechanic the whole ad feature rests on, and it is worth proving on hardware now rather than in Phase 3.

**Gate:** a written spike report answering D-09 and the pause/resume question, plus audible playback on a device. If Feed.fm cannot be made to work here, **stop** — provider change is a Stop Condition.

✅ Progress note format from here on: `✅ [what was done] — [file(s)]`

---

## Phase 2 — Domain, services, and the tested core
*D-01 resolved: bundled creatives. D-04 defaulted: completed tracks only.*

Deliberately **no UI in this phase.** All of it is unit-testable and none of it depends on glass rendering.

1. `Domain/` — `Track`, `Station`, `AdCreative`, `PlaybackState`, `Entitlement`, `PlaybackFailure`.
2. `Domain/AdBreakPolicy.swift` — pure struct.
3. Protocols: `MusicPlaybackService`, `AdService`, `EntitlementService`.
4. `FeedFMPlaybackAdapter` — promote the Phase 1 spike into the real adapter; map `FMAudioItem` → `Track` at the boundary; vend the `AsyncStream<PlaybackEvent>`.
5. `PlaybackCoordinator` — the state machine from [ARCHITECTURE.md §5](ARCHITECTURE.md), including fail-open on ad error.
6. Test fakes for all three services.
7. **`AdBreakPolicyTests` + `PlaybackCoordinatorTests`** — written here, not at the end. These cover one of the two named acceptance criteria for tests.

**Gate:** `swift test` green. Ad-trigger logic proven at N=3 (breaks at 3, 6, 9 — not 3, 4, 5) with zero UI in existence.

---

## Phase 3 — Ad-Break, end to end, headless-ish
*D-01 resolved: bundled creatives in `Resources/Ads/`.*

1. `AdService` conformance per D-01 (bundled creatives by default).
2. Audio session choreography: suspend music → ad owns session → ad ends → resume music. Handle interruptions (call, Siri) *during* an ad.
3. Wire `.adBreak` state to a placeholder full-screen view — unstyled, just proving the transition. Styling is Phase 4.
4. Ensure the ad screen cannot be dismissed by gesture.

**Gate:** on device, three tracks play and an ad audibly interrupts, then music resumes at track four. Repeats at six.

---

## Phase 4 — Design system, glass chrome, and the content screens
*Needs D-09 answered (from Phase 1), D-10.*

The largest phase. Build chrome first, content second — the glass boundary is easier to hold when the chrome already exists as a finished thing you are deliberately *not* extending.

**4a — Foundations**
1. `DesignSystem/Palette.swift` — Deep Onyx `#0A0A0A`, Honey Amber `#E8A33D`, sepia ramp for Ad-Break.
2. `Typography.swift` — SF Pro Display, Light/Thin for headers.
3. `GlassSurface.swift` — **the only file that calls `.glassEffect()`.** Vends `.chromeGlass()` and nothing else.

**4b — Chrome (glass)**
4. `RootTabView` — `TabView` with `Tab(role: .search)` so Search renders as its own circular glass element natively. Do not hand-build the separate capsule.
5. `PlayerBar` — glass capsule, amber tint, `.interactive()`.
6. Wrap tab bar + player bar in a single `GlassEffectContainer`. Two adjacent glass elements outside a shared container is the specific failure Apple's guidance calls out.
7. `glassEffectID` + `@Namespace` for the bar → Now Playing morph. Chrome morphs; content crossfades.

**4c — Content (opaque)**
8. `NowPlayingView` — Liquid Mesh `MeshGradient` background (album colors + amber, 0.5× drift), circular non-spinning album art, bass-reactive glow per D-09 outcome, arc-based progress ring.
9. `AdBreakView` — monochrome sepia, ripple visualizer, waning-moon countdown. **No glass anywhere on this screen**; that's the point of it.
10. `HomeView`, `LibraryView`, `TrackRow` — opaque, per D-02's station model.

**Gate:**
- `grep -rn "glassEffect" Hum/ | grep -v GlassSurface.swift` returns nothing.
- Visual pass on device against the boundary table in [ARCHITECTURE.md §6](ARCHITECTURE.md).
- ≥44×44pt hit targets verified with Accessibility Inspector.

---

## Phase 5 — StoreKit 2 subscription
*D-07 behavior resolved (Duo = Family Sharing, identical features). Real product IDs still needed before shipping; `.storekit` placeholders unblock the work.*

1. `.storekit` configuration file with the Solo/Duo products and subscription group.
2. `StoreKit2EntitlementService` — `Product.products(for:)`, `product.purchase()`, `VerificationResult` unwrapped **properly** (a `.unverified` result is not an entitlement), `Transaction.currentEntitlements` on launch, and a `Transaction.updates` listener task started at app launch and never cancelled — miss that and externally-completed purchases (Ask to Buy, interrupted flows) never land.
3. `PaywallView` + `PaywallViewModel` per D-06.
4. Restore purchases (App Review requires it).
5. Wire `entitlement.suppressesAds` into the coordinator's gate.
6. **`EntitlementGatingTests`** — the second named test criterion.

**Gate:** in the StoreKit test environment — non-subscriber hears ads at N; purchase Solo; ads stop and never return; app relaunch preserves entitlement; restore works from a clean install.

---

## Phase 6 — Accessibility, polish, acceptance sweep
1. **Reduce Transparency on** — walk every screen. Verify SwiftUI's automatic solid fallback is legible with amber-on-onyx. Fix contrast, do not hand-roll a parallel glass path.
2. **Reduce Motion on** — freeze the Liquid Mesh drift and the glow pulse to static.
3. Dynamic Type through the accessibility sizes on the largest text screens.
4. VoiceOver pass — the Ad-Break screen especially needs a sensible announcement and a stated countdown.
5. Zero-warning build check with warnings-as-errors on.
6. Walk the acceptance criteria list explicitly, one by one, recording pass/fail.

**Gate:** every box in the brief's Acceptance Criteria is checked with evidence, or explicitly listed as not-met with a reason.

---

## Phase 7 — Handoff
1. `README.md` — setup, how to supply Feed.fm credentials, how to run StoreKit tests.
2. Spike findings and any defaults taken under silence folded back into `DECISIONS.md` as resolved.
3. Known gaps list.

---

## Risk register

| Risk | Likelihood | Impact | Handled by |
|---|---|---|---|
| Feed.fm SDK fights Swift 6 strict concurrency | **High** | Medium | Phase 1 spike; `@preconcurrency`; adapter containment |
| No audio tap → bass reactivity impossible (D-09) | **High** | Low (cosmetic) | Phase 1 spike; documented fallback |
| Station-only model contradicts the Home/Library brief (D-02) | Resolved | **High** if reversed | Station model chosen; reversal means a provider change |
| No ad inventory source (D-01) | Resolved | High commercially, low technically | Bundled placeholders; `AdService` keeps the swap cheap |
| Pause/resume around ad insertion misbehaves in Feed.fm | Medium | **High** | Proven in Phase 1, before UI exists |
| MeshGradient + glass + blur costs frames on older devices | Medium | Medium | Phase 6 profiling; drift is already 0.5× |
| iOS 26 glass APIs shift in a point release | Low | Medium | All glass funnels through one file |

---

## What this plan deliberately does not include

Per "only make changes directly requested": no analytics, no crash reporting, no onboarding flow, no offline caching, no CarPlay, no widgets, no account system, no server component, no CI pipeline, no localization beyond system defaults. Each is a reasonable thing to want and none was asked for.
