#!/usr/bin/env python3
"""
Parse OSM Overpass API JSON responses into UmiLog site seed format.
Consolidates multiple regional OSM dumps into a single sites file.

Usage: python3 osm_sites_to_json.py <raw_dir> <output_json>
Example: python3 osm_sites_to_json.py raw/ export/sites_osm.json
"""

import sys
import json
import os
import re
from datetime import datetime
from collections import defaultdict

# Region detection based on coordinates
def detect_region(lat, lon):
    """Determine diving region from coordinates."""
    if 12 <= lat <= 30 and 32 <= lon <= 44:
        return "Red Sea"
    if -10 <= lat <= 10 and 95 <= lon <= 145:
        return "Coral Triangle"
    if lat <= 20 and 95 <= lon <= 120:
        return "Southeast Asia"
    if 24 <= lat <= 46 and 122 <= lon <= 146:
        return "Japan"
    if -30 <= lat <= 0 and 110 <= lon <= 160:
        return "Australia"
    if 10 <= lat <= 28 and -90 <= lon <= -60:
        return "Caribbean"
    if 7 <= lat <= 25 and -120 <= lon <= -80:
        return "Central America"
    if 30 <= lat <= 46 and -6 <= lon <= 36:
        return "Mediterranean"
    if -2 <= lat <= 10 and 71 <= lon <= 82:
        return "Maldives"
    if -30 <= lat <= 10 and 130 <= lon <= 180:
        return "Pacific Islands"
    return "Global"


def detect_site_type(tags):
    """Determine dive site type from OSM tags."""
    if tags.get("historic") == "wreck":
        return "Wreck"
    if tags.get("seamark:type") == "wreck":
        return "Wreck"
    if tags.get("natural") == "reef":
        return "Reef"
    if tags.get("natural") == "sinkhole":
        return "Cave"  # Cenotes
    if tags.get("natural") == "cave_entrance":
        return "Cave"
    if "wall" in tags.get("name", "").lower() or "wall" in tags.get("description", "").lower():
        return "Wall"
    return "Reef"  # Default


def slugify(text):
    """Convert text to URL-safe slug."""
    text = text.lower().strip()
    text = re.sub(r'[^\w\s-]', '', text)
    text = re.sub(r'[\s_]+', '-', text)
    return text.strip('-')


def parse_osm_json(filepath):
    """Parse a single OSM Overpass JSON file."""
    sites = []

    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            data = json.load(f)
    except Exception as e:
        print(f"  Error loading {filepath}: {e}")
        return sites

    elements = data.get('elements', [])

    for elem in elements:
        # Get coordinates
        lat = elem.get('lat')
        lon = elem.get('lon')

        # For ways, calculate centroid from nodes
        if elem.get('type') == 'way' and 'center' in elem:
            lat = elem['center'].get('lat')
            lon = elem['center'].get('lon')

        if lat is None or lon is None:
            continue

        tags = elem.get('tags', {})
        osm_id = f"osm_{elem.get('type', 'n')}_{elem.get('id', 0)}"

        # Get name
        name = tags.get('name') or tags.get('name:en') or tags.get('alt_name')
        if not name:
            # Generate name from type
            site_type = detect_site_type(tags)
            name = f"Unnamed {site_type} Site"

        # Detect region and type
        region = detect_region(lat, lon)
        site_type = detect_site_type(tags)

        # Build location string
        addr_parts = []
        if tags.get('addr:city'):
            addr_parts.append(tags['addr:city'])
        if tags.get('addr:country'):
            addr_parts.append(tags['addr:country'])
        location = ', '.join(addr_parts) if addr_parts else region

        # Extract additional metadata
        description = tags.get('description') or tags.get('note') or ''

        # Parse depth values
        def parse_depth(val):
            if not val:
                return None
            try:
                # Handle ranges like "5-27"
                if '-' in str(val):
                    parts = str(val).replace('m', '').split('-')
                    return float(parts[-1].strip())  # Return max
                return float(str(val).replace('m', '').strip())
            except ValueError:
                return None

        # Extract dive-specific OSM tags
        max_depth = parse_depth(tags.get('scuba_diving:maxdepth') or tags.get('depth'))
        min_depth = parse_depth(tags.get('scuba_diving:mindepth'))

        # Difficulty mapping (OSM uses 1-5 scale)
        difficulty_map = {'1': 'Beginner', '2': 'Easy', '3': 'Intermediate', '4': 'Advanced', '5': 'Expert'}
        osm_difficulty = tags.get('scuba_diving:difficulty', '')
        difficulty = difficulty_map.get(str(osm_difficulty), 'Intermediate')

        # Current strength (1-5)
        current = tags.get('scuba_diving:current')

        # Entry method
        entry = tags.get('scuba_diving:entry') or ('boat' if tags.get('scuba_diving:entry:boat') else None)

        # Dangers
        dangers = tags.get('scuba_diving:dangers', '')

        # Website/links
        website = tags.get('website') or tags.get('url')
        wikidata_id = tags.get('wikidata')
        wikipedia = tags.get('wikipedia')

        # Wreck-specific data
        wreck_date = tags.get('wreck:date_sunk')
        wreck_type = tags.get('wreck:type')

        site = {
            "id": osm_id,
            "name": name,
            "location": location,
            "region": region,
            "latitude": lat,
            "longitude": lon,
            "difficulty": difficulty,
            "type": site_type.lower(),
            "description": description,
            "minDepth": min_depth,
            "maxDepth": max_depth or 30,
            "averageDepth": min_depth if min_depth else (max_depth / 2 if max_depth else 15),
            "currentStrength": int(current) if current and current.isdigit() else None,
            "entryType": entry,
            "dangers": dangers if dangers else None,
            "averageTemp": 26,
            "averageVisibility": 20,
            "website": website,
            "wikidataId": wikidata_id,
            "wikipedia": wikipedia,
            "wreckDate": wreck_date,
            "wreckType": wreck_type,
            "wishlist": False,
            "visitedCount": 0,
            "osmId": osm_id,
            "source": "OpenStreetMap",
            "license": "ODbL",
            "createdAt": datetime.utcnow().isoformat(timespec='seconds') + 'Z'
        }

        # Add tags from OSM - including dive type tags
        site_tags = []
        if tags.get("sport") == "scuba_diving":
            site_tags.append("Scuba Diving")
        if tags.get("natural") == "reef":
            site_tags.append("Reef")
        if tags.get("historic") == "wreck":
            site_tags.append("Wreck")
        if tags.get("natural") == "sinkhole":
            site_tags.append("Cenote")

        # Dive type tags from scuba_diving:type:*
        dive_type_map = {
            "drift": "Drift Dive",
            "wall": "Wall Dive",
            "cave": "Cave Dive",
            "cavern": "Cavern Dive",
            "night": "Night Dive",
            "wreck": "Wreck Dive",
            "reef": "Reef Dive",
            "muck": "Muck Dive",
            "sharks": "Shark Dive",
            "bigfish": "Big Fish",
            "snorkeling": "Snorkeling",
        }
        for dive_type, label in dive_type_map.items():
            if tags.get(f"scuba_diving:type:{dive_type}") == "yes":
                site_tags.append(label)

        site["tags"] = site_tags

        sites.append(site)

    return sites


def main():
    if len(sys.argv) < 3:
        print("Usage: osm_sites_to_json.py <raw_dir> <output_json>")
        sys.exit(1)

    raw_dir = sys.argv[1].rstrip('/')
    output_file = sys.argv[2]

    all_sites = []
    seen_coords = set()

    # Find all sites_*.json files in raw_dir
    for filename in os.listdir(raw_dir):
        if filename.startswith('sites_') and filename.endswith('.json'):
            filepath = os.path.join(raw_dir, filename)
            print(f"Processing {filename}...")

            sites = parse_osm_json(filepath)
            print(f"  Found {len(sites)} elements")

            # Deduplicate by coordinates
            for site in sites:
                coord_key = (round(site['latitude'], 5), round(site['longitude'], 5))
                if coord_key not in seen_coords:
                    seen_coords.add(coord_key)
                    all_sites.append(site)

    # Sort by region, then name
    all_sites.sort(key=lambda s: (s['region'], s['name']))

    # Write output
    output = {
        "sites": all_sites,
        "metadata": {
            "source": "OpenStreetMap",
            "license": "ODbL",
            "generated_at": datetime.utcnow().isoformat() + "Z",
            "count": len(all_sites),
        }
    }

    with open(output_file, 'w', encoding='utf-8') as f:
        json.dump(output, f, ensure_ascii=False, indent=2)

    print(f"\nWrote {len(all_sites)} sites -> {output_file}")

    # Region breakdown
    region_counts = defaultdict(int)
    for site in all_sites:
        region_counts[site['region']] += 1

    print("\nSites by region:")
    for region, count in sorted(region_counts.items(), key=lambda x: -x[1]):
        print(f"  {region}: {count}")


if __name__ == "__main__":
    main()
