#!/usr/bin/env python3
"""
Link species to dive sites using GBIF and OBIS occurrence data.
Creates site_species junction records with likelihood ratings.

Usage: python3 site_species_linker.py <sites_json> <species_json> <output_json>
Example: python3 site_species_linker.py export/sites.json export/species.json export/site_species.json

APIs:
- GBIF: https://api.gbif.org/v1/occurrence/search
- OBIS: https://api.obis.org/v3/occurrence
"""

import sys
import json
import time
import requests
from datetime import datetime
from collections import defaultdict
from math import radians, sin, cos, sqrt, atan2

GBIF_API = "https://api.gbif.org/v1"
OBIS_API = "https://api.obis.org/v3"
SEARCH_RADIUS_KM = 25


def haversine_distance(lat1, lon1, lat2, lon2):
    """Calculate distance between two points in km."""
    R = 6371
    dlat = radians(lat2 - lat1)
    dlon = radians(lon2 - lon1)
    a = sin(dlat/2)**2 + cos(radians(lat1)) * cos(radians(lat2)) * sin(dlon/2)**2
    return 2 * R * atan2(sqrt(a), sqrt(1-a))


def classify_likelihood(count):
    """Classify species likelihood based on occurrence count."""
    if count >= 50:
        return "common"
    elif count >= 10:
        return "occasional"
    else:
        return "rare"


def fetch_gbif_species_near_site(lat, lon, radius_km=SEARCH_RADIUS_KM):
    """Fetch species occurrences near a coordinate from GBIF."""
    url = f"{GBIF_API}/occurrence/search"
    params = {
        "decimalLatitude": lat,
        "decimalLongitude": lon,
        "radius": f"{radius_km}km",
        "limit": 0,
        "facet": "speciesKey",
        "facetLimit": 100,
    }

    try:
        resp = requests.get(url, params=params, timeout=60)
        time.sleep(0.35)

        if not resp.ok:
            return {}

        data = resp.json()
        facets = data.get("facets", [])

        species = {}
        for facet in facets:
            if facet.get("field") == "SPECIES_KEY":
                for count in facet.get("counts", []):
                    gbif_key = int(count["name"])
                    species[gbif_key] = {
                        "gbif_key": gbif_key,
                        "count": count["count"],
                        "source": "gbif",
                    }
        return species
    except Exception as e:
        return {}


def fetch_obis_species_near_site(lat, lon, radius_km=SEARCH_RADIUS_KM):
    """Fetch species occurrences near a coordinate from OBIS."""
    url = f"{OBIS_API}/occurrence"
    params = {
        "geometry": f"POINT({lon} {lat})",
        "distance": radius_km * 1000,  # meters
        "size": 0,
        "facets": "speciesid",
    }

    try:
        resp = requests.get(url, params=params, timeout=60)
        time.sleep(1.1)  # OBIS rate limit

        if not resp.ok:
            return {}

        data = resp.json()
        # OBIS response structure may vary
        return {}  # Placeholder - OBIS API handling
    except Exception as e:
        return {}


def main():
    if len(sys.argv) < 4:
        print("Usage: site_species_linker.py <sites_json> <species_json> <output_json>")
        sys.exit(1)

    sites_file = sys.argv[1]
    species_file = sys.argv[2]
    output_file = sys.argv[3]

    # Load sites
    with open(sites_file, 'r', encoding='utf-8') as f:
        sites_data = json.load(f)
    sites = sites_data.get('sites', sites_data) if isinstance(sites_data, dict) else sites_data

    # Load species catalog
    with open(species_file, 'r', encoding='utf-8') as f:
        species_data = json.load(f)
    species_list = species_data.get('species', [])

    # Build GBIF key to species ID mapping
    gbif_to_species = {}
    for sp in species_list:
        gbif_key = sp.get('gbif_key')
        if gbif_key:
            gbif_to_species[gbif_key] = sp['id']

    print(f"Loaded {len(sites)} sites and {len(species_list)} species")
    print(f"GBIF-linked species: {len(gbif_to_species)}")

    # Process each site
    site_species_links = []
    processed = 0

    for site in sites:
        site_id = site.get('id')
        lat = site.get('latitude')
        lon = site.get('longitude')

        if not site_id or lat is None or lon is None:
            continue

        processed += 1
        if processed % 100 == 0:
            print(f"Progress: {processed}/{len(sites)} sites")

        # Fetch nearby species
        species_counts = fetch_gbif_species_near_site(lat, lon)

        # Create links for species in our catalog
        for gbif_key, data in species_counts.items():
            species_id = gbif_to_species.get(gbif_key)
            if not species_id:
                continue  # Species not in our catalog

            likelihood = classify_likelihood(data["count"])

            link = {
                "site_id": site_id,
                "species_id": species_id,
                "likelihood": likelihood,
                "source": "gbif",
                "source_record_count": data["count"],
                "last_updated": datetime.utcnow().isoformat() + "Z",
            }
            site_species_links.append(link)

    # Deduplicate (keep highest count for same site-species pair)
    unique_links = {}
    for link in site_species_links:
        key = (link["site_id"], link["species_id"])
        if key not in unique_links or link["source_record_count"] > unique_links[key]["source_record_count"]:
            unique_links[key] = link

    final_links = list(unique_links.values())

    # Write output
    output = {
        "site_species": final_links,
        "metadata": {
            "source": "GBIF",
            "search_radius_km": SEARCH_RADIUS_KM,
            "processed_at": datetime.utcnow().isoformat() + "Z",
            "sites_processed": processed,
            "links_created": len(final_links),
        }
    }

    with open(output_file, 'w', encoding='utf-8') as f:
        json.dump(output, f, ensure_ascii=False, indent=2)

    print(f"\nWrote {len(final_links)} site-species links -> {output_file}")

    # Summary stats
    likelihood_counts = defaultdict(int)
    for link in final_links:
        likelihood_counts[link["likelihood"]] += 1

    print("\nLikelihood distribution:")
    for likelihood, count in sorted(likelihood_counts.items()):
        print(f"  {likelihood}: {count}")


if __name__ == "__main__":
    main()
