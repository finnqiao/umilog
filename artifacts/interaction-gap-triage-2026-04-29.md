# UmiLog Map Interaction Gap Triage
Date: 2026-04-29
Scope: Explore/Search/Cluster/Inspect interaction pass on simulator via `DiveMapUITests` scenarios and direct reruns in Xcode.

## Summary
- Core map interaction flows validated and green in automated coverage:
  - cluster tap does not auto-zoom
  - explicit cluster zoom action available and functional
  - pin preview close affordance visible and functional
  - tap-outside-to-dismiss preview functional
  - Indonesia query returns hierarchical search results
- One notable interaction gap remains in the inspect close path.

## Open Gaps

### High
1. Inspect header back affordance is inconsistent in cluster-origin inspection.
   - Impact: user can get “stuck” in site details unless they use sheet swipe-down dismiss.
   - Repro: open cluster-origin inspect detail; tap inspect header back chevron; mode can remain `inspect`.
   - Current workaround: swipe down on the sheet successfully restores cluster surface.
   - Evidence: `test17_CloseDetailsReturnsToClusterSurface` required fallback swipe gesture to reliably satisfy return-surface assertion.

## Notes
- This report reflects current behavior after reducer/state/test updates in this branch.
- Recommended next fix: make inspect close action deterministic from header affordance (single-tap close parity with swipe dismiss).
