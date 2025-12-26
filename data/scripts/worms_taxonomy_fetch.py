#!/usr/bin/env python3
"""
Fetch marine species taxonomy from WoRMS (World Register of Marine Species).
Builds family-level taxonomy for common diving species.

Usage: python3 worms_taxonomy_fetch.py <output_json>
Example: python3 worms_taxonomy_fetch.py raw/worms_families.json

API: https://www.marinespecies.org/rest/
Rate limit: 1 request/second
"""

import sys
import json
import time
import requests
from datetime import datetime

WORMS_API = "https://www.marinespecies.org/rest"

# Key families for recreational diving
TARGET_FAMILIES = [
    # Sharks
    {"scientific": "Carcharhinidae", "common": "Requiem Sharks", "category": "Fish"},
    {"scientific": "Sphyrnidae", "common": "Hammerhead Sharks", "category": "Fish"},
    {"scientific": "Lamnidae", "common": "Mackerel Sharks", "category": "Fish"},
    {"scientific": "Orectolobidae", "common": "Wobbegongs", "category": "Fish"},
    {"scientific": "Ginglymostomatidae", "common": "Nurse Sharks", "category": "Fish"},
    {"scientific": "Rhincodontidae", "common": "Whale Sharks", "category": "Fish"},
    # Rays
    {"scientific": "Mobulidae", "common": "Manta Rays", "category": "Fish"},
    {"scientific": "Myliobatidae", "common": "Eagle Rays", "category": "Fish"},
    {"scientific": "Dasyatidae", "common": "Stingrays", "category": "Fish"},
    # Popular reef fish
    {"scientific": "Labridae", "common": "Wrasses", "category": "Fish"},
    {"scientific": "Serranidae", "common": "Groupers", "category": "Fish"},
    {"scientific": "Chaetodontidae", "common": "Butterflyfish", "category": "Fish"},
    {"scientific": "Pomacanthidae", "common": "Angelfish", "category": "Fish"},
    {"scientific": "Pomacentridae", "common": "Damselfish", "category": "Fish"},
    {"scientific": "Scaridae", "common": "Parrotfish", "category": "Fish"},
    {"scientific": "Acanthuridae", "common": "Surgeonfish", "category": "Fish"},
    {"scientific": "Balistidae", "common": "Triggerfish", "category": "Fish"},
    {"scientific": "Tetraodontidae", "common": "Pufferfish", "category": "Fish"},
    {"scientific": "Muraenidae", "common": "Moray Eels", "category": "Fish"},
    {"scientific": "Scorpaenidae", "common": "Scorpionfish", "category": "Fish"},
    {"scientific": "Syngnathidae", "common": "Seahorses & Pipefish", "category": "Fish"},
    {"scientific": "Antennariidae", "common": "Frogfish", "category": "Fish"},
    {"scientific": "Lutjanidae", "common": "Snappers", "category": "Fish"},
    {"scientific": "Carangidae", "common": "Jacks", "category": "Fish"},
    {"scientific": "Ephippidae", "common": "Batfish", "category": "Fish"},
    # Turtles
    {"scientific": "Cheloniidae", "common": "Sea Turtles", "category": "Reptile"},
    {"scientific": "Dermochelyidae", "common": "Leatherback Turtles", "category": "Reptile"},
    # Mammals
    {"scientific": "Delphinidae", "common": "Dolphins", "category": "Mammal"},
    {"scientific": "Dugongidae", "common": "Dugongs", "category": "Mammal"},
    {"scientific": "Trichechidae", "common": "Manatees", "category": "Mammal"},
    {"scientific": "Phocidae", "common": "True Seals", "category": "Mammal"},
    # Cephalopods
    {"scientific": "Octopodidae", "common": "Octopuses", "category": "Invertebrate"},
    {"scientific": "Sepiidae", "common": "Cuttlefish", "category": "Invertebrate"},
    # Nudibranchs
    {"scientific": "Chromodorididae", "common": "Chromodorid Nudibranchs", "category": "Invertebrate"},
    {"scientific": "Phyllidiidae", "common": "Phyllidiid Nudibranchs", "category": "Invertebrate"},
    {"scientific": "Flabellinidae", "common": "Flabellinid Nudibranchs", "category": "Invertebrate"},
    # Crustaceans
    {"scientific": "Stenopodidae", "common": "Cleaner Shrimp", "category": "Invertebrate"},
    {"scientific": "Palaemonidae", "common": "Palaemonid Shrimp", "category": "Invertebrate"},
    {"scientific": "Palinuridae", "common": "Spiny Lobsters", "category": "Invertebrate"},
    # Corals
    {"scientific": "Acroporidae", "common": "Staghorn Corals", "category": "Coral"},
    {"scientific": "Pocilloporidae", "common": "Cauliflower Corals", "category": "Coral"},
    {"scientific": "Poritidae", "common": "Porites Corals", "category": "Coral"},
    {"scientific": "Fungiidae", "common": "Mushroom Corals", "category": "Coral"},
    {"scientific": "Faviidae", "common": "Brain Corals", "category": "Coral"},
    {"scientific": "Dendrophylliidae", "common": "Dendrophyllia Corals", "category": "Coral"},
    # Echinoderms
    {"scientific": "Holothuriidae", "common": "Sea Cucumbers", "category": "Invertebrate"},
    {"scientific": "Ophidiasteridae", "common": "Sea Stars", "category": "Invertebrate"},
    {"scientific": "Diadematidae", "common": "Sea Urchins", "category": "Invertebrate"},
    {"scientific": "Crinoidea", "common": "Feather Stars", "category": "Invertebrate"},
]


def fetch_aphia_by_name(scientific_name):
    """Fetch AphiaID for a taxon name from WoRMS."""
    url = f"{WORMS_API}/AphiaRecordsByName/{scientific_name}"
    params = {"like": "false", "marine_only": "true"}

    try:
        resp = requests.get(url, params=params, timeout=30)
        time.sleep(1.1)  # Rate limit

        if resp.status_code == 204:  # No content
            return None
        if not resp.ok:
            print(f"  Error fetching {scientific_name}: {resp.status_code}")
            return None

        records = resp.json()
        if records and len(records) > 0:
            return records[0]
        return None
    except Exception as e:
        print(f"  Exception fetching {scientific_name}: {e}")
        return None


def fetch_children(aphia_id, limit=50):
    """Fetch child taxa (species) for a family."""
    url = f"{WORMS_API}/AphiaChildrenByAphiaID/{aphia_id}"
    params = {"marine_only": "true", "offset": 0}

    all_children = []
    try:
        while True:
            resp = requests.get(url, params=params, timeout=30)
            time.sleep(1.1)

            if resp.status_code == 204 or not resp.ok:
                break

            children = resp.json()
            if not children:
                break

            all_children.extend(children)
            if len(children) < 50 or len(all_children) >= limit:
                break

            params["offset"] += 50

        return all_children[:limit]
    except Exception as e:
        print(f"  Exception fetching children for {aphia_id}: {e}")
        return []


def main():
    if len(sys.argv) < 2:
        print("Usage: worms_taxonomy_fetch.py <output_json>")
        sys.exit(1)

    output_file = sys.argv[1]
    families = []
    species_list = []

    print(f"Fetching taxonomy for {len(TARGET_FAMILIES)} families...")

    for i, family_def in enumerate(TARGET_FAMILIES):
        scientific = family_def["scientific"]
        common = family_def["common"]
        category = family_def["category"]

        print(f"[{i+1}/{len(TARGET_FAMILIES)}] {scientific} ({common})...")

        # Fetch family record
        record = fetch_aphia_by_name(scientific)
        if not record:
            print(f"  Not found: {scientific}")
            continue

        aphia_id = record.get("AphiaID")
        family_id = scientific.lower()

        family = {
            "id": family_id,
            "name": common,
            "scientific_name": scientific,
            "category": category,
            "worms_aphia_id": aphia_id,
            "rank": record.get("rank", "Family"),
            "status": record.get("status", "accepted"),
        }
        families.append(family)

        # Fetch some species in this family
        children = fetch_children(aphia_id, limit=30)
        for child in children:
            if child.get("rank") == "Species" and child.get("status") == "accepted":
                species_list.append({
                    "id": f"species_{child.get('AphiaID')}",
                    "name": child.get("vernacular") or child.get("scientificname", "").split()[-1].title(),
                    "scientific_name": child.get("scientificname"),
                    "family_id": family_id,
                    "category": category,
                    "worms_aphia_id": child.get("AphiaID"),
                    "authority": child.get("authority"),
                })

        print(f"  Found {len(children)} species")

    # Write output
    output = {
        "families": families,
        "species": species_list,
        "metadata": {
            "source": "WoRMS",
            "api": WORMS_API,
            "fetched_at": datetime.utcnow().isoformat() + "Z",
            "family_count": len(families),
            "species_count": len(species_list),
        }
    }

    with open(output_file, 'w', encoding='utf-8') as f:
        json.dump(output, f, ensure_ascii=False, indent=2)

    print(f"\nWrote {len(families)} families, {len(species_list)} species -> {output_file}")


if __name__ == "__main__":
    main()
