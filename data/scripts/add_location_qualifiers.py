#!/usr/bin/env python3
"""
Add location qualifiers to duplicate site names.

This script:
1. Finds sites with duplicate names
2. Adds location qualifiers to make names unique (e.g., "Coral Reef - Banda Aceh")
3. Fixes known typos
4. Cleans up note-like names

Usage:
    python3 add_location_qualifiers.py <sites_json> <output_json>

Example:
    python3 add_location_qualifiers.py \
        data/export/sites_linked.json \
        data/export/sites_qualified.json
"""

import json
import sys
import re
from pathlib import Path
from datetime import datetime, timezone
from collections import defaultdict


# Known typos to fix
TYPO_FIXES = {
    "Monad Shoel": "Monad Shoal",
    "reef": "Coral Reef",
}

# Note-like patterns to detect
NOTE_PATTERNS = [
    r"^good\s",
    r"^nice\s",
    r"^great\s",
    r"^best\s",
    r"no need for",
    r"spot to see",
    r"place to",
    r"^[a-z]$",  # single letter
]

# Country code to name for qualifiers
COUNTRY_NAMES = {
    "AU": "Australia",
    "BS": "Bahamas",
    "BB": "Barbados",
    "BZ": "Belize",
    "BQ": "Bonaire",
    "BR": "Brazil",
    "VG": "BVI",
    "KY": "Caymans",
    "CO": "Colombia",
    "CR": "Costa Rica",
    "CU": "Cuba",
    "CW": "Curacao",
    "CY": "Cyprus",
    "DJ": "Djibouti",
    "DO": "Dominican Republic",
    "EC": "Ecuador",
    "EG": "Egypt",
    "FJ": "Fiji",
    "FR": "France",
    "GB": "UK",
    "GR": "Greece",
    "HN": "Honduras",
    "HR": "Croatia",
    "ID": "Indonesia",
    "IE": "Ireland",
    "IL": "Israel",
    "IN": "India",
    "IS": "Iceland",
    "IT": "Italy",
    "JM": "Jamaica",
    "JO": "Jordan",
    "JP": "Japan",
    "KE": "Kenya",
    "LK": "Sri Lanka",
    "MG": "Madagascar",
    "MT": "Malta",
    "MU": "Mauritius",
    "MV": "Maldives",
    "MX": "Mexico",
    "MY": "Malaysia",
    "MZ": "Mozambique",
    "NC": "New Caledonia",
    "NO": "Norway",
    "NZ": "New Zealand",
    "OM": "Oman",
    "PA": "Panama",
    "PF": "French Polynesia",
    "PG": "PNG",
    "PH": "Philippines",
    "PR": "Puerto Rico",
    "PT": "Portugal",
    "PW": "Palau",
    "SA": "Saudi Arabia",
    "SC": "Seychelles",
    "SD": "Sudan",
    "SO": "Somalia",
    "TH": "Thailand",
    "TR": "Turkey",
    "TZ": "Tanzania",
    "US": "USA",
    "VE": "Venezuela",
    "VN": "Vietnam",
    "ZA": "South Africa",
}


def get_location_qualifier(site: dict) -> str:
    """Get a location qualifier for a site."""
    # Try area first
    area = site.get("area", "").strip()
    if area and len(area) > 2:
        return area

    # Try location field (often "Area, Country")
    location = site.get("location", "").strip()
    if location:
        parts = [p.strip() for p in location.split(",")]
        if parts and len(parts[0]) > 2:
            return parts[0]

    # Fall back to country name
    country_id = site.get("country_id") or site.get("country", "")
    if country_id:
        # Check if it's a code
        if country_id in COUNTRY_NAMES:
            return COUNTRY_NAMES[country_id]
        # Check if it's a name
        if len(country_id) > 2:
            return country_id

    # Use coordinates as last resort
    lat, lon = site.get("latitude"), site.get("longitude")
    if lat is not None and lon is not None:
        return f"{lat:.2f}°, {lon:.2f}°"

    return "Unknown"


def is_note_like(name: str) -> bool:
    """Check if name looks like a note/comment rather than proper name."""
    name_lower = name.lower()
    for pattern in NOTE_PATTERNS:
        if re.search(pattern, name_lower):
            return True
    return len(name) > 60  # Very long names are often notes


def fix_name(name: str) -> str:
    """Apply typo fixes and normalization."""
    # Apply known typo fixes
    if name in TYPO_FIXES:
        return TYPO_FIXES[name]

    # Normalize whitespace
    name = " ".join(name.split())

    return name


def add_qualifiers(sites: list) -> list:
    """Add location qualifiers to duplicate names."""
    # Group sites by normalized name
    name_groups = defaultdict(list)
    for i, site in enumerate(sites):
        name = fix_name(site.get("name", "").strip())
        name_lower = name.lower()
        name_groups[name_lower].append((i, name, site))

    # Track changes
    changes = []
    note_like = []

    for name_lower, group in name_groups.items():
        # Get the original (non-lowercased) name from first occurrence
        original_name = group[0][1]

        # Check for note-like names
        if is_note_like(original_name):
            for idx, name, site in group:
                qualifier = get_location_qualifier(site)
                # Add coordinates to make unique
                lat, lon = site.get("latitude"), site.get("longitude")
                coord_suffix = ""
                if lat is not None and lon is not None:
                    coord_suffix = f" ({lat:.2f}, {lon:.2f})"
                new_name = f"Dive Site - {qualifier}{coord_suffix}"
                sites[idx]["name"] = new_name
                note_like.append((original_name[:50], new_name))
            continue

        # Skip if not a duplicate
        if len(group) == 1:
            # Still apply typo fixes
            idx, name, site = group[0]
            fixed = fix_name(name)
            if fixed != name:
                sites[idx]["name"] = fixed
                changes.append((name, fixed))
            continue

        # Add qualifiers to duplicates
        qualifiers_used = set()
        for idx, name, site in group:
            qualifier = get_location_qualifier(site)
            lat, lon = site.get("latitude"), site.get("longitude")

            # Make qualifier unique if needed
            base_qualifier = qualifier
            if qualifier in qualifiers_used:
                # Add coordinates for disambiguation
                if lat is not None and lon is not None:
                    qualifier = f"{base_qualifier} ({lat:.2f}, {lon:.2f})"
                else:
                    # Fall back to counter
                    counter = 2
                    while f"{base_qualifier} {counter}" in qualifiers_used:
                        counter += 1
                    qualifier = f"{base_qualifier} {counter}"

            qualifiers_used.add(qualifier)

            new_name = f"{original_name} - {qualifier}"
            sites[idx]["name"] = new_name

        changes.append((original_name, f"{len(group)} occurrences qualified"))

    return sites, changes, note_like


def main():
    if len(sys.argv) != 3:
        print(__doc__)
        sys.exit(1)

    input_path = Path(sys.argv[1])
    output_path = Path(sys.argv[2])

    # Load sites
    print(f"Loading sites: {input_path}")
    with open(input_path) as f:
        data = json.load(f)

    sites = data.get("sites", data) if isinstance(data, dict) else data
    print(f"  {len(sites)} sites loaded")

    # Find duplicates before
    name_counts = defaultdict(int)
    for site in sites:
        name_counts[site.get("name", "").strip().lower()] += 1
    dupe_groups_before = sum(1 for c in name_counts.values() if c > 1)
    dupe_sites_before = sum(c for c in name_counts.values() if c > 1)

    print(f"\nBefore: {dupe_groups_before} duplicate name groups ({dupe_sites_before} sites)")

    # Add qualifiers
    print("\nAdding location qualifiers...")
    sites, changes, note_like = add_qualifiers(sites)

    # Find duplicates after
    name_counts = defaultdict(int)
    for site in sites:
        name_counts[site.get("name", "").strip().lower()] += 1
    dupe_groups_after = sum(1 for c in name_counts.values() if c > 1)
    dupe_sites_after = sum(c for c in name_counts.values() if c > 1)

    print(f"After: {dupe_groups_after} duplicate name groups ({dupe_sites_after} sites)")

    # Report changes
    if note_like:
        print(f"\nRenamed {len(note_like)} note-like names:")
        for old, new in note_like[:10]:
            print(f"  '{old}...' -> '{new}'")

    # Show sample changes
    print(f"\nQualified {len(changes)} name groups:")
    for old, change in list(changes)[:15]:
        print(f"  {old}: {change}")

    # Output
    output = {
        "sites": sites,
        "metadata": {
            "generated_at": datetime.now(timezone.utc).isoformat(),
            "source": str(input_path),
            "total_sites": len(sites),
            "duplicate_groups_fixed": dupe_groups_before - dupe_groups_after,
            "note_like_fixed": len(note_like),
        }
    }

    output_path.parent.mkdir(parents=True, exist_ok=True)
    with open(output_path, "w") as f:
        json.dump(output, f, indent=2)

    print(f"\nOutput written to: {output_path}")


if __name__ == "__main__":
    main()
