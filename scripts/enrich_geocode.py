#!/usr/bin/env python3
"""
Geocode sites in canonical_site_list.json that have null coordinates.

Outputs: data/stage/geocode_results.json  (checkpoint, not committed)

Strategy per site:
  1. Nominatim search, bounded to region bounds when available
  2. Accept first result within region bounds
  3. Skip and warn if no result found

Run: python3 scripts/enrich_geocode.py [--limit N] [--dry-run]
"""

from __future__ import annotations

import argparse
import json
import re
import time
from datetime import datetime, timezone
from pathlib import Path

import urllib.request
import urllib.parse

ROOT = Path(__file__).resolve().parents[1]
SEED_DATA = ROOT / "Resources" / "SeedData"
STAGE_DIR = ROOT / "data" / "stage"
INPUT_PATH = SEED_DATA / "canonical_site_list.json"
OUTPUT_PATH = STAGE_DIR / "geocode_results.json"

NOMINATIM_URL = "https://nominatim.openstreetmap.org/search"
HEADERS = {"User-Agent": "UmiLog-geocoder/1.0 (finnqiao1993@gmail.com)"}
RATE_LIMIT_S = 1.1  # Nominatim ToS: max 1 req/s


def slugify(text: str) -> str:
    return re.sub(r"-+", "-", re.sub(r"[^a-z0-9]+", "-", text.lower())).strip("-")


def site_id(region_id: str, site_name: str) -> str:
    return f"canonical_{region_id}_{slugify(site_name)}"


def within_bounds(lat: float, lon: float, bounds: dict | None, region: dict) -> bool:
    """Check if point is within region bounds or within a loose radius of region center."""
    if bounds:
        return (
            bounds["min_lat"] <= lat <= bounds["max_lat"]
            and bounds["min_lon"] <= lon <= bounds["max_lon"]
        )
    # Fallback: within ~2° of region center
    rlat = region.get("latitude")
    rlon = region.get("longitude")
    if rlat and rlon:
        return abs(lat - rlat) < 2.0 and abs(lon - rlon) < 2.0
    return True  # no bounds info, accept anything


def nominatim_search(query: str, bounds: dict | None, country: str | None) -> dict | None:
    params: dict = {
        "q": query,
        "format": "json",
        "limit": "5",
        "addressdetails": "0",
    }
    if bounds:
        # viewbox: min_lon,max_lat,max_lon,min_lat
        params["viewbox"] = f"{bounds['min_lon']},{bounds['max_lat']},{bounds['max_lon']},{bounds['min_lat']}"
        params["bounded"] = "1"

    url = f"{NOMINATIM_URL}?{urllib.parse.urlencode(params)}"
    req = urllib.request.Request(url, headers=HEADERS)
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            results = json.loads(resp.read().decode())
        return results[0] if results else None
    except Exception as e:
        print(f"    Nominatim error: {e}")
        return None


def geocode_site(site: dict, region: dict) -> dict | None:
    """Try to geocode a site. Returns {latitude, longitude, source} or None."""
    name = site["name"]
    country = region.get("country", "")
    bounds = region.get("bounds")

    queries = [
        f"{name} dive site {country}",
        f"{name} {region['name']} diving",
        f"{name} {country}",
    ]

    for q in queries:
        result = nominatim_search(q, bounds, country)
        time.sleep(RATE_LIMIT_S)
        if result:
            lat = float(result["lat"])
            lon = float(result["lon"])
            if within_bounds(lat, lon, bounds, region):
                return {"latitude": lat, "longitude": lon, "source": "nominatim", "query": q}
        # Try without bounds on second attempt
        if bounds:
            result = nominatim_search(q, None, country)
            time.sleep(RATE_LIMIT_S)
            if result:
                lat = float(result["lat"])
                lon = float(result["lon"])
                if within_bounds(lat, lon, None, region):
                    return {"latitude": lat, "longitude": lon, "source": "nominatim_unbounded", "query": q}

    return None


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--limit", type=int, default=None, help="Stop after N sites processed")
    parser.add_argument("--dry-run", action="store_true", help="Print sites needing geocoding, don't call API")
    parser.add_argument("--region", type=str, default=None, help="Only process sites in this region id")
    args = parser.parse_args()

    STAGE_DIR.mkdir(parents=True, exist_ok=True)

    data = json.loads(INPUT_PATH.read_text())

    # Load existing checkpoint
    checkpoint: dict = {}
    if OUTPUT_PATH.exists():
        checkpoint = json.loads(OUTPUT_PATH.read_text())
    print(f"Checkpoint: {len(checkpoint)} sites already geocoded")

    sites_needing_geocode = []
    for group in data["region_groups"]:
        for region in group.get("regions", []):
            if args.region and region["id"] != args.region:
                continue
            for site in region.get("sites", []):
                sid = site_id(region["id"], site["name"])
                has_coords = site.get("latitude") is not None and site.get("longitude") is not None
                in_checkpoint = sid in checkpoint
                if not has_coords and not in_checkpoint:
                    sites_needing_geocode.append((sid, site, region))

    print(f"Sites needing geocoding: {len(sites_needing_geocode)}")

    if args.dry_run:
        for sid, site, region in sites_needing_geocode[:50]:
            print(f"  {sid}")
        if len(sites_needing_geocode) > 50:
            print(f"  ... and {len(sites_needing_geocode) - 50} more")
        return

    failed = []
    processed = 0

    for sid, site, region in sites_needing_geocode:
        if args.limit and processed >= args.limit:
            break

        print(f"[{processed+1}/{len(sites_needing_geocode)}] {sid}", end=" ... ", flush=True)
        result = geocode_site(site, region)

        if result:
            checkpoint[sid] = result
            print(f"✓ ({result['latitude']:.4f}, {result['longitude']:.4f})")
        else:
            failed.append(sid)
            print("✗ not found")

        processed += 1

        # Save checkpoint every 50
        if processed % 50 == 0:
            OUTPUT_PATH.write_text(json.dumps(checkpoint, indent=2, ensure_ascii=False) + "\n")
            print(f"  [checkpoint saved: {len(checkpoint)} entries]")

    OUTPUT_PATH.write_text(json.dumps(checkpoint, indent=2, ensure_ascii=False) + "\n")

    print(f"\nDone. Geocoded: {processed - len(failed)}, Failed: {len(failed)}")
    if failed:
        print(f"\nSites without coordinates ({len(failed)}):")
        for sid in failed:
            print(f"  {sid}")
        print("\nAdd coordinates manually to canonical_site_list.json for these sites,")
        print("then re-run build_canonical_core.py (without --use-region-center).")


if __name__ == "__main__":
    main()
