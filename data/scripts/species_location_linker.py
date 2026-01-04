#!/usr/bin/env python3
"""
Link species to geographic hierarchy (countries, regions) using GBIF occurrence data.
Creates bidirectional junction tables for species ↔ locations.

Usage: python3 species_location_linker.py
Inputs: species_images_prompt.csv
Outputs:
  - species_countries.json (junction table)
  - species_regions.json (junction table)
  - species_catalog_full.json (enriched species with location arrays)
  - countries_enriched.json (countries with species arrays)
  - regions_enriched.json (regions with species arrays)
"""

import csv
import json
import time
import requests
import re
from datetime import datetime, timezone
from collections import defaultdict
from pathlib import Path

GBIF_API = "https://api.gbif.org/v1"
DATA_DIR = Path(__file__).parent.parent
EXPORT_DIR = DATA_DIR / "export"

# Rate limiting
GBIF_DELAY = 0.35  # seconds between requests

# Country to region mapping (from geographic_hierarchy.py)
COUNTRY_TO_REGION = {
    # Red Sea
    "EG": "red-sea", "SD": "red-sea", "SA": "red-sea", "JO": "red-sea", "IL": "red-sea", "DJ": "red-sea",
    # Indian Ocean
    "MV": "indian-ocean", "SC": "indian-ocean", "MU": "indian-ocean", "MG": "indian-ocean",
    "LK": "indian-ocean", "IN": "indian-ocean", "OM": "indian-ocean", "AE": "indian-ocean",
    # Southeast Asia
    "TH": "southeast-asia", "MY": "southeast-asia", "ID": "southeast-asia", "PH": "southeast-asia",
    "VN": "southeast-asia", "MM": "southeast-asia", "KH": "southeast-asia",
    # Japan
    "JP": "japan",
    # Australia
    "AU": "australia",
    # Pacific Islands
    "FJ": "pacific-islands", "PF": "pacific-islands", "NC": "pacific-islands", "VU": "pacific-islands",
    "WS": "pacific-islands", "PW": "pacific-islands", "FM": "pacific-islands", "MH": "pacific-islands",
    "GU": "pacific-islands", "NZ": "pacific-islands", "PG": "pacific-islands",
    # Caribbean
    "BS": "caribbean", "CU": "caribbean", "JM": "caribbean", "DO": "caribbean", "PR": "caribbean",
    "KY": "caribbean", "TC": "caribbean", "VG": "caribbean", "VI": "caribbean", "BB": "caribbean",
    "LC": "caribbean", "AG": "caribbean", "CW": "caribbean", "BQ": "caribbean", "AW": "caribbean",
    "BZ": "caribbean", "HN": "caribbean", "MX": "caribbean",
    # Central America
    "CR": "central-america", "PA": "central-america",
    # Mediterranean
    "ES": "mediterranean", "IT": "mediterranean", "GR": "mediterranean", "HR": "mediterranean",
    "MT": "mediterranean", "CY": "mediterranean", "TR": "mediterranean", "FR": "mediterranean",
    "ME": "mediterranean", "SI": "mediterranean",
    # Atlantic
    "PT": "atlantic", "GB": "atlantic", "IE": "atlantic", "NO": "atlantic", "IS": "atlantic",
    "US": "atlantic", "CA": "atlantic",
    # South America
    "BR": "south-america", "CO": "south-america", "VE": "south-america", "EC": "south-america",
    "PE": "south-america", "CL": "south-america", "AR": "south-america",
    # Africa
    "TZ": "africa", "KE": "africa", "MZ": "africa", "ZA": "africa", "SO": "africa",
}

# All valid country codes we care about
VALID_COUNTRIES = set(COUNTRY_TO_REGION.keys())


def slugify(text):
    """Convert to URL-safe ID."""
    text = text.lower().strip()
    text = re.sub(r'[^\w\s-]', '', text)
    text = re.sub(r'[\s_]+', '-', text)
    return text.strip('-')


def get_gbif_key(scientific_name):
    """Look up GBIF species key by scientific name."""
    url = f"{GBIF_API}/species/match"
    params = {"name": scientific_name, "strict": False}

    try:
        resp = requests.get(url, params=params, timeout=30)
        time.sleep(GBIF_DELAY)

        if resp.ok:
            data = resp.json()
            if data.get("matchType") != "NONE" and data.get("usageKey"):
                return data["usageKey"], data.get("canonicalName", scientific_name)
    except Exception as e:
        print(f"  Error looking up {scientific_name}: {e}")

    return None, None


def get_species_countries(gbif_key):
    """Get country occurrence counts for a species from GBIF."""
    url = f"{GBIF_API}/occurrence/search"
    params = {
        "speciesKey": gbif_key,
        "hasCoordinate": "true",
        "limit": 0,
        "facet": "country",  # Note: lowercase 'country', not 'countryCode'
        "facetLimit": 100,
    }

    try:
        resp = requests.get(url, params=params, timeout=60)
        time.sleep(GBIF_DELAY)

        if not resp.ok:
            return {}

        data = resp.json()
        country_counts = {}

        for facet in data.get("facets", []):
            if facet.get("field") == "COUNTRY":  # Field returns as 'COUNTRY'
                for count in facet.get("counts", []):
                    country_code = count["name"]
                    if country_code in VALID_COUNTRIES:
                        country_counts[country_code] = count["count"]

        return country_counts
    except Exception as e:
        print(f"  Error getting countries for {gbif_key}: {e}")
        return {}


def classify_likelihood(count, max_count):
    """Classify species likelihood based on occurrence count."""
    if max_count == 0:
        return "rare"
    ratio = count / max_count
    if ratio >= 0.1:
        return "common"
    elif ratio >= 0.01:
        return "occasional"
    return "rare"


def main():
    # Load species from CSV
    csv_path = DATA_DIR / "species_images_prompt.csv"
    species_list = []

    print(f"Loading species from {csv_path}...")
    with open(csv_path, 'r', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        for row in reader:
            species_list.append({
                "scientific_name": row["scientific_name"],
                "common_name": row["common_name"],
                "rarity": row["bucket"],
                "description": row["description"],
            })

    print(f"Loaded {len(species_list)} species")

    # Load cached GBIF keys from previous run if available
    gbif_cache = {}
    cache_path = EXPORT_DIR / "species_catalog_full.json"
    if cache_path.exists():
        try:
            with open(cache_path, 'r', encoding='utf-8') as f:
                cached_data = json.load(f)
                for sp in cached_data.get("species", []):
                    if sp.get("gbif_key"):
                        gbif_cache[sp["scientificName"]] = sp["gbif_key"]
            print(f"Loaded {len(gbif_cache)} cached GBIF keys")
        except Exception as e:
            print(f"Could not load cache: {e}")

    # Process each species
    species_countries = []  # junction table
    species_regions = []    # junction table
    species_catalog = []    # enriched species

    # Track for reverse lookups
    country_species = defaultdict(list)
    region_species = defaultdict(list)

    for i, sp in enumerate(species_list):
        scientific_name = sp["scientific_name"]
        common_name = sp["common_name"]

        if i % 20 == 0:
            print(f"Progress: {i}/{len(species_list)} - {scientific_name}")

        # Get GBIF key (use cache if available)
        if scientific_name in gbif_cache:
            gbif_key = gbif_cache[scientific_name]
            canonical_name = scientific_name
        else:
            gbif_key, canonical_name = get_gbif_key(scientific_name)

        if not gbif_key:
            print(f"  No GBIF match for: {scientific_name}")
            # Still add to catalog without location data
            species_id = f"species_{slugify(common_name)}"
            species_catalog.append({
                "id": species_id,
                "name": common_name,
                "scientificName": scientific_name,
                "rarity": sp["rarity"],
                "description": sp["description"],
                "gbif_key": None,
                "countries": [],
                "regions": [],
            })
            continue

        # Get country occurrences
        country_counts = get_species_countries(gbif_key)

        if not country_counts:
            # No occurrences in our target countries
            species_id = f"species_{slugify(common_name)}"
            species_catalog.append({
                "id": species_id,
                "name": common_name,
                "scientificName": scientific_name,
                "rarity": sp["rarity"],
                "description": sp["description"],
                "gbif_key": gbif_key,
                "countries": [],
                "regions": [],
            })
            continue

        # Generate species ID
        species_id = f"species_{slugify(common_name)}"

        # Calculate max count for likelihood
        max_count = max(country_counts.values()) if country_counts else 1

        # Build country associations
        countries = []
        regions_set = set()

        for country_code, count in country_counts.items():
            likelihood = classify_likelihood(count, max_count)

            # Add to junction table
            species_countries.append({
                "species_id": species_id,
                "country_id": country_code,
                "occurrence_count": count,
                "likelihood": likelihood,
            })

            countries.append(country_code)

            # Track reverse lookup
            country_species[country_code].append({
                "id": species_id,
                "name": common_name,
                "likelihood": likelihood,
                "occurrence_count": count,
            })

            # Map to region
            region_id = COUNTRY_TO_REGION.get(country_code)
            if region_id:
                regions_set.add(region_id)

        # Build region associations (aggregate from countries)
        for region_id in regions_set:
            # Get total count for this region
            region_count = sum(
                c for cc, c in country_counts.items()
                if COUNTRY_TO_REGION.get(cc) == region_id
            )
            likelihood = classify_likelihood(region_count, max_count * 3)  # adjust threshold for regions

            species_regions.append({
                "species_id": species_id,
                "region_id": region_id,
                "occurrence_count": region_count,
                "likelihood": likelihood,
            })

            region_species[region_id].append({
                "id": species_id,
                "name": common_name,
                "likelihood": likelihood,
                "occurrence_count": region_count,
            })

        # Add to catalog
        species_catalog.append({
            "id": species_id,
            "name": common_name,
            "scientificName": scientific_name,
            "rarity": sp["rarity"],
            "description": sp["description"],
            "gbif_key": gbif_key,
            "countries": sorted(countries),
            "regions": sorted(regions_set),
        })

    # Sort reverse lookups by occurrence count
    for country_code in country_species:
        country_species[country_code].sort(key=lambda x: x["occurrence_count"], reverse=True)
    for region_id in region_species:
        region_species[region_id].sort(key=lambda x: x["occurrence_count"], reverse=True)

    # Write outputs
    timestamp = datetime.now(timezone.utc).isoformat()

    # 1. Species-Countries junction table
    output_path = EXPORT_DIR / "species_countries.json"
    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump({
            "species_countries": species_countries,
            "metadata": {"generated_at": timestamp, "count": len(species_countries)}
        }, f, ensure_ascii=False, indent=2)
    print(f"Wrote {len(species_countries)} species-country links -> {output_path}")

    # 2. Species-Regions junction table
    output_path = EXPORT_DIR / "species_regions.json"
    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump({
            "species_regions": species_regions,
            "metadata": {"generated_at": timestamp, "count": len(species_regions)}
        }, f, ensure_ascii=False, indent=2)
    print(f"Wrote {len(species_regions)} species-region links -> {output_path}")

    # 3. Full species catalog
    output_path = EXPORT_DIR / "species_catalog_full.json"
    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump({
            "species": species_catalog,
            "metadata": {"generated_at": timestamp, "count": len(species_catalog)}
        }, f, ensure_ascii=False, indent=2)
    print(f"Wrote {len(species_catalog)} species -> {output_path}")

    # 4. Countries with species
    countries_path = EXPORT_DIR / "countries.json"
    with open(countries_path, 'r', encoding='utf-8') as f:
        countries_data = json.load(f)

    for country in countries_data.get("countries", []):
        country_id = country["id"]
        country["species"] = country_species.get(country_id, [])

    output_path = EXPORT_DIR / "countries_enriched.json"
    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump(countries_data, f, ensure_ascii=False, indent=2)
    print(f"Wrote countries with species -> {output_path}")

    # 5. Regions with species
    regions_path = EXPORT_DIR / "regions.json"
    with open(regions_path, 'r', encoding='utf-8') as f:
        regions_data = json.load(f)

    for region in regions_data.get("regions", []):
        region_id = region["id"]
        region["species"] = region_species.get(region_id, [])

    output_path = EXPORT_DIR / "regions_enriched.json"
    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump(regions_data, f, ensure_ascii=False, indent=2)
    print(f"Wrote regions with species -> {output_path}")

    # Summary
    print(f"\n=== Summary ===")
    print(f"Species processed: {len(species_catalog)}")
    print(f"Species with GBIF data: {len([s for s in species_catalog if s['gbif_key']])}")
    print(f"Species-country links: {len(species_countries)}")
    print(f"Species-region links: {len(species_regions)}")
    print(f"Countries with species: {len(country_species)}")
    print(f"Regions with species: {len(region_species)}")


if __name__ == "__main__":
    main()
