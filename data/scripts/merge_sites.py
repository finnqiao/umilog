#!/usr/bin/env python3
"""Merge dive site sources, deduplicating by name and location."""

import json
import sys
from pathlib import Path


def load_sites(filepath: Path) -> list:
    """Load sites from a JSON file."""
    try:
        data = json.load(open(filepath))
        if isinstance(data, dict):
            return data.get('sites', [])
        return data
    except Exception as e:
        print(f"  Warning: Could not load {filepath}: {e}")
        return []


def main():
    if len(sys.argv) < 3:
        print("Usage: merge_sites.py <output_file> <input_file1> [input_file2 ...]")
        sys.exit(1)

    output_file = Path(sys.argv[1])
    input_files = [Path(f) for f in sys.argv[2:]]

    sites = []
    seen = set()

    for filepath in input_files:
        if not filepath.exists():
            print(f"  Skipping {filepath} (not found)")
            continue

        file_sites = load_sites(filepath)
        added = 0

        for site in file_sites:
            name = site.get('name', '').lower()
            lat = round(site.get('latitude', 0), 4)
            lon = round(site.get('longitude', 0), 4)
            key = (name, lat, lon)

            if key not in seen:
                seen.add(key)
                sites.append(site)
                added += 1

        print(f"  Loaded {added} unique sites from {filepath.name}")

    output_file.parent.mkdir(parents=True, exist_ok=True)
    with open(output_file, 'w') as f:
        json.dump({'sites': sites}, f, indent=2)

    print(f"\nMerged {len(sites)} total sites -> {output_file}")


if __name__ == '__main__':
    main()
