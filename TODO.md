# 📋 UmiLog TODO (Map‑first Migration)

This list tracks the 2025 refactor to a map‑first IA with a 4‑step logging wizard and updated History/Wildlife/Profile.

## ✅ Completed
- Replace long form with 4‑step Logging Wizard (Steps 1–4)
- Add SpeciesRepository (popular + search)
- Extend LogDraft with selected species + notes
- Implement WizardSaver (Dive + Sighting + ListState + notifications)
- Map FAB: prompt Quick Log vs Full Wizard
- Fix numeric text field bindings by converting to String inputs with safe parsing
- Build succeeded on iPhone 17 Pro simulator
- Site details card updated to the "Grand Bazaar" pattern
- **Database seeder implementation**: All JSON files loaded on first launch
- **24 dive sites** across Red Sea, Caribbean, Southeast Asia, Pacific, Mediterranean
- **35 wildlife species** with scientific names and categories
- **3 mock dive logs** with instructor sign-offs
- **19 wildlife sightings** linked to dives and species

## 🚧 In Progress / Next Up
- **Test the app** with seeded data on simulator
- Verify map displays all 24 pins correctly
- Confirm wizard shows 35 species in catalog
- Test history view displays 3 completed dives
- Validate wildlife sightings display per dive
- Enhance Step 4 summary to show species names instead of IDs
- "View in History" banner after successful save with tap‑through
- Explore gestures: double‑tap pin and swipe on card → ★ Wishlist
- History: bulk export CSV and Sign‑off (stub)
- QA acceptance checklist and in‑app instrumentation hooks

## Phased Plan

### Phase 0 – Foundations ✅
- Remove overlay nav; keep tab bar
- Apply tokens (spacing, radius, typography, colors)
- Replace country stat with summary strip

### Phase 1 – Map IA ✅ (initial pass)
- My Map/Explore segmented control + chips
- Tier tabs: Regions · Areas · Sites
- Bottom sheet + site cards + region progress
- Pin styles and legend
- Remove separate Sites tab; deep links to Map

### Phase 2 – Logging & History (active)
- [x] 4‑step wizard with validation and fast‑path save
- [ ] Review bar polish and haptics
- [ ] History KPI tiles, group by day
- [ ] Editable chips and multi‑select toolbar
- [ ] CSV export (initial)

### Phase 3 – Wildlife
- [x] Species search and popular list
- [x] Save sightings with dives
- [ ] Wildlife tab filters and quick add

### Phase 4 – Backfill & Polish
- [ ] Backfill v1 (date range → per‑day site pick → essentials)
- [ ] Explore sorters: Nearby/Popular/Beginner
- [ ] A11y labels on pins, chips, cards; ensure no overlap with home indicator
- [ ] Animations, haptics, empty states

## Data & Models
- [x] Region → Area → Site hierarchy (seed JSON) - 24 sites across 4 regions
- [x] Wildlife species catalog (35 real marine species)
- [x] Mock dive logs (3 completed dives with sightings)
- Dive, ListState, Species, Sighting
- UIState persisted for mode/tier/filters

## Metrics & QA Targets
- My Map vs Explore recognition ≥ 90%
- Wishlist from Explore ≤ 2 taps
- Start log from site card ≤ 2 taps; essentials ≤ 30 s
- Backfill 10 dives < 8 min (seeded set)

## Testing Checklist
- Unit: repositories, migrations, WizardSaver, species search
- UI: map → sheet → wizard, offline paths, wishlist gesture
- Perf: cold start < 2s; DB writes < 100ms; search < 200ms

## Documentation
- [x] README.md (map‑first overview)
- [x] ARCHITECTURE.md (modules, flows, site details card)
- [ ] TODO.md (this file)
- [x] LEARNINGS.md (latest fixes)
- [x] ASSETS.md (tokens, pins, sheets, screenshots paths)

---

Updated: October 2025 – track progress and maintain velocity 🚀
