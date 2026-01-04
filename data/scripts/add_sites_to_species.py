#!/usr/bin/env python3
"""
Add site arrays to species catalog for bidirectional lookup.
Species → Sites (in addition to existing Species → Countries/Regions)

Usage: python3 add_sites_to_species.py
"""

import json
from pathlib import Path
from collections import defaultdict

DATA_DIR = Path(__file__).parent.parent
EXPORT_DIR = DATA_DIR / "export"


def main():
    # Load site-species links
    print("Loading site-species links...")
    with open(EXPORT_DIR / "site_species_full.json", 'r', encoding='utf-8') as f:
        links_data = json.load(f)

    # Build species -> sites mapping
    species_sites = defaultdict(list)
    for link in links_data.get("site_species", []):
        species_id = link["species_id"]
        species_sites[species_id].append({
            "site_id": link["site_id"],
            "likelihood": link.get("likelihood", "occasional"),
        })

    print(f"Built mapping for {len(species_sites)} species")

    # Load sites for name lookup
    print("Loading sites...")
    with open(EXPORT_DIR / "sites_enriched.json", 'r', encoding='utf-8') as f:
        sites_data = json.load(f)

    site_names = {}
    for site in sites_data.get("sites", []):
        site_id = site.get("id") or site.get("wikidataId")
        site_names[site_id] = {
            "name": site.get("name", "Unknown"),
            "region_id": site.get("region_id"),
            "country_id": site.get("country_id"),
        }

    # Load species catalog and add sites
    print("Loading species catalog...")
    with open(EXPORT_DIR / "species_catalog_full.json", 'r', encoding='utf-8') as f:
        catalog_data = json.load(f)

    species_with_sites = 0
    for species in catalog_data.get("species", []):
        species_id = species["id"]
        if species_id in species_sites:
            # Add site info with names
            sites = []
            for site_link in species_sites[species_id][:20]:  # Limit to 20 sites
                site_id = site_link["site_id"]
                site_info = site_names.get(site_id, {})
                sites.append({
                    "id": site_id,
                    "name": site_info.get("name", "Unknown"),
                    "region_id": site_info.get("region_id"),
                    "likelihood": site_link.get("likelihood"),
                })
            species["sites"] = sites
            species_with_sites += 1
        else:
            species["sites"] = []

    # Write updated catalog
    output_path = EXPORT_DIR / "species_catalog_full.json"
    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump(catalog_data, f, ensure_ascii=False, indent=2)

    print(f"\nUpdated {len(catalog_data['species'])} species")
    print(f"Species with sites: {species_with_sites}")
    print(f"Wrote -> {output_path}")


if __name__ == "__main__":
    main()
