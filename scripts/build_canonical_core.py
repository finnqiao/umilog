#!/usr/bin/env python3
"""
Build canonical core artifacts from canonical_site_list.json.

Outputs:
  Resources/SeedData/curated_core_sites.json  — ~2000 sites (same filename, backward compat)
  Resources/SeedData/regions.json             — 126 regions with group_id
  Resources/SeedData/region_groups.json       — 17 groups

Coordinates are filled in by enrich_geocode.py (later step).
Sites with null coords are excluded with an audit warning.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SEED_DATA = ROOT / "Resources" / "SeedData"
STAGE_DIR = ROOT / "data" / "stage"

INPUT_PATH = SEED_DATA / "canonical_site_list.json"
SITES_OUTPUT = SEED_DATA / "curated_core_sites.json"
REGIONS_OUTPUT = SEED_DATA / "regions.json"
GROUPS_OUTPUT = SEED_DATA / "region_groups.json"
AUDIT_PATH = SEED_DATA / "curation" / "audit_report.json"

ENRICHMENT_PATH = STAGE_DIR / "enrichment_checkpoint.json"
GEOCODE_PATH = STAGE_DIR / "geocode_results.json"


def slugify(text: str) -> str:
    return re.sub(r"-+", "-", re.sub(r"[^a-z0-9]+", "-", text.lower())).strip("-")


def site_id(region_id: str, site_name: str) -> str:
    return f"canonical_{region_id}_{slugify(site_name)}"


def load_optional_json(path: Path) -> dict:
    if path.exists():
        return json.loads(path.read_text())
    return {}


def build(limit_groups: int | None = None, use_region_center: bool = False) -> None:
    print(f"Reading {INPUT_PATH.name}...")
    data = json.loads(INPUT_PATH.read_text())
    all_groups = data["region_groups"]
    if limit_groups:
        all_groups = all_groups[:limit_groups]

    enrichment = load_optional_json(ENRICHMENT_PATH)
    geocode = load_optional_json(GEOCODE_PATH)

    now = datetime.now(timezone.utc).isoformat()
    audit: dict = {"generated_at": now, "missing_coords": [], "missing_enrichment": [], "groups": []}

    # ── Output containers ─────────────────────────────────────────────────
    out_groups: list[dict] = []
    out_regions: list[dict] = []
    out_sites: list[dict] = []
    seen_site_ids: set[str] = set()

    for sort_i, group in enumerate(all_groups):
        gid = group["id"]
        g_entry = {
            "id": gid,
            "name": group["name"],
            "tagline": group.get("tagline"),
            "description": group.get("description") or "",
            "latitude": group.get("latitude"),
            "longitude": group.get("longitude"),
            "cover_image_url": None,
            "sort_order": group.get("sort_order", sort_i + 1),
        }
        out_groups.append(g_entry)

        g_audit = {"id": gid, "regions": []}

        for region in group.get("regions", []):
            rid = region["id"]

            # Apply geocode results if available
            region_geocode = geocode.get(rid, {})

            r_entry = {
                "id": rid,
                "name": region["name"],
                "country_id": region.get("country_id"),
                "country": region.get("country"),
                "latitude": region.get("latitude"),
                "longitude": region.get("longitude"),
                "bounds": region.get("bounds"),
                "tagline": region.get("tagline"),
                "description": region.get("description") or "",
                "best_season": region.get("best_season"),
                "wikidata_id": None,
                "group_id": gid,
            }
            out_regions.append(r_entry)

            r_audit: dict = {"id": rid, "sites_missing_coords": [], "sites_missing_enrichment": []}

            for site in region.get("sites", []):
                sid = site_id(rid, site["name"])

                # Apply per-site geocode
                site_geo = geocode.get(sid, {})
                lat = site.get("latitude") or site_geo.get("latitude")
                lon = site.get("longitude") or site_geo.get("longitude")

                if lat is None or lon is None:
                    if use_region_center and region.get("latitude") is not None:
                        # Use region center as approximation (dev/test only)
                        lat = region["latitude"]
                        lon = region["longitude"]
                    else:
                        r_audit["sites_missing_coords"].append(site["name"])
                        audit["missing_coords"].append(sid)
                        continue  # skip sites without coordinates

                # Apply enrichment
                enrich = enrichment.get(sid, {})
                description = site.get("description") or enrich.get("description") or ""
                user_quotes = site.get("user_quotes") or enrich.get("user_quotes") or []
                best_season = site.get("best_season") or enrich.get("best_season") or region.get("best_season")

                if not enrich and not site.get("description"):
                    r_audit["sites_missing_enrichment"].append(site["name"])
                    audit["missing_enrichment"].append(sid)

                if sid in seen_site_ids:
                    continue
                seen_site_ids.add(sid)

                out_sites.append({
                    "id": sid,
                    "name": site["name"],
                    "region": region["name"],
                    "region_id": rid,
                    "country_id": region.get("country_id"),
                    "country": region.get("country"),
                    "area": region["name"],
                    "area_id": rid,
                    "latitude": lat,
                    "longitude": lon,
                    "type": site.get("type", "Reef"),
                    "difficulty": site.get("difficulty", "Intermediate"),
                    "maxDepth": site.get("maxDepth"),
                    "averageDepth": site.get("averageDepth"),
                    "averageTemp": site.get("averageTemp"),
                    "averageVisibility": site.get("averageVisibility"),
                    "access_level": site.get("access_level", "boat"),
                    "tags": site.get("tags") or [],
                    "collections": site.get("collections") or [],
                    "curation_score": site.get("curation_score", 8.0),
                    "popularity_score": site.get("popularity_score", 7.5),
                    "required_cert": site.get("required_cert"),
                    "best_season": best_season,
                    "aliases": site.get("aliases") or [],
                    "description": description,
                    "user_quotes": user_quotes,
                    "wikidata_id": site.get("wikidata_id"),
                    "osm_id": None,
                    "isPlanned": False,
                    "wishlist": False,
                    "visitedCount": 0,
                    "createdAt": now,
                    "wreck_verified": site.get("type") == "Wreck",
                    "destination_slug": rid,
                    "provenance": {"source": "canonical", "region_id": rid, "group_id": gid},
                })

            g_audit["regions"].append(r_audit)

        audit["groups"].append(g_audit)

    # ── Write outputs ──────────────────────────────────────────────────────
    SEED_DATA.mkdir(parents=True, exist_ok=True)
    (SEED_DATA / "curation").mkdir(exist_ok=True)

    sites_doc = {"version": data.get("version"), "sites": out_sites}
    SITES_OUTPUT.write_text(json.dumps(sites_doc, indent=2, ensure_ascii=False) + "\n")

    regions_doc = {"regions": out_regions}
    REGIONS_OUTPUT.write_text(json.dumps(regions_doc, indent=2, ensure_ascii=False) + "\n")

    groups_doc = {"region_groups": out_groups}
    GROUPS_OUTPUT.write_text(json.dumps(groups_doc, indent=2, ensure_ascii=False) + "\n")

    AUDIT_PATH.write_text(json.dumps(audit, indent=2, ensure_ascii=False) + "\n")

    print(f"\nWrote {SITES_OUTPUT.name}: {len(out_sites)} sites")
    print(f"Wrote {REGIONS_OUTPUT.name}: {len(out_regions)} regions")
    print(f"Wrote {GROUPS_OUTPUT.name}: {len(out_groups)} region groups")

    skipped = len(audit["missing_coords"])
    if skipped:
        pct = skipped / (len(out_sites) + skipped) * 100
        print(f"\n⚠  {skipped} sites skipped (null coords — {pct:.1f}%)")
        print("   Run enrich_geocode.py to fill coordinates, then re-run this script.")
    else:
        print("\n✓ All sites have coordinates.")

    print(f"\nAudit report: {AUDIT_PATH.relative_to(ROOT)}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--limit-groups", type=int, default=None,
                        help="Process only first N region groups (for testing)")
    parser.add_argument("--use-region-center", action="store_true",
                        help="Use region center coords for sites missing coordinates (dev/testing only)")
    args = parser.parse_args()
    build(limit_groups=args.limit_groups, use_region_center=args.use_region_center)
