#!/usr/bin/env python3
"""
Validate enriched data before deployment.

Checks all enriched data files for quality and completeness.

Usage:
    python3 enrichment_validator.py <export_dir>

Example:
    python3 data/scripts/enrichment_validator.py data/export

Output:
    - Validation report to stdout
    - Exit code 0 if all checks pass, 1 otherwise
"""

import sys
import json
from pathlib import Path

TARGETS = {
    "species_image_coverage": 0.90,
    "species_description_coverage": 1.0,
    "site_description_coverage": 0.80,
    "region_description_coverage": 1.0,
    "min_description_length": 50,
}


def load_json(path: Path) -> dict:
    if not path.exists():
        return {}
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def validate_species_images(export_dir: Path) -> dict:
    results = {"passed": True, "errors": [], "warnings": [], "stats": {}}
    manifest_path = export_dir / "species_reference_images.json"
    data = load_json(manifest_path)

    if not data:
        results["errors"].append(f"Missing: {manifest_path}")
        results["passed"] = False
        return results

    stats = data.get("stats", {})
    species = data.get("species", {})
    total = stats.get("total_species", len(species))
    with_images = stats.get("with_images", 0)
    coverage = with_images / max(total, 1)

    results["stats"] = {
        "total_species": total,
        "with_images": with_images,
        "coverage": round(coverage * 100, 1)
    }

    if coverage < TARGETS["species_image_coverage"]:
        results["warnings"].append(f"Coverage {coverage*100:.1f}% below target")

    multi_image = sum(1 for s in species.values() if s.get("photo_count", 0) >= 2)
    results["stats"]["with_2plus_images"] = multi_image
    return results


def validate_species_descriptions(export_dir: Path) -> dict:
    results = {"passed": True, "errors": [], "warnings": [], "stats": {}}
    manifest_path = export_dir / "species_descriptions_enhanced.json"
    data = load_json(manifest_path)

    if not data:
        results["errors"].append(f"Missing: {manifest_path}")
        results["passed"] = False
        return results

    species = data.get("species", {})
    total = len(species)
    with_desc = sum(1 for s in species.values()
                    if s.get("visual_description", {}).get("prompt_additions", ""))

    results["stats"] = {
        "total": total,
        "with_desc": with_desc,
        "coverage": round(with_desc / max(total, 1) * 100, 1)
    }
    return results


def validate_site_descriptions(export_dir: Path) -> dict:
    results = {"passed": True, "errors": [], "warnings": [], "stats": {}}
    manifest_path = export_dir / "sites_enriched.json"
    data = load_json(manifest_path)

    if not data:
        results["errors"].append(f"Missing: {manifest_path}")
        results["passed"] = False
        return results

    sites = data.get("sites", [])
    total = len(sites)
    with_desc = sum(1 for s in sites if len(s.get("description", "")) >= 50)

    results["stats"] = {
        "total": total,
        "with_desc": with_desc,
        "coverage": round(with_desc / max(total, 1) * 100, 1)
    }
    return results


def validate_region_descriptions(export_dir: Path) -> dict:
    results = {"passed": True, "errors": [], "warnings": [], "stats": {}}
    manifest_path = export_dir / "regions_enriched.json"
    data = load_json(manifest_path)

    if not data:
        results["errors"].append(f"Missing: {manifest_path}")
        results["passed"] = False
        return results

    regions = data.get("regions", [])
    total = len(regions)
    with_desc = sum(1 for r in regions if r.get("tagline") and r.get("description"))

    results["stats"] = {
        "total": total,
        "with_desc": with_desc,
        "coverage": round(with_desc / max(total, 1) * 100, 1)
    }

    if with_desc < total:
        results["passed"] = False
    return results


def print_section(title: str, results: dict):
    status = "PASS" if results["passed"] else "FAIL"
    print(f"\n{title}: {status}")
    for k, v in results.get("stats", {}).items():
        print(f"  {k}: {v}")
    for e in results.get("errors", []):
        print(f"  ERROR: {e}")
    for w in results.get("warnings", []):
        print(f"  WARNING: {w}")


def main():
    if len(sys.argv) != 2:
        print("Usage: enrichment_validator.py <export_dir>")
        sys.exit(1)

    export_dir = Path(sys.argv[1])
    if not export_dir.exists():
        print(f"Error: Export directory not found: {export_dir}")
        sys.exit(1)

    print("=" * 50)
    print("ENRICHMENT VALIDATION REPORT")
    print("=" * 50)

    all_passed = True
    for name, validator in [
        ("Species Images", validate_species_images),
        ("Species Descriptions", validate_species_descriptions),
        ("Site Descriptions", validate_site_descriptions),
        ("Region Descriptions", validate_region_descriptions),
    ]:
        result = validator(export_dir)
        print_section(name, result)
        if not result["passed"]:
            all_passed = False

    print("\n" + "=" * 50)
    print("RESULT:", "PASS" if all_passed else "FAIL")
    sys.exit(0 if all_passed else 1)


if __name__ == "__main__":
    main()
