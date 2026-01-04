#!/usr/bin/env python3
"""
Enrich sites with species based on their region.
Each site gets the species array from its region.

Usage: python3 enrich_sites_with_species.py
Inputs: sites_curated.json, regions_enriched.json
Outputs: sites_enriched.json
"""

import json
from pathlib import Path

DATA_DIR = Path(__file__).parent.parent
EXPORT_DIR = DATA_DIR / "export"


def main():
    # Load regions with species
    print("Loading regions with species...")
    with open(EXPORT_DIR / "regions_enriched.json", 'r', encoding='utf-8') as f:
        regions_data = json.load(f)

    region_species = {}
    for region in regions_data.get("regions", []):
        region_id = region["id"]
        species = region.get("species", [])
        region_species[region_id] = species
        print(f"  {region['name']}: {len(species)} species")

    # Load curated sites
    print("\nLoading sites...")
    with open(EXPORT_DIR / "sites_curated.json", 'r', encoding='utf-8') as f:
        sites_data = json.load(f)

    sites = sites_data.get("sites", [])
    print(f"Loaded {len(sites)} sites")

    # Enrich each site with species from its region
    sites_with_species = 0
    total_species_links = 0

    for site in sites:
        region_id = site.get("region_id")
        if region_id and region_id in region_species:
            # Get top species for this region (limit to 50 most common)
            site["species"] = region_species[region_id][:50]
            sites_with_species += 1
            total_species_links += len(site["species"])
        else:
            site["species"] = []

    # Write enriched sites
    output_path = EXPORT_DIR / "sites_enriched.json"
    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump({"sites": sites}, f, ensure_ascii=False, indent=2)

    print(f"\nWrote {len(sites)} sites -> {output_path}")
    print(f"Sites with species: {sites_with_species}")
    print(f"Total species links: {total_species_links}")

    # Also create a site_species junction table from the enriched data
    site_species_links = []
    for site in sites:
        site_id = site.get("id") or site.get("wikidataId")
        for sp in site.get("species", []):
            site_species_links.append({
                "site_id": site_id,
                "species_id": sp["id"],
                "species_name": sp["name"],
                "likelihood": sp.get("likelihood", "occasional"),
                "source": "region_inference",
            })

    output_path = EXPORT_DIR / "site_species_full.json"
    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump({
            "site_species": site_species_links,
            "metadata": {
                "count": len(site_species_links),
                "method": "Region-based inference from GBIF occurrence data"
            }
        }, f, ensure_ascii=False, indent=2)

    print(f"\nWrote {len(site_species_links)} site-species links -> {output_path}")


if __name__ == "__main__":
    main()
