# Board 03 revision prompt — for the Claude Design tool

Written 2026-09-04, after reading Board 03 ("03-iPad-and-Watch-Screens") for the
first time — see `design-audit/HUM_AUDIT.md`'s status update for how it was
found (embedded, gzip-compressed, inside `Hum-All-Platforms.html`'s asset map)
and the full reasoning behind each item below. Not yet run against the design
tool; nothing in Board 03 has been changed. Paste the prompt below into the
Claude Design tool to revise Board 03 in place.

---

```
Update Board 03 ("03-iPad-and-Watch-Screens") inside the existing hum, design system. Keep every convention already established in this file — same tokens, same component patterns, same authority rules (Board 01 wins on visual values, Board 02 on behaviour, Board 03 inherits every law from 01). Do not touch Board 01 or Board 02. Do not introduce a new visual language, new fonts, or new colours — reuse #0A0A0A ground / #0D0C0E content-surface / #E8A33D accent / #D2714A warning, SF Pro Display at 200/300/400, ui-monospace for timecodes, 44pt minimum targets.

This is a revision pass, not a redraw: Board 03 was designed before several capabilities were confirmed real or confirmed impossible against the actual MusicKit framework. Bring it in line with what's now known.

═══ FIX — remove or correct these ═══

1. iPad First Run (Section 02): remove "Connect Spotify" entirely. Hum is Apple-Music-only by design — no second content provider exists or will exist. Redraw the button row as ONE primary "Connect Apple Music" CTA, sized and centred as a single option (not half of a pair), with "Browse what's already on this iPad" kept as the real secondary action beneath it, unchanged.

2. iPad player column (Section 01, right column) and Watch Now Playing (Section 03): remove the heart/love toggle. MusicKit has no love/favorite API — this was already discovered and fixed on iPhone, where the same affordance is titled "Add to Library" with a plus/checkmark glyph, not a heart. Match that exactly: same icon language, same label logic, so iPad/Watch/iPhone read as one product.

═══ ADD — bring these already-shipped iPhone capabilities into the iPad layout ═══

3. Search (middle column): add filter chips for "All / Songs / Albums" above the results, matching the chip visual already used elsewhere in this file (pill shape, amber-16%-fill-plus-border when selected). The current "scope chips" placeholder should resolve to this specific set — Hum's catalog search returns songs and albums only, no third type.

4. Now Playing (player column): add the read-only audio-format badge already shipped on iPhone — a small bordered capsule under the artist name naming what's actually playing (e.g. "LOSSLESS", "DOLBY ATMOS"), blank for ordinary lossy playback so it never reads as an apology. This is real and read-only (MusicKit reports it, doesn't let you choose it) — do not draw it as a selectable quality picker.

5. Loading and error states, once per middle-column view (Grid, Album, Artist, Playlist, Search): each needs its own loading placeholder (shimmering skeleton, matching the amber-on-dark sweep already defined) and its own error state (terracotta #D2714A icon halo, headline, retry action) — the same recipe already established for iPhone's equivalent screens, redrawn at this column's width. Currently none of the six middle-column views have a defined loading or error state.

6. Player-column states for real playback failure modes, since this column is now permanent (not a rising sheet that can be replaced by a full-screen takeover):
   - Buffering: the progress ring/scrub area shows a spinning partial arc with a "BUFFERING" label, transport dimmed ~55% and disabled — same as iPhone, redrawn for this column's proportions.
   - Connection lost: iPhone shows this as a full-screen takeover, which doesn't fit a permanent side column. Design an in-column equivalent — same terracotta double-ring halo and headline, sized to fit within the 340pt player column without displacing Up Next.
   - Subscription gap (no active Apple Music subscription): same requirement — iPhone uses a sheet; design what this looks like inside a permanent column instead of a modal.

7. Sidebar: add a "New Playlist" affordance to the Playlists section (a plain row at the top or bottom of the list, matching the row style already used for existing playlists) — playlist creation exists on iPhone and has no iPad entry point yet.

8. Toasts: specify where the existing three-variant toast system (success amber / error terracotta with retry / neutral white) anchors within the three-column layout — bottom of the middle column only, not full-width across sidebar and player column.

9. Row-level actions: add a secondary-click / long-press context menu to track rows across the middle column (Album, Artist, Playlist, Search results) covering: Play Next, Add to Queue, Add to Library, Add to Playlist, Share, Go to Artist, Go to Album — the same seven actions already shipped on iPhone's long-press menu, here triggered by right-click/secondary-click since iPad has a pointer. Currently every row only defines a single onClick.

═══ FLAG — mark these as open questions in the spec comments, do not silently resolve them ═══

10. Playlist Edit mode's delete-row and drag-to-reorder affordances (Section 01, Playlist view): add a spec comment noting these are UNCONFIRMED against MusicKit's actual public interface — reordering has a known open defect on iPhone (hangs during playback), and track removal from a playlist has no confirmed API in this codebase's usage so far. Do not remove the drawn affordances, but mark them "pending a framework check" rather than final.

11. The entire Watch section (Section 03): add a spec comment at the top stating this board assumes an architecture decision that has not actually been made — whether Watch plays independently or relays through the paired iPhone via WatchConnectivity. Flag specifically that "Downloaded — 41 songs on watch" and the "Out of range" screen's meaning both depend on this answer, and should not be treated as final until it's decided.

12. Two iPad sidebar destinations — "Recently added" and a flat "Songs" browse — have no confirmed backing query in this codebase's service layer yet. Add a spec comment flagging both as tentative pending a capability check, same treatment as item 10.

═══ DO NOT ═══
- Do not add any non-Apple-Music service, account system, or content source.
- Do not turn the read-only audio-format badge into a selectable control.
- Do not resolve the Watch connectivity question yourself — flag it, don't pick an answer.
- Do not touch the mini-capsule-removal rule, the glass-is-chrome-only rule, or any Section 01/02 measurement not explicitly listed above.

Output: the revised Board 03 HTML in the same format as the current file (same `<!-- SECTION -->` comment structure, same sc-for/sc-if/image-slot component patterns, same top-of-file spec comment block updated to describe what changed and why).
```
