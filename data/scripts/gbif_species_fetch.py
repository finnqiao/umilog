#!/usr/bin/env python3
"""
Fetch marine species occurrences from GBIF (Global Biodiversity Information Facility).
Focuses on dive regions to build species occurrence data.

Usage: python3 gbif_species_fetch.py <output_json>
Example: python3 gbif_species_fetch.py raw/gbif_species.json

API: https://api.gbif.org/v1/
Rate limit: ~3 requests/second
"""

import sys
import json
import time
import requests
from datetime import datetime
from collections import defaultdict

GBIF_API = "https://api.gbif.org/v1"

# Dive regions with bounding boxes [minLat, minLon, maxLat, maxLon]
DIVE_REGIONS = [
    {"name": "Red Sea", "id": "red-sea", "bbox": [12, 32, 30, 44]},
    {"name": "Coral Triangle", "id": "coral-triangle", "bbox": [-10, 95, 10, 140]},
    {"name": "Caribbean", "id": "caribbean", "bbox": [10, -90, 28, -60]},
    {"name": "Great Barrier Reef", "id": "australia", "bbox": [-25, 142, -10, 155]},
    {"name": "Maldives", "id": "indian-ocean", "bbox": [-1, 72, 8, 74]},
    {"name": "Japan", "id": "japan", "bbox": [24, 122, 46, 146]},
    {"name": "Mediterranean", "id": "mediterranean", "bbox": [30, -6, 46, 36]},
    {"name": "Southeast Asia", "id": "southeast-asia", "bbox": [-10, 95, 25, 120]},
]

# Key marine phyla
MARINE_PHYLA = {
    44: "Chordata",       # Fish, mammals, reptiles
    52: "Cnidaria",       # Corals, jellyfish
    54: "Mollusca",       # Octopus, nudibranch
    88: "Arthropoda",     # Crustaceans
    95: "Echinodermata",  # Starfish, urchins
}

# Category mapping based on class
CLASS_TO_CATEGORY = {
    "Actinopterygii": "Fish",
    "Chondrichthyes": "Fish",  # Sharks, rays
    "Reptilia": "Reptile",
    "Mammalia": "Mammal",
    "Anthozoa": "Coral",
    "Cephalopoda": "Invertebrate",
    "Gastropoda": "Invertebrate",
    "Malacostraca": "Invertebrate",
    "Echinoidea": "Invertebrate",
    "Asteroidea": "Invertebrate",
    "Holothuroidea": "Invertebrate",
    "Crinoidea": "Invertebrate",
}


def fetch_species_in_region(bbox, phylum_key, limit=100):
    """Fetch species occurrences in a bounding box for a phylum."""
    url = f"{GBIF_API}/occurrence/search"
    params = {
        "decimalLatitude": f"{bbox[0]},{bbox[2]}",
        "decimalLongitude": f"{bbox[1]},{bbox[3]}",
        "phylumKey": phylum_key,
        "hasCoordinate": "true",
        "limit": 0,  # We just want facets
        "facet": "speciesKey",
        "facetLimit": limit,
    }

    try:
        resp = requests.get(url, params=params, timeout=60)
        time.sleep(0.35)  # Rate limit

        if not resp.ok:
            print(f"    Error: {resp.status_code}")
            return []

        data = resp.json()
        facets = data.get("facets", [])

        species_counts = []
        for facet in facets:
            if facet.get("field") == "SPECIES_KEY":
                for count in facet.get("counts", []):
                    species_counts.append({
                        "gbif_key": int(count["name"]),
                        "count": count["count"],
                    })

        return species_counts
    except Exception as e:
        print(f"    Exception: {e}")
        return []


def fetch_species_details(gbif_key):
    """Fetch species details from GBIF."""
    url = f"{GBIF_API}/species/{gbif_key}"

    try:
        resp = requests.get(url, timeout=30)
        time.sleep(0.35)

        if not resp.ok:
            return None

        return resp.json()
    except Exception as e:
        return None


def main():
    if len(sys.argv) < 2:
        print("Usage: gbif_species_fetch.py <output_json>")
        sys.exit(1)

    output_file = sys.argv[1]

    # Collect species by key with occurrence counts per region
    species_occurrences = defaultdict(lambda: {"regions": {}, "total_count": 0})

    print("Fetching species occurrences from GBIF...")

    for region in DIVE_REGIONS:
        print(f"\n[{region['name']}] bbox={region['bbox']}")

        for phylum_key, phylum_name in MARINE_PHYLA.items():
            print(f"  Phylum: {phylum_name}...")

            species_list = fetch_species_in_region(region["bbox"], phylum_key)

            for sp in species_list:
                key = sp["gbif_key"]
                count = sp["count"]
                species_occurrences[key]["regions"][region["id"]] = count
                species_occurrences[key]["total_count"] += count

            print(f"    Found {len(species_list)} species")

    # Filter to species with significant occurrences
    print(f"\nTotal unique species keys: {len(species_occurrences)}")

    # Get details for top species
    significant_species = sorted(
        species_occurrences.items(),
        key=lambda x: x[1]["total_count"],
        reverse=True
    )[:500]  # Top 500 species

    print(f"Fetching details for top {len(significant_species)} species...")

    species_output = []
    for i, (gbif_key, occurrence_data) in enumerate(significant_species):
        if i % 50 == 0:
            print(f"  Progress: {i}/{len(significant_species)}")

        details = fetch_species_details(gbif_key)
        if not details:
            continue

        scientific_name = details.get("scientificName", "")
        canonical_name = details.get("canonicalName", "")
        vernacular = details.get("vernacularName", "")
        class_name = details.get("class", "")
        family = details.get("family", "")

        # Determine category
        category = CLASS_TO_CATEGORY.get(class_name, "Invertebrate")

        # Generate readable name
        name = vernacular or canonical_name.split()[-1].title() if canonical_name else scientific_name

        species_output.append({
            "id": f"gbif_{gbif_key}",
            "gbif_key": gbif_key,
            "name": name,
            "scientific_name": scientific_name,
            "canonical_name": canonical_name,
            "category": category,
            "class": class_name,
            "family": family.lower() if family else None,
            "regions": list(occurrence_data["regions"].keys()),
            "occurrence_counts": occurrence_data["regions"],
            "total_occurrences": occurrence_data["total_count"],
        })

    # Determine rarity based on occurrence count
    max_count = max(s["total_occurrences"] for s in species_output) if species_output else 1
    for sp in species_output:
        ratio = sp["total_occurrences"] / max_count
        if ratio >= 0.3:
            sp["rarity"] = "Common"
        elif ratio >= 0.1:
            sp["rarity"] = "Uncommon"
        elif ratio >= 0.01:
            sp["rarity"] = "Rare"
        else:
            sp["rarity"] = "Very Rare"

    # Write output
    output = {
        "species": species_output,
        "metadata": {
            "source": "GBIF",
            "api": GBIF_API,
            "fetched_at": datetime.utcnow().isoformat() + "Z",
            "species_count": len(species_output),
            "regions_queried": [r["name"] for r in DIVE_REGIONS],
        }
    }

    with open(output_file, 'w', encoding='utf-8') as f:
        json.dump(output, f, ensure_ascii=False, indent=2)

    print(f"\nWrote {len(species_output)} species -> {output_file}")


if __name__ == "__main__":
    main()
