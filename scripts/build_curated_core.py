#!/usr/bin/env python3
"""Build a curated global-core dive site dataset.

Inputs:
- Resources/SeedData/source_registry.json
- Resources/SeedData/benchmark_sites.json
- Resources/SeedData/manual_overrides.json
- Resources/SeedData/sites_enriched.json (audit input only)

Outputs:
- Resources/SeedData/curated_core_sites.json
- Resources/SeedData/areas.json
- Resources/SeedData/curation/audit_report.json
"""

from __future__ import annotations

import json
import math
import re
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
SEED_DIR = ROOT / "Resources" / "SeedData"
CURATION_DIR = SEED_DIR / "curation"

SOURCE_REGISTRY_PATH = SEED_DIR / "source_registry.json"
BENCHMARKS_PATH = SEED_DIR / "benchmark_sites.json"
OVERRIDES_PATH = SEED_DIR / "manual_overrides.json"
BASE_SITES_PATH = SEED_DIR / "sites_enriched.json"
OUTPUT_SITES_PATH = SEED_DIR / "curated_core_sites.json"
OUTPUT_AREAS_PATH = SEED_DIR / "areas.json"
AUDIT_REPORT_PATH = CURATION_DIR / "audit_report.json"

GENERIC_WRECK_PATTERNS = [
    re.compile(r"^unnamed shipwreck", re.I),
    re.compile(r"^unknown shipwreck", re.I),
    re.compile(r"^shipwreck$", re.I),
    re.compile(r"^wreck$", re.I),
    re.compile(r"\bprotected wreck\b", re.I),
    re.compile(r"\barchaeological wreck\b", re.I),
    re.compile(r"\bhistoric wreck\b", re.I),
]

REGION_DEFAULTS = {
    "coral-triangle": {"averageTemp": 28.0, "averageVisibility": 18.0},
    "red-sea-egypt": {"averageTemp": 25.0, "averageVisibility": 25.0},
    "maldives": {"averageTemp": 28.0, "averageVisibility": 24.0},
    "palau": {"averageTemp": 28.0, "averageVisibility": 25.0},
    "great-barrier-reef": {"averageTemp": 26.0, "averageVisibility": 22.0},
    "caribbean-mexico": {"averageTemp": 27.0, "averageVisibility": 23.0},
    "philippines": {"averageTemp": 28.0, "averageVisibility": 18.0},
    "thailand": {"averageTemp": 28.0, "averageVisibility": 16.0},
    "south-africa": {"averageTemp": 22.0, "averageVisibility": 15.0},
}


def load_json(path: Path) -> Any:
    return json.loads(path.read_text())


def write_json(path: Path, payload: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n")


def normalize(value: str | None) -> str:
    if not value:
        return ""
    lowered = value.lower()
    flattened = "".join(ch if ch.isalnum() else " " for ch in lowered)
    return " ".join(flattened.split())


def slugify(value: str) -> str:
    return normalize(value).replace(" ", "-")


def tag_list(*values: str) -> list[str]:
    seen: set[str] = set()
    result: list[str] = []
    for value in values:
        normalized = normalize(value)
        if normalized and normalized not in seen:
            seen.add(normalized)
            result.append(value)
    return result


def in_bounds(site: dict[str, Any], bounds: dict[str, float] | None) -> bool:
    if not bounds:
        return True
    lat = site.get("latitude")
    lon = site.get("longitude")
    if lat is None or lon is None:
        return False
    return (
        bounds["min_lat"] <= float(lat) <= bounds["max_lat"]
        and bounds["min_lon"] <= float(lon) <= bounds["max_lon"]
    )


def haversine_km(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    r = 6371.0
    p1 = math.radians(lat1)
    p2 = math.radians(lat2)
    dp = math.radians(lat2 - lat1)
    dl = math.radians(lon2 - lon1)
    a = math.sin(dp / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2
    return 2 * r * math.atan2(math.sqrt(a), math.sqrt(1 - a))


def is_generic_wreck(name: str) -> bool:
    return any(pattern.search(name) for pattern in GENERIC_WRECK_PATTERNS)


def merge_unique(*groups: list[str]) -> list[str]:
    seen: set[str] = set()
    result: list[str] = []
    for group in groups:
        for value in group:
            stripped = value.strip()
            normalized = normalize(stripped)
            if stripped and normalized and normalized not in seen:
                seen.add(normalized)
                result.append(stripped)
    return result


def score_candidate(candidate: dict[str, Any], names: list[str], bounds: dict[str, float] | None, base_site_id: str | None) -> int:
    score = 0
    candidate_name = normalize(candidate.get("name"))
    if not candidate_name:
        return -999
    if base_site_id and candidate.get("id") == base_site_id:
        score += 200
    if in_bounds(candidate, bounds):
        score += 40
    for name in names:
        normalized = normalize(name)
        if not normalized:
            continue
        if normalized == candidate_name:
            score += 140
        elif normalized in candidate_name or candidate_name in normalized:
            score += 70
    if is_generic_wreck(candidate.get("name", "")):
        score -= 150
    if candidate.get("region") == "Global":
        score -= 25
    return score


def pick_base_site(
    site_spec: dict[str, Any],
    destination: dict[str, Any],
    base_sites: list[dict[str, Any]],
    overrides: dict[str, Any],
) -> dict[str, Any] | None:
    site_key = f"{destination['destination_slug']}::{site_spec['name']}"
    override = overrides.get("site_overrides", {}).get(site_key, {})
    base_site_id = override.get("base_site_id")
    names = merge_unique(
        [site_spec["name"]],
        site_spec.get("aliases", []),
        site_spec.get("match_names", []),
        override.get("match_names", []),
    )
    bounds = destination.get("bounds")

    best: dict[str, Any] | None = None
    best_score = -999
    for candidate in base_sites:
        if candidate.get("id") in overrides.get("excluded_ids", []):
            continue
        if any(re.search(pattern, candidate.get("name", ""), re.I) for pattern in overrides.get("excluded_name_patterns", [])):
            continue
        if (
            base_site_id != candidate.get("id")
            and destination.get("bounds")
            and not in_bounds(candidate, destination.get("bounds"))
        ):
            continue
        score = score_candidate(candidate, names, bounds, base_site_id)
        if score > best_score:
            best = candidate
            best_score = score
    return best if best_score >= 80 else None


def fallback_description(site_spec: dict[str, Any], destination: dict[str, Any]) -> str:
    tags = site_spec.get("tags", [])
    highlights = ", ".join(tags[:2]) if tags else "marine life"
    type_name = site_spec.get("type", "Reef").lower()
    return f"Curated {type_name} dive in {destination['area']} known for {highlights}."


def build_site_record(
    destination: dict[str, Any],
    site_spec: dict[str, Any],
    base_site: dict[str, Any] | None,
) -> dict[str, Any]:
    defaults = destination.get("defaults", {})
    region_defaults = REGION_DEFAULTS.get(destination["region_id"], {})
    canonical_name = site_spec["name"]
    aliases = merge_unique(site_spec.get("aliases", []), site_spec.get("match_names", []), [base_site["name"]] if base_site and base_site.get("name") != canonical_name else [])

    average_depth = site_spec.get("averageDepth")
    if average_depth is None and base_site is not None:
        average_depth = base_site.get("averageDepth")
    if average_depth is None:
        average_depth = defaults.get("averageDepth", 18.0)

    max_depth = site_spec.get("maxDepth")
    if max_depth is None and base_site is not None:
        max_depth = base_site.get("maxDepth")
    if max_depth is None:
        max_depth = defaults.get("maxDepth", max(average_depth + 10.0, 28.0))

    average_temp = site_spec.get("averageTemp")
    if average_temp is None and base_site is not None:
        average_temp = base_site.get("averageTemp")
    if average_temp is None:
        average_temp = defaults.get("averageTemp", region_defaults.get("averageTemp", 26.0))

    average_visibility = site_spec.get("averageVisibility")
    if average_visibility is None and base_site is not None:
        average_visibility = base_site.get("averageVisibility")
    if average_visibility is None:
        average_visibility = defaults.get("averageVisibility", region_defaults.get("averageVisibility", 18.0))

    latitude = site_spec.get("latitude")
    longitude = site_spec.get("longitude")
    if base_site is not None:
        latitude = base_site.get("latitude", latitude)
        longitude = base_site.get("longitude", longitude)

    description = site_spec.get("description") or (base_site or {}).get("description") or fallback_description(site_spec, destination)
    tags = merge_unique(site_spec.get("tags", []), (base_site or {}).get("tags", []))

    record = {
        "id": f"curated_{destination['area_id']}_{slugify(canonical_name)}",
        "name": canonical_name,
        "region": destination["region"],
        "area": destination["area"],
        "country": destination["country"],
        "latitude": latitude,
        "longitude": longitude,
        "averageDepth": round(float(average_depth), 2),
        "maxDepth": round(float(max_depth), 2),
        "averageTemp": round(float(average_temp), 2),
        "averageVisibility": round(float(average_visibility), 2),
        "difficulty": site_spec.get("difficulty", defaults.get("difficulty", "Intermediate")),
        "type": site_spec.get("type", defaults.get("type", "Reef")),
        "description": description,
        "wishlist": False,
        "visitedCount": 0,
        "tags": tags,
        "country_id": destination["country_id"],
        "region_id": destination["region_id"],
        "area_id": destination["area_id"],
        "wikidata_id": (base_site or {}).get("wikidata_id") or (base_site or {}).get("wikidataId"),
        "osm_id": (base_site or {}).get("osm_id") or (base_site or {}).get("osmId") or (base_site or {}).get("id"),
        "aliases": aliases,
        "curation_score": float(site_spec.get("curation_score", defaults.get("curation_score", 9.0))),
        "popularity_score": float(site_spec.get("popularity_score", defaults.get("popularity_score", 8.5))),
        "access_level": site_spec.get("access_level", defaults.get("access_level", "boat")),
        "wreck_verified": bool(site_spec.get("wreck_verified", False)),
        "destination_slug": destination["destination_slug"],
        "provenance": {
            "matched_base_id": (base_site or {}).get("id"),
            "source_ids": destination.get("source_ids", []),
        },
    }
    return record


def build_areas(destinations: list[dict[str, Any]]) -> dict[str, Any]:
    return {
        "areas": [
            {
                "id": destination["area_id"],
                "name": destination["area"],
                "region_id": destination["region_id"],
                "country_id": destination["country_id"],
                "latitude": destination["latitude"],
                "longitude": destination["longitude"],
                "wikidata_id": destination.get("wikidata_id"),
            }
            for destination in destinations
        ]
    }


def find_duplicate_clusters(records: list[dict[str, Any]]) -> list[dict[str, Any]]:
    duplicates: list[dict[str, Any]] = []
    for index, left in enumerate(records):
        for right in records[index + 1 :]:
            if normalize(left["name"]) != normalize(right["name"]):
                continue
            distance = haversine_km(left["latitude"], left["longitude"], right["latitude"], right["longitude"])
            if distance <= 1.0:
                duplicates.append(
                    {
                        "name": left["name"],
                        "left_id": left["id"],
                        "right_id": right["id"],
                        "distance_km": round(distance, 3),
                    }
                )
    return duplicates


def build_audit_report(
    base_sites: list[dict[str, Any]],
    curated_sites: list[dict[str, Any]],
    benchmarks: list[dict[str, Any]],
    overrides: dict[str, Any],
) -> dict[str, Any]:
    uk_wreck_like = 0
    wreck_like = 0
    global_region_rows = 0
    for site in base_sites:
        name = site.get("name", "")
        description = site.get("description", "") or ""
        location = " ".join(filter(None, [site.get("country"), site.get("area"), site.get("location")]))
        combined = f"{name} {description}".lower()
        if "wreck" in combined:
            wreck_like += 1
            if "united kingdom" in location.lower() or "united kingdom" in name.lower() or "orkney" in location.lower():
                uk_wreck_like += 1
        if site.get("region") == "Global":
            global_region_rows += 1

    coverage: list[dict[str, Any]] = []
    source_misses: list[dict[str, Any]] = []
    curated_keys = {f"{site['destination_slug']}::{normalize(site['name'])}" for site in curated_sites}
    for destination in benchmarks:
        destination_key = destination["destination_slug"]
        benchmark_sites = destination.get("sites", [])
        matched_in_base = 0
        missing_in_base: list[str] = []
        for site_spec in benchmark_sites:
            names = merge_unique([site_spec["name"]], site_spec.get("aliases", []), site_spec.get("match_names", []))
            found = any(
                in_bounds(candidate, destination.get("bounds"))
                and any(normalize(name) == normalize(candidate.get("name")) or normalize(name) in normalize(candidate.get("name")) for name in names)
                for candidate in base_sites
                if candidate.get("id") not in overrides.get("excluded_ids", [])
            )
            if found:
                matched_in_base += 1
            else:
                missing_in_base.append(site_spec["name"])

        curated_count = sum(1 for site in curated_sites if site["destination_slug"] == destination_key)
        benchmark_count = len(benchmark_sites)
        coverage.append(
            {
                "destination_slug": destination_key,
                "minimum_coverage": destination.get("minimum_coverage", 0),
                "benchmark_count": benchmark_count,
                "curated_count": curated_count,
                "coverage": round(curated_count / benchmark_count, 3) if benchmark_count else 1.0,
                "source_match_count": matched_in_base,
            }
        )
        if missing_in_base:
            source_misses.append({"destination_slug": destination_key, "missing_benchmark_sites": missing_in_base})

    return {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "source_corpus": {
            "total_sites": len(base_sites),
            "global_region_rows": global_region_rows,
            "wreck_like_rows": wreck_like,
            "uk_wreck_like_rows": uk_wreck_like,
        },
        "curated_core": {
            "site_count": len(curated_sites),
            "duplicate_clusters_within_1km": find_duplicate_clusters(curated_sites),
            "rows_missing_geography": [site["id"] for site in curated_sites if not (site.get("country_id") and site.get("region_id") and site.get("area_id"))],
            "rows_with_global_region": [site["id"] for site in curated_sites if site.get("region") == "Global"],
            "generic_wreck_rows": [site["id"] for site in curated_sites if is_generic_wreck(site.get("name", ""))],
        },
        "benchmark_coverage": coverage,
        "source_benchmark_misses": source_misses,
    }


def validate_curated_sites(curated_sites: list[dict[str, Any]]) -> None:
    errors: list[str] = []
    for site in curated_sites:
        if not site.get("country_id") or not site.get("region_id") or not site.get("area_id"):
            errors.append(f"{site['id']}: missing geography ids")
        if site.get("region") == "Global":
            errors.append(f"{site['id']}: Global region is not allowed")
        if is_generic_wreck(site.get("name", "")):
            errors.append(f"{site['id']}: generic wreck naming is not allowed")
        if site.get("latitude") is None or site.get("longitude") is None:
            errors.append(f"{site['id']}: missing coordinates")
    if errors:
        raise SystemExit("Curated-core validation failed:\n- " + "\n- ".join(errors[:50]))


def main() -> None:
    source_registry = load_json(SOURCE_REGISTRY_PATH)
    benchmarks_file = load_json(BENCHMARKS_PATH)
    overrides = load_json(OVERRIDES_PATH)
    base_sites = load_json(BASE_SITES_PATH).get("sites", [])
    destinations = benchmarks_file.get("destinations", [])

    if not source_registry.get("sources"):
        raise SystemExit("source_registry.json is empty")
    if not destinations:
        raise SystemExit("benchmark_sites.json is empty")

    curated_sites: list[dict[str, Any]] = []
    for destination in destinations:
        for site_spec in destination.get("sites", []):
            base_site = pick_base_site(site_spec, destination, base_sites, overrides)
            curated_sites.append(build_site_record(destination, site_spec, base_site))

    validate_curated_sites(curated_sites)

    curated_payload = {
        "version": benchmarks_file.get("version", "2026-04-15-curated-core-v1"),
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "site_count": len(curated_sites),
        "sites": curated_sites,
    }
    areas_payload = build_areas(destinations)
    audit_payload = build_audit_report(base_sites, curated_sites, destinations, overrides)

    write_json(OUTPUT_SITES_PATH, curated_payload)
    write_json(OUTPUT_AREAS_PATH, areas_payload)
    write_json(AUDIT_REPORT_PATH, audit_payload)

    print(f"Wrote {OUTPUT_SITES_PATH.relative_to(ROOT)} ({len(curated_sites)} sites)")
    print(f"Wrote {OUTPUT_AREAS_PATH.relative_to(ROOT)} ({len(areas_payload['areas'])} areas)")
    print(f"Wrote {AUDIT_REPORT_PATH.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
