#!/usr/bin/env python3
"""
Merge species data from WoRMS and GBIF into unified seed format.
Produces species_catalog.json and families_catalog.json for app seeding.

Usage: python3 species_to_seed.py <worms_json> <gbif_json> <output_dir>
Example: python3 species_to_seed.py raw/worms_families.json raw/gbif_species.json export/
"""

import sys
import json
from datetime import datetime
from collections import defaultdict

# Rarity classification
def classify_rarity(gbif_occurrences):
    """Classify rarity based on GBIF occurrence count."""
    if gbif_occurrences >= 1000:
        return "Common"
    elif gbif_occurrences >= 100:
        return "Uncommon"
    elif gbif_occurrences >= 10:
        return "Rare"
    else:
        return "Very Rare"


def main():
    if len(sys.argv) < 4:
        print("Usage: species_to_seed.py <worms_json> <gbif_json> <output_dir>")
        sys.exit(1)

    worms_file = sys.argv[1]
    gbif_file = sys.argv[2]
    output_dir = sys.argv[3].rstrip('/')

    # Load WoRMS data
    with open(worms_file, 'r', encoding='utf-8') as f:
        worms_data = json.load(f)
    worms_families = worms_data.get('families', [])
    worms_species = worms_data.get('species', [])

    # Load GBIF data
    with open(gbif_file, 'r', encoding='utf-8') as f:
        gbif_data = json.load(f)
    gbif_species = gbif_data.get('species', [])

    print(f"WoRMS: {len(worms_families)} families, {len(worms_species)} species")
    print(f"GBIF: {len(gbif_species)} species")

    # Build GBIF lookup by scientific name
    gbif_by_scientific = {}
    for sp in gbif_species:
        scientific = sp.get('scientific_name', '').lower().strip()
        canonical = sp.get('canonical_name', '').lower().strip()
        if scientific:
            gbif_by_scientific[scientific] = sp
        if canonical and canonical != scientific:
            gbif_by_scientific[canonical] = sp

    # Process families
    families_out = []
    for fam in worms_families:
        families_out.append({
            "id": fam["id"],
            "name": fam["name"],
            "scientific_name": fam["scientific_name"],
            "category": fam["category"],
            "worms_aphia_id": fam.get("worms_aphia_id"),
        })

    # Process species - merge WoRMS + GBIF
    species_out = []
    seen_ids = set()

    # First, add WoRMS species with GBIF enrichment
    for sp in worms_species:
        species_id = sp["id"]
        if species_id in seen_ids:
            continue
        seen_ids.add(species_id)

        scientific = sp.get("scientific_name", "").lower().strip()
        gbif_match = gbif_by_scientific.get(scientific)

        # Determine rarity
        if gbif_match:
            rarity = gbif_match.get("rarity", classify_rarity(gbif_match.get("total_occurrences", 0)))
            gbif_key = gbif_match.get("gbif_key")
            regions = gbif_match.get("regions", [])
        else:
            rarity = "Uncommon"  # Default for WoRMS-only species
            gbif_key = None
            regions = []

        species_out.append({
            "id": species_id,
            "name": sp.get("name", sp.get("scientific_name", "").split()[-1].title()),
            "scientificName": sp.get("scientific_name"),
            "category": sp.get("category"),
            "rarity": rarity,
            "familyId": sp.get("family_id"),
            "regions": regions,
            "wormsAphiaId": sp.get("worms_aphia_id"),
            "gbifKey": gbif_key,
        })

    # Add GBIF-only species that aren't in WoRMS
    for sp in gbif_species:
        gbif_key = sp.get("gbif_key")
        species_id = f"gbif_{gbif_key}"

        if species_id in seen_ids:
            continue
        seen_ids.add(species_id)

        # Try to match family
        family = sp.get("family", "").lower()
        family_id = family if any(f["id"] == family for f in families_out) else None

        species_out.append({
            "id": species_id,
            "name": sp.get("name"),
            "scientificName": sp.get("scientific_name"),
            "category": sp.get("category"),
            "rarity": sp.get("rarity", "Uncommon"),
            "familyId": family_id,
            "regions": sp.get("regions", []),
            "gbifKey": gbif_key,
        })

    # Sort by name
    species_out.sort(key=lambda x: x.get("name", "").lower())
    families_out.sort(key=lambda x: x.get("name", "").lower())

    # Write families
    with open(f"{output_dir}/families_catalog.json", 'w', encoding='utf-8') as f:
        json.dump({
            "families": families_out,
            "metadata": {
                "generated_at": datetime.utcnow().isoformat() + "Z",
                "count": len(families_out),
            }
        }, f, ensure_ascii=False, indent=2)

    # Write species
    with open(f"{output_dir}/species_catalog_v2.json", 'w', encoding='utf-8') as f:
        json.dump({
            "species": species_out,
            "metadata": {
                "generated_at": datetime.utcnow().isoformat() + "Z",
                "count": len(species_out),
                "sources": ["WoRMS", "GBIF"],
            }
        }, f, ensure_ascii=False, indent=2)

    print(f"\nGenerated:")
    print(f"  {len(families_out)} families -> {output_dir}/families_catalog.json")
    print(f"  {len(species_out)} species -> {output_dir}/species_catalog_v2.json")

    # Category breakdown
    category_counts = defaultdict(int)
    for sp in species_out:
        category_counts[sp.get("category", "Unknown")] += 1

    print("\nSpecies by category:")
    for cat, count in sorted(category_counts.items()):
        print(f"  {cat}: {count}")


if __name__ == "__main__":
    main()
