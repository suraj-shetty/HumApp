# Hum — Decisions to clear before implementation

Each entry is either **BLOCKING** (Phase work cannot start without an answer) or **DEFAULTED** (I will proceed with the stated default unless told otherwise). Blocking items are ordered by how much rework a late answer causes.

---

## D-01 — Where does ad audio come from? ✅ RESOLVED

> **Decision: Option A — bundled placeholder creatives.** It is the only option that ships inside the stated dependency constraint. `AdService.nextCreative()` hides the source entirely, so a backend endpoint or an ad network drops in behind the same protocol later without touching the coordinator, the ViewModels, or the tests.
>
> **Accepted consequence:** the subscription removes ads that carry no revenue yet. Picking real inventory is a commercial decision, not an engineering one, and it does not block any phase.

The brief requires "an audio ad after every N tracks," but the constraints say *no dependency beyond the Feed.fm SDK*. Feed.fm licenses music; it does not serve third-party audio ad inventory. So there is no ad source in the currently-approved dependency set.

Three ways out:

| Option | What it means | Cost |
|---|---|---|
| **A. Bundled placeholder creatives** (recommended for v1) | 2–3 house/self-promo MP3s in `Resources/Ads/`. Real inventory is a later, separate decision. | Zero new deps. Ships. Earns no revenue. |
| **B. Your own ad endpoint** | App fetches a creative URL + impression beacon from a backend you own. | Needs a backend that does not exist yet. Still no new SDK. |
| **C. An ad network SDK** (Google AdMob, AdsWizz, Triton) | Real audio ad revenue. | **Violates the dependency constraint** — needs explicit approval, and is a Stop Condition. |

I recommend **A**, with `AdService` shaped so B or C drops in behind the same protocol later — `nextCreative()` already returns an `AdCreative`, and where that creative comes from is invisible to the coordinator.

**Note this matters commercially:** the subscription's value proposition is "remove ads," and option A means there is nothing of monetary value to remove yet. The engineering is identical either way; the business readiness is not.

---

## D-02 — Feed.fm is station-based radio, not on-demand. What do Home and Library become? ✅ RESOLVED

> **Decision: build the station model.** Feed.fm cannot do on-demand, and changing provider is a Stop Condition that was not triggered — so the station reading is the only self-consistent answer available.
>
> - **Discover** = a grid of stations to tune into.
> - **Library** = followed stations + a play-history log.
> - **TrackRow** = display-only. It renders the current track and history; it is **not** a play trigger. `onTap` does not exist on it.
>
> **Reversal cost if you later require on-demand:** high. It means a different provider and a rewrite of the playback adapter, Discover, and Library. Say so now rather than in Phase 4.

This is the decision most likely to cause rework if deferred.

Feed.fm's licensing model is DMCA-compliant simulated radio. Practically:
- You **cannot** let a listener pick and play a specific track on demand.
- You **cannot** show an upcoming queue or let them rewind to a previous track.
- Skips are **rate-limited by the service** and can be denied.
- Content is organized as *stations*, which you tune to.

The brief's screen list ("Home/Discover", "Library", "Track Rows") reads like an on-demand app. Under Feed.fm those screens have to mean something different:

| Screen | On-demand reading (not possible) | Station reading (possible) |
|---|---|---|
| Home / Discover | grid of playable tracks/albums | grid of **stations** to tune into |
| Library | your saved tracks, tap to play | your **followed stations** + a **play history** log (display-only, not replayable) |
| Track Rows | tap to play that track | now-playing + history rows, **not tappable-to-play** |

**Recommendation:** build the station reading, and rename in the UI accordingly (Discover = stations, Library = followed stations + history). Track Rows still exist as a component — they render history and the current track — they just aren't play triggers.

If on-demand playback is a hard product requirement, Feed.fm is the wrong provider and that is a Stop Condition (provider change). Please confirm which.

---

## D-03 — Client secret in the shipped binary: accepted? ✅ RESOLVED

> **Decision: accept client-side credentials.** Feed.fm's token/secret pair is designed to live in the client; a token-broker backend is new scope, needs a server that does not exist, and buys little against a vendor model that assumes client-side keys. xcconfig satisfies the actual stated requirement — not hardcoded, not in version control.
>
> Recorded as a conscious acceptance: **the pair is extractable from a shipped IPA.**

Feed.fm authenticates with a client token + secret pair. The xcconfig approach satisfies "never hardcoded / not in version control." It does **not** prevent extraction from a distributed IPA — no client-side scheme does.

This is normal for Feed.fm (their model assumes a client-side pair), but I want it acknowledged rather than assumed. Confirm: **accept client-side credentials**, or **require a token-broker backend** (which is new scope and a backend that does not exist).

---

## D-04 — Does a skipped track count toward N? **DEFAULTED**

If skips count, a listener can speed-run to an ad break in seconds. If they don't, a serial skipper never hears an ad.

**Default:** only *completed* tracks count (`countsSkippedTracks = false`). It's the listener-friendlier reading and it makes the `trackDidComplete` / `trackWasSkipped` event split in `PlaybackEvent` meaningful. Flag if you want skips counted — it's a one-line policy change plus test cases either way.

---

## D-05 — Skip-denied UX **DEFAULTED**

Feed.fm will deny skips past the licensing limit. **Default:** the skip button stays enabled, and a denial surfaces as a brief inline message on the Now Playing screen ("Skip limit reached"). Alternative is disabling the button preemptively, which requires polling remaining-skip state and tends to look broken.

---

## D-06 — Paywall: custom view or StoreKit 2's `SubscriptionStoreView`? **DEFAULTED**

`SubscriptionStoreView` gives you a compliant, localized, auto-updating paywall almost free, and handles tier comparison. But it is heavily system-styled and will fight the Amber Glow art direction.

**Default:** custom `PaywallView` over Deep Onyx (opaque content), driving `Product.purchase()` directly, because the brief specifies a designed visual system. Say the word if you'd rather trade the art direction for the system view's compliance guarantees.

---

## D-07 — What actually differs between Solo and Duo? ⚠️ DEFAULTED (still needs your product IDs)

> **Decision on behavior: Duo = Family Sharing enabled, identical features, higher price.** This is the standard shape and it keeps app logic simple — `Transaction.currentEntitlements` treats both tiers identically for ad suppression, so the tier affects billing only. Phase 5 does not branch on tier.
>
> **Still needed from you:** the real product IDs and subscription group ID from App Store Connect. I will scaffold `.storekit` placeholders (`com.hum.sub.solo.monthly`, `com.hum.sub.duo.monthly`, group `hum_premium`) so Phase 5 can proceed and be tested; you reconcile before any real build.

The brief names two tiers but not what separates them. Both are described as doing the same thing (remove ads). Options: Duo = Family Sharing enabled (2 people), Duo = higher price with identical features, Duo = additional feature not yet specified.

I also need the **product IDs** and the **subscription group ID** you'll create in App Store Connect, or I'll invent placeholders in a `.storekit` test file and you'll have to reconcile them later.

Note: if the only difference is Family Sharing, `Transaction.currentEntitlements` treats both identically for ad suppression — the tier affects billing, not app logic. That's fine and simplifies Phase 5.

---

## D-08 — Purchase completing *during* an ad **DEFAULTED**

**Default:** the in-flight ad finishes, then ad suppression takes effect from the next track boundary. Killing audio mid-ad on purchase is jarring and creates a messy audio-session teardown. Easy to change if you'd rather reward the purchase instantly.

---

## D-09 — Bass-reactive album art glow: is there a signal to react to? **BLOCKING for Phase 4**

The brief specifies "bass-reactive glow shadow." That needs amplitude/FFT data from the audio graph. Feed.fm's SDK plays through its own internal `AVPlayer`; **it is not documented to expose an audio tap or an `AVAudioEngine` node**, and I could not verify otherwise without SDK access.

If no tap is available, the options are:
- **A.** Simulated reactivity — drive the glow from the track's BPM/tempo metadata or a fixed pleasing pulse. Looks good, isn't truly reactive. *(recommended fallback)*
- **B.** Drop the reactivity, keep a static amber glow.
- **C.** Route Feed.fm's output through a custom audio graph — likely not possible without SDK support, and may violate their playback terms.

Phase 1 includes an explicit spike to answer this. **Default if the spike says no tap: option A**, and I'll flag it in the progress log rather than silently shipping a fake.

---

## D-10 — Album-color extraction for the Liquid Mesh background **DEFAULTED**

"Album colors + amber" requires sampling the artwork. **Default:** downsample the artwork to a small bitmap on a background task and take 2–3 dominant colors, blended toward Honey Amber, feeding a SwiftUI `MeshGradient`. No new dependency. Cached per track. Falls back to Deep Onyx + amber when artwork is missing or slow.

---

## D-11 — Persistence for Library **DEFAULTED**

The constraint says "do not modify any data model beyond local playback/subscription state." **Default:** followed stations and play history persist to a small local store (SwiftData, in the SDK, no new dependency) as local playback state only. No account, no sync, no server. Confirm this reads as in-scope to you — if Library should be purely in-memory for v1, that's simpler still.

---

## D-12 — Feed.fm credentials & account availability 🚫 STILL BLOCKING — I cannot answer this one

> This is the one decision that is not mine to make on the merits. Phase 1 needs a real Feed.fm client token + secret (trial credentials are fine) from an account only you can create at feed.fm. Nothing substitutes for it: without credentials there is no authentication handshake, no station list, and no audio, so the Phase 1 spike — which also answers D-09 — cannot run.
>
> Phase 0 does not need it and can start now.

Phase 1 cannot start without a Feed.fm token/secret (their trial credentials are fine). Everything before that is project scaffolding only.

---

## Summary — current state

| | |
|---|---|
| ✅ **Resolved** | D-01 (bundled ads), D-02 (station model), D-03 (client-side secret accepted) |
| ⚠️ **Defaulted, proceeding** | D-04, D-05, D-06, D-07 (behavior), D-08, D-10, D-11 |
| ⏳ **Answered by the Phase 1 spike** | D-09 (audio tap for bass reactivity) |
| 🚫 **Still blocking** | **D-12 — Feed.fm credentials.** Only you can supply these. |
| 📋 **Needed before Phase 5 ships** | D-07 real product IDs from App Store Connect |

Every resolved and defaulted decision above is one sentence away from being overridden — none of them are expensive to reverse except D-02, which is flagged in place.

**Phase 0 can start now.** Phase 1 starts the moment D-12 lands.
