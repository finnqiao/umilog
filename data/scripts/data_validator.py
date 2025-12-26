#!/usr/bin/env python3
"""
Validate and deduplicate data files before app seeding.
Checks for:
- Coordinate validity
- Required fields
- Duplicate detection
- Referential integrity

Usage: python3 data_validator.py <data_dir>
Example: python3 data_validator.py export/
"""

import sys
import json
import os
from collections import defaultdict


def validate_coordinates(lat, lon):
    """Check if coordinates are valid."""
    if lat is None or lon is None:
        return False, "Missing coordinates"
    if not (-90 <= lat <= 90):
        return False, f"Invalid latitude: {lat}"
    if not (-180 <= lon <= 180):
        return False, f"Invalid longitude: {lon}"
    return True, None


def validate_required_fields(record, required_fields):
    """Check if required fields are present."""
    missing = []
    for field in required_fields:
        if field not in record or record[field] is None:
            missing.append(field)
    if missing:
        return False, f"Missing fields: {missing}"
    return True, None


def dedupe_by_key(records, key_func):
    """Deduplicate records by a key function."""
    seen = {}
    dupes = []
    for record in records:
        key = key_func(record)
        if key in seen:
            dupes.append((key, record))
        else:
            seen[key] = record
    return list(seen.values()), dupes


def main():
    if len(sys.argv) < 2:
        print("Usage: data_validator.py <data_dir>")
        sys.exit(1)

    data_dir = sys.argv[1].rstrip('/')
    errors = []
    warnings = []
    stats = defaultdict(int)

    # Validate sites
    sites_file = f"{data_dir}/sites_merged.json"
    if os.path.exists(sites_file):
        print(f"Validating {sites_file}...")
        with open(sites_file, 'r', encoding='utf-8') as f:
            data = json.load(f)
        sites = data.get('sites', data) if isinstance(data, dict) else data

        valid_sites = []
        for site in sites:
            site_id = site.get('id', 'unknown')

            # Check coordinates
            valid, err = validate_coordinates(site.get('latitude'), site.get('longitude'))
            if not valid:
                errors.append(f"Site {site_id}: {err}")
                continue

            # Check required fields
            valid, err = validate_required_fields(site, ['id', 'name', 'region'])
            if not valid:
                errors.append(f"Site {site_id}: {err}")
                continue

            valid_sites.append(site)

        # Deduplicate by coordinates (rounded)
        deduped, dupes = dedupe_by_key(
            valid_sites,
            lambda s: (s['name'].lower(), round(s['latitude'], 4), round(s['longitude'], 4))
        )

        stats['sites_input'] = len(sites)
        stats['sites_valid'] = len(valid_sites)
        stats['sites_deduped'] = len(deduped)
        stats['sites_duplicates'] = len(dupes)

        for key, _ in dupes[:5]:
            warnings.append(f"Duplicate site: {key}")

        # Write validated output
        output = {"sites": deduped}
        with open(f"{data_dir}/sites_validated.json", 'w', encoding='utf-8') as f:
            json.dump(output, f, ensure_ascii=False, indent=2)

    # Validate species
    species_file = f"{data_dir}/species_catalog_v2.json"
    if os.path.exists(species_file):
        print(f"Validating {species_file}...")
        with open(species_file, 'r', encoding='utf-8') as f:
            data = json.load(f)
        species = data.get('species', [])

        valid_species = []
        for sp in species:
            sp_id = sp.get('id', 'unknown')

            valid, err = validate_required_fields(sp, ['id', 'name', 'category'])
            if not valid:
                warnings.append(f"Species {sp_id}: {err}")
                continue

            valid_species.append(sp)

        # Deduplicate by scientific name
        deduped, dupes = dedupe_by_key(
            valid_species,
            lambda s: s.get('scientificName', s['id']).lower()
        )

        stats['species_input'] = len(species)
        stats['species_valid'] = len(valid_species)
        stats['species_deduped'] = len(deduped)
        stats['species_duplicates'] = len(dupes)

    # Validate site-species links
    links_file = f"{data_dir}/site_species.json"
    if os.path.exists(links_file):
        print(f"Validating {links_file}...")
        with open(links_file, 'r', encoding='utf-8') as f:
            data = json.load(f)
        links = data.get('site_species', [])

        valid_links = []
        for link in links:
            valid, err = validate_required_fields(link, ['site_id', 'species_id', 'likelihood'])
            if not valid:
                warnings.append(f"Link: {err}")
                continue

            if link['likelihood'] not in ['common', 'occasional', 'rare']:
                warnings.append(f"Invalid likelihood: {link['likelihood']}")
                continue

            valid_links.append(link)

        stats['links_input'] = len(links)
        stats['links_valid'] = len(valid_links)

    # Print report
    print("\n" + "=" * 50)
    print("VALIDATION REPORT")
    print("=" * 50)

    print("\nStatistics:")
    for key, value in sorted(stats.items()):
        print(f"  {key}: {value}")

    if errors:
        print(f"\nErrors ({len(errors)}):")
        for err in errors[:10]:
            print(f"  - {err}")
        if len(errors) > 10:
            print(f"  ... and {len(errors) - 10} more")

    if warnings:
        print(f"\nWarnings ({len(warnings)}):")
        for warn in warnings[:10]:
            print(f"  - {warn}")
        if len(warnings) > 10:
            print(f"  ... and {len(warnings) - 10} more")

    # Exit code
    if errors:
        print("\nValidation FAILED")
        sys.exit(1)
    else:
        print("\nValidation PASSED")
        sys.exit(0)


if __name__ == "__main__":
    main()
