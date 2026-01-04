#!/usr/bin/env python3
"""
Merge v1 curated species catalog with v2 GBIF species catalog.

This script:
1. Loads v1 curated species (35 species with good names)
2. Loads v2 GBIF species (16 species with gbif_key)
3. Merges by scientific name, keeping best of both
4. Links species to families using scientific name matching
5. Outputs combined catalog with ~50+ species

Usage:
    python3 merge_species_catalogs.py <v1_catalog> <v2_catalog> <families_catalog> <output>

Example:
    python3 merge_species_catalogs.py \
        Resources/SeedData/species_catalog.json \
        data/export/species_catalog_v2.json \
        data/export/families_catalog.json \
        data/export/species_catalog_merged.json
"""

import json
import sys
from pathlib import Path
from datetime import datetime, timezone


# Species -> Family mapping based on scientific name patterns
# Format: scientific_name_pattern -> family_id
SPECIES_FAMILY_MAP = {
    # Sharks (Carcharhinidae - Requiem Sharks)
    "Carcharhinus": "carcharhinidae",
    "Triaenodon": "carcharhinidae",

    # Sharks (Sphyrnidae - Hammerheads)
    "Sphyrna": "sphyrnidae",

    # Sharks (Ginglymostomatidae - Nurse Sharks)
    "Ginglymostoma": "ginglymostomatidae",

    # Sharks (Rhincodontidae - Whale Sharks)
    "Rhincodon": "rhincodontidae",

    # Rays (Mobulidae - Manta Rays)
    "Mobula": "mobulidae",
    "Manta": "mobulidae",

    # Rays (Myliobatidae - Eagle Rays)
    "Aetobatus": "myliobatidae",

    # Rays (Dasyatidae - Stingrays)
    "Taeniura": "dasyatidae",
    "Dasyatis": "dasyatidae",

    # Turtles (Cheloniidae - Sea Turtles)
    "Chelonia": "cheloniidae",
    "Eretmochelys": "cheloniidae",
    "Caretta": "cheloniidae",

    # Eels (Muraenidae - Moray Eels)
    "Gymnothorax": "muraenidae",

    # Groupers (Serranidae)
    "Cephalopholis": "serranidae",
    "Epinephelus": "serranidae",
    "Plectropomus": "serranidae",

    # Wrasses (Labridae)
    "Cheilinus": "labridae",

    # Scorpionfish (Scorpaenidae - includes Lionfish)
    "Pterois": "scorpaenidae",

    # Frogfish (Antennariidae)
    "Antennarius": "antennariidae",

    # Seahorses (Syngnathidae)
    "Hippocampus": "syngnathidae",

    # Parrotfish (Scaridae)
    "Bolbometopon": "scaridae",

    # Jacks (Carangidae)
    "Caranx": "carangidae",

    # Barracuda (Sphyraenidae - not in families list, skip)

    # Sunfish (Molidae - not in families list, skip)

    # Tuna (Scombridae - not in families list, skip)

    # Dolphins (Delphinidae)
    "Tursiops": "delphinidae",

    # Octopus (Octopodidae)
    "Octopus": "octopodidae",
    "Hapalochlaena": "octopodidae",

    # Cuttlefish (Sepiidae)
    "Sepia": "sepiidae",

    # Lobsters (Palinuridae)
    "Panulirus": "palinuridae",

    # Damselfish/Clownfish (Pomacentridae)
    "Amphiprion": "pomacentridae",

    # Nudibranchs (Hexabranchidae - Spanish Dancer, not in list)
    # Use chromodorididae as fallback
    "Hexabranchus": "chromodorididae",

    # Sea snakes (Hydrophiidae - not in families list, skip)

    # Angelfish (Pomacanthidae)
    "Holacanthus": "pomacanthidae",
}


def normalize_scientific_name(name: str) -> str:
    """Normalize scientific name for matching."""
    # Remove author citations (text in parentheses or after comma)
    if "(" in name:
        name = name.split("(")[0].strip()
    if "," in name:
        name = name.split(",")[0].strip()
    return name.strip()


def get_genus(scientific_name: str) -> str:
    """Extract genus from scientific name."""
    normalized = normalize_scientific_name(scientific_name)
    parts = normalized.split()
    return parts[0] if parts else ""


def match_family(scientific_name: str, families: list) -> str | None:
    """Match species to family based on scientific name."""
    genus = get_genus(scientific_name)

    # Direct genus mapping
    if genus in SPECIES_FAMILY_MAP:
        family_id = SPECIES_FAMILY_MAP[genus]
        # Verify family exists
        if any(f["id"] == family_id for f in families):
            return family_id

    return None


def merge_species(v1_species: list, v2_species: list, families: list) -> list:
    """Merge v1 and v2 species catalogs."""
    merged = {}

    # Index v2 species by normalized scientific name for GBIF key lookup
    v2_by_sciname = {}
    for sp in v2_species:
        sciname = normalize_scientific_name(sp.get("scientificName", ""))
        if sciname:
            v2_by_sciname[sciname.lower()] = sp

    # Process v1 species (curated, higher quality names)
    for sp in v1_species:
        sciname = normalize_scientific_name(sp.get("scientificName", ""))
        sciname_lower = sciname.lower()

        # Start with v1 data
        merged_sp = {
            "id": sp["id"],
            "name": sp["name"],
            "scientificName": sciname,
            "category": sp.get("category", "Fish"),
            "rarity": sp.get("rarity", "Common"),
            "regions": sp.get("regions", []),
            "imageUrl": sp.get("imageUrl"),
            "familyId": None,
            "gbifKey": None,
        }

        # Check if v2 has this species (by scientific name match)
        if sciname_lower in v2_by_sciname:
            v2_sp = v2_by_sciname[sciname_lower]
            merged_sp["gbifKey"] = v2_sp.get("gbifKey")
            # Merge regions
            v2_regions = v2_sp.get("regions", [])
            if v2_regions:
                # Combine unique regions
                all_regions = set(merged_sp["regions"]) | set(v2_regions)
                merged_sp["regions"] = sorted(list(all_regions))

        # Match to family
        merged_sp["familyId"] = match_family(sciname, families)

        merged[sciname_lower] = merged_sp

    # Add v2 species not in v1
    for sp in v2_species:
        sciname = normalize_scientific_name(sp.get("scientificName", ""))
        sciname_lower = sciname.lower()

        if sciname_lower not in merged:
            # Skip freshwater/non-marine species from v2
            name = sp.get("name", "").lower()
            if any(x in name for x in ["chub", "minnow", "gudgeon", "clausi"]):
                continue

            merged_sp = {
                "id": sp.get("id", f"species_{sciname.replace(' ', '_').lower()}"),
                "name": sp.get("name", sciname),
                "scientificName": sciname,
                "category": sp.get("category", "Fish"),
                "rarity": sp.get("rarity", "Common"),
                "regions": sp.get("regions", []),
                "imageUrl": sp.get("imageUrl"),
                "familyId": match_family(sciname, families),
                "gbifKey": sp.get("gbifKey"),
            }
            merged[sciname_lower] = merged_sp

    return list(merged.values())


def normalize_regions(species: list) -> list:
    """Normalize region names to match regions.json IDs."""
    region_map = {
        "Red Sea": "red-sea",
        "Pacific": "pacific-islands",
        "Caribbean": "caribbean",
        "Southeast Asia": "southeast-asia",
        "Mediterranean": "mediterranean",
        "Australia": "australia",
        "Indian Ocean": "indian-ocean",
        "Japan": "japan",
        "atlantic": "atlantic",
        "australia": "australia",
        "caribbean": "caribbean",
        "indian-ocean": "indian-ocean",
        "mediterranean": "mediterranean",
    }

    for sp in species:
        normalized = []
        for region in sp.get("regions", []):
            mapped = region_map.get(region, region.lower().replace(" ", "-"))
            normalized.append(mapped)
        sp["regions"] = sorted(list(set(normalized)))

    return species


def main():
    if len(sys.argv) != 5:
        print(__doc__)
        sys.exit(1)

    v1_path = Path(sys.argv[1])
    v2_path = Path(sys.argv[2])
    families_path = Path(sys.argv[3])
    output_path = Path(sys.argv[4])

    # Load catalogs
    print(f"Loading v1 catalog: {v1_path}")
    with open(v1_path) as f:
        v1_data = json.load(f)
    v1_species = v1_data.get("species", [])
    print(f"  {len(v1_species)} curated species")

    print(f"Loading v2 catalog: {v2_path}")
    with open(v2_path) as f:
        v2_data = json.load(f)
    v2_species = v2_data.get("species", [])
    print(f"  {len(v2_species)} GBIF species")

    print(f"Loading families: {families_path}")
    with open(families_path) as f:
        families_data = json.load(f)
    families = families_data.get("families", [])
    print(f"  {len(families)} families")

    # Merge species
    print("\nMerging species catalogs...")
    merged = merge_species(v1_species, v2_species, families)
    print(f"  {len(merged)} total species after merge")

    # Normalize regions
    merged = normalize_regions(merged)

    # Count species with family links
    with_family = sum(1 for sp in merged if sp.get("familyId"))
    print(f"  {with_family} species linked to families")

    # Count species with GBIF keys
    with_gbif = sum(1 for sp in merged if sp.get("gbifKey"))
    print(f"  {with_gbif} species with GBIF keys")

    # Output
    output = {
        "species": merged,
        "metadata": {
            "generated_at": datetime.now(timezone.utc).isoformat(),
            "v1_source": str(v1_path),
            "v2_source": str(v2_path),
            "total_species": len(merged),
            "species_with_family": with_family,
            "species_with_gbif": with_gbif,
        }
    }

    output_path.parent.mkdir(parents=True, exist_ok=True)
    with open(output_path, "w") as f:
        json.dump(output, f, indent=2)

    print(f"\nOutput written to: {output_path}")

    # Print summary by category
    categories = {}
    for sp in merged:
        cat = sp.get("category", "Unknown")
        categories[cat] = categories.get(cat, 0) + 1

    print("\nSpecies by category:")
    for cat, count in sorted(categories.items(), key=lambda x: -x[1]):
        print(f"  {cat}: {count}")


if __name__ == "__main__":
    main()
