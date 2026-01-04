#!/usr/bin/env python3
"""
Quick sample search to demonstrate the search-augmented approach.
Tests 15 diverse species including problem cases.
"""

import json
import sys
sys.path.insert(0, '/Users/finn/dev/umilog/scripts')

from search_species_descriptions import (
    wikipedia_search, worms_search, extract_morphology,
    get_body_class_from_taxonomy, BODY_CLASS_CONSTRAINTS,
    generate_grounded_prompt
)
import time

# Test species - including problem cases
TEST_SPECIES = [
    # The snail that was called a fish
    {"id": "test1", "name": "Ladder Cone", "scientificName": "Conus scalaris", "description": ""},
    # Spiny lobster (no claws!)
    {"id": "test2", "name": "Japanese spiny lobster", "scientificName": "Panulirus japonicus", "description": ""},
    # Garden eel
    {"id": "test3", "name": "Spotted Garden Eel", "scientificName": "Heteroconger hassi", "description": ""},
    # Nudibranch
    {"id": "test4", "name": "Sea Bunny", "scientificName": "Jorunna parva", "description": ""},
    # Mantis shrimp
    {"id": "test5", "name": "Peacock Mantis Shrimp", "scientificName": "Odontodactylus scyllarus", "description": ""},
    # Blue-ringed octopus
    {"id": "test6", "name": "Greater Blue-ringed Octopus", "scientificName": "Hapalochlaena lunulata", "description": ""},
    # Swimming crab with paddles
    {"id": "test7", "name": "Blue Swimming Crab", "scientificName": "Portunus pelagicus", "description": ""},
    # Bivalve
    {"id": "test8", "name": "Giant Clam", "scientificName": "Tridacna gigas", "description": ""},
    # Sea cucumber
    {"id": "test9", "name": "Prickly Redfish", "scientificName": "Thelenota ananas", "description": ""},
    # Jellyfish
    {"id": "test10", "name": "Moon Jellyfish", "scientificName": "Aurelia aurita", "description": ""},
]

def search_and_display(species: dict):
    """Search one species and display results."""
    name = species["name"]
    sci_name = species["scientificName"]

    print(f"\n{'='*70}")
    print(f"🔍 {name} ({sci_name})")
    print('='*70)

    result = {
        "id": species["id"],
        "name": name,
        "scientificName": sci_name,
    }

    # WoRMS search
    print("\n📚 WoRMS (taxonomy):")
    worms = worms_search(sci_name)
    if worms:
        print(f"   Phylum: {worms.get('phylum')}")
        print(f"   Class:  {worms.get('class')}")
        print(f"   Order:  {worms.get('order')}")
        print(f"   Family: {worms.get('family')}")
        result["taxonomy"] = worms
        result["body_class"] = get_body_class_from_taxonomy(worms)
        print(f"\n   → Body class: {result['body_class']}")

        # Show constraints
        constraints = BODY_CLASS_CONSTRAINTS.get(result["body_class"], {})
        if constraints:
            print(f"   → Type: {constraints.get('type')}")
            print(f"   → Constraints: {constraints.get('constraints')[:100]}...")
    else:
        print("   (no data)")
        result["body_class"] = "unknown"

    time.sleep(0.5)

    # Wikipedia search
    print("\n📖 Wikipedia:")
    wiki = wikipedia_search(sci_name)
    if wiki:
        result["wikipedia_extract"] = wiki
        morph = extract_morphology(wiki)
        result["extracted_morphology"] = morph

        print(f"   First 200 chars: {wiki[:200]}...")
        if morph.get("colors"):
            print(f"   Colors found: {morph['colors']}")
        if morph.get("size"):
            print(f"   Size: {morph['size']}")
        if morph.get("body_type"):
            print(f"   Body type detected: {morph['body_type']}")
    else:
        print("   (no data)")

    time.sleep(0.5)

    # Generate prompt
    prompt = generate_grounded_prompt(result)

    print("\n" + "-"*70)
    print("📝 GENERATED PROMPT:")
    print("-"*70)
    print(prompt)

    return result


def main():
    print("="*70)
    print("SEARCH-AUGMENTED PROMPT GENERATION - SAMPLE TEST")
    print("Testing with 10 diverse species including known problem cases")
    print("="*70)

    results = []
    for species in TEST_SPECIES:
        try:
            result = search_and_display(species)
            results.append(result)
        except Exception as e:
            print(f"ERROR: {e}")

        print("\n" + "."*70)
        time.sleep(0.5)

    # Summary
    print("\n" + "="*70)
    print("SUMMARY")
    print("="*70)

    for r in results:
        body_class = r.get("body_class", "unknown")
        taxonomy = r.get("taxonomy", {})
        phylum = taxonomy.get("phylum", "?")
        print(f"  {r['name']:30} → {body_class:20} ({phylum})")


if __name__ == "__main__":
    main()
