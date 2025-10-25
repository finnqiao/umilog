# 📋 UmiLog TODO — iOS Refactor (Explore → Plan → Dive → Relive)

Status legend: ✅ done · 🟡 in progress · ⏳ not started

See also: README.md, ARCHITECTURE.md, ASSETS.md, LEARNINGS.md

## Progress inventory (validated)
- ✅ Optimized dataset seeding (tiles + manifest); tests and benchmarks in place
- ✅ Viewport-driven queries with debounce; bottom-sheet “in view” counts
- ✅ Underwater Theme baseline (glassy cards, transitions, overlays)
- ✅ 4-step Logging Wizard (fast-path save after Step 2)
- ✅ Species catalog + sightings; WizardSaver transactionally persists data
- ✅ MapLibre as default (MapKit fallback retained)

## Phase 0 — Foundations & Data (Complete)
- ✅ Seed pipeline (1,120 sites) integrated with fallback to legacy seeds
- ✅ FTS5 search, tags/facets repositories, viewport-first queries
- ✅ Diagnostics and accessibility baseline (VO announcements, dark-mode contrast)

## Phase 1 — Explore: Areas & In‑Area
- ⏳ Discover scope with chips visible only in Discover (chips: Near me, Beginner, Wrecks, Big animals, Season, Entry, Depth, Current, Viz)
- ⏳ Single Search pill; one icon opening Filters & Layers (two tabs) in a unified modal
- 🟡 Sheet headers show scope and counts; make counts tap-to-fit and add Follow‑map toggle
- ⏳ Enter Area flow: camera zoom-to-bounds; Back to Areas pill; hide area pins; show only sites inside active area

## Phase 2 — Dive: Contextual logging
- ⏳ Contextual Start a dive action when within ~150m of a known site in the active area
- ⏳ Site-card swipe right → Quick Log
- ⏳ Remove per-card Log buttons; promote Start a dive on site detail

## Phase 3 — Plan & Offline
- ⏳ Card utilities: Save / Download / Plan (on area and site)
- ⏳ Offline area packs (tiles + images); download and manage status
- ⏳ Plan: assign dates, show status chips (Logged, Saved, Planned)

## Phase 4 — Relive: My Dive Sites
- ⏳ Rename scope to My Dive Sites with segments: Timeline | Saved | Planned (fold History into Timeline)
- ⏳ Timeline: image-forward log cards; tap → open log; share from here
- ⏳ Saved/Planned: same image-first cards; tap → enter area/site

## Phase 5 — Search & Dive Lens
- ⏳ Search results grouped with imagery: AREAS (“Enter area …”) then SITES (“Open site …”)
- ⏳ Filters tab vs Dive Lens tab (wildlife hotspots, marine parks, currents); primary CTA: Show results (N)

## Phase 6 — Underwater Theme & Pins
- ✅ Underwater Theme baseline (dark-first blues, watery cards/transitions)
- ⏳ Align MapLibre style palette (water/land/labels) to theme
- ⏳ Area pins: capsule rings with “Name · count”, status color, subtle glow/pulse on select
- ⏳ Site pins: small circles colored by difficulty with entry glyph; render only inside active area
- ⏳ AA contrast audit over imagery (scrims), esp. chips/cards/sheet headers

## Phase 7 — Performance & Accessibility
- ✅ Debounce viewport queries; viewport-first fetches
- 🟡 Cap visible sites for perf (limit render count per viewport)
- ⏳ Lazy-load images with BlurHash placeholders; prefetch in scroll direction
- ⏳ Reduce Motion disables large parallax and pin pulses
- ⏳ VoiceOver strings for areas/sites (“Area, Similan Islands, 23 sites, Logged”)

## Phase 8 — Guidance & States
- ⏳ Coach marks (first 2–3 sessions): “Tap any card to enter an area”, “Swipe right to quick‑log”
- ⏳ Empty/permission/zero‑result states with CTAs: Enable location; Clear filters; Zoom out; Download area

---

## Migration checklist (no code)
1. ⏳ Rename scope to My Dive Sites; add Timeline | Saved | Planned; remove standalone History
2. ⏳ Replace floating search bubble; chips only in Discover; add single Search pill; unify Filters & Layers in one modal
3. ⏳ Replace list rows with image‑first cards (Areas 16:9; Sites 3:2); full card tap = primary CTA
4. ⏳ Implement explicit Areas ↔ In‑Area state; Back to Areas pill; render sites only inside active area
5. ⏳ Add contextual Start a dive (near site) and Quick Log via swipe; remove per‑card Log buttons
6. 🟡 Apply Underwater Theme across UI; align MapLibre style palette (water/land/labels/pins)
7. ⏳ Make header counts tappable (zoom‑to‑fit) and add Follow‑map toggle to sync list↔viewport
8. ⏳ Ship image placeholders and caching; prefetch in scroll direction
9. ⏳ Add coach marks, empty, permission, and zero‑result states
10. ⏳ QA: 60fps map + scroll, AA contrast, 44pt targets, Respect Reduce Motion, VoiceOver labels

---

## QA acceptance checklist
- ⏳ Map and scroll ≥ 60fps on iPhone 13+ simulators; image loading doesn’t drop frames
- ⏳ All text passes AA contrast over imagery (scrims applied where needed)
- ⏳ All tappable targets ≥ 44pt incl. utility icons and Back to Areas pill
- ⏳ Reduce Motion disables large parallax and pin pulses; animations remain subtle
- ⏳ VoiceOver reads: “Area, Name, N sites, Logged/Planned” and “Site, Name, difficulty, entry, status”
- ⏳ Follow‑map toggle synchronizes list and viewport; counts tap‑to‑fit animates camera
- ⏳ Empty/permission states include clear CTAs: Enable location; Clear filters; Zoom out; Download area

---

## 📋 Backlog (still relevant; outside this design-only refactor)
- ⏳ Add UI toggle in Profile to switch Map Engine (MapKit vs MapLibre)
- ⏳ Expand MapLibre style (bathymetry raster source + land/water layers)
- ⏳ Add custom Metal water layer to MapLibre style (low alpha caustics)
- ⏳ Replace runtime images with bundled SDF sprite once asset pipeline is ready
- ⏳ Ship visual polish: Underwater theme animations/tweaks
- ⏳ Add A11y labels on pins, chips, cards; ensure no overlap with home indicator
- ⏳ Add small debug toggle in Profile to enable/disable UnderwaterTheme
- ⏳ Enhance Step 4 summary to show species names instead of IDs
- ⏳ “View in Timeline” banner after successful save with tap‑through
- ⏳ Explore gestures: double‑tap pin and swipe on card → ★ Wishlist
- ⏳ History/Timeline: bulk export CSV and Sign‑off (stub)
- ⏳ Tag filtering UI: Multi-select chips for tags, difficulty, site type, depth ranges
- ⏳ Wildlife-based filtering: Find sites with specific species
- ⏳ QA instrumentation hooks and acceptance checklist wiring

## Docs cleanup (this refactor)
- ⏳ Archive outdated PRD/task docs to docs/archive with DEPRECATED banners linking to README/ARCHITECTURE
- ⏳ Add disclaimer to design/README.md: prototype predates this refactor (reference‑only)
- ⏳ Replace “History” references with “My Dive Sites → Timeline” across docs
- ⏳ Cross‑link README, ARCHITECTURE, TODO, ASSETS, LEARNINGS consistently

---

## Success metrics (tied to JTBD)
- JTBD 1/2 (Explore): Enter‑Area rate; Sites‑opened/session; Chip usage rate
- JTBD 3 (Dive): Log starts near site; Time‑to‑first log (new install)
- JTBD 4/8 (Plan/Offline): Save→Plan conversion; Offline packs installed
- JTBD 5 (Relive): Timeline opens/session; Photo attachments per log
- JTBD 6 (Wildlife): Dive Lens toggles; Wildlife‑filtered sessions
- JTBD 9 (Search): Search→action conversion

---

Last updated: 2025‑10‑25
