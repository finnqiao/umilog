#!/usr/bin/env python3
"""
Search-Augmented Species Description Generator

Uses FREE sources to get accurate morphological descriptions:
1. Wikipedia API (free, no key needed)
2. WoRMS API (World Register of Marine Species - free)

Saves progress incrementally so you can resume if interrupted.
"""

import json
import time
import re
import urllib.request
import urllib.parse
from pathlib import Path
from typing import Optional

# Configuration
INPUT_FILE = Path("/Users/finn/dev/umilog/data/export/species_catalog_full.json")
OUTPUT_FILE = Path("/Users/finn/dev/umilog/data/export/species_descriptions_searched.json")
PROGRESS_FILE = Path("/Users/finn/dev/umilog/data/export/search_progress.json")

# Rate limiting (be nice to free APIs)
DELAY_BETWEEN_REQUESTS = 0.5  # seconds


def wikipedia_search(scientific_name: str) -> Optional[str]:
    """
    Search Wikipedia for species description.
    Uses the free Wikipedia API - no key needed.
    """
    try:
        # First, search for the page
        search_url = (
            f"https://en.wikipedia.org/w/api.php?"
            f"action=query&list=search&srsearch={urllib.parse.quote(scientific_name)}"
            f"&format=json&srlimit=1"
        )

        # Add proper User-Agent to avoid 403 errors
        headers = {
            "User-Agent": "UmiLog Species Catalog/1.0 (https://github.com/umilog; contact@example.com) Python/3"
        }
        req = urllib.request.Request(search_url, headers=headers)
        with urllib.request.urlopen(req, timeout=10) as response:
            data = json.loads(response.read().decode())

        if not data.get("query", {}).get("search"):
            return None

        # Get the page title
        title = data["query"]["search"][0]["title"]

        # Now get the extract (summary) of the page
        extract_url = (
            f"https://en.wikipedia.org/w/api.php?"
            f"action=query&titles={urllib.parse.quote(title)}"
            f"&prop=extracts&exintro=1&explaintext=1&format=json"
        )

        req = urllib.request.Request(extract_url, headers=headers)
        with urllib.request.urlopen(req, timeout=10) as response:
            data = json.loads(response.read().decode())

        pages = data.get("query", {}).get("pages", {})
        for page_id, page_data in pages.items():
            if page_id != "-1":
                extract = page_data.get("extract", "")
                if extract and len(extract) > 50:
                    return extract[:2000]  # Limit length

        return None

    except Exception as e:
        print(f"  Wikipedia error for {scientific_name}: {e}")
        return None


def worms_search(scientific_name: str) -> Optional[dict]:
    """
    Search WoRMS (World Register of Marine Species) for taxonomic info.
    Free API, no key needed.
    """
    try:
        # Search by scientific name
        url = (
            f"https://www.marinespecies.org/rest/AphiaRecordsByMatchNames?"
            f"scientificnames[]={urllib.parse.quote(scientific_name)}&marine_only=true"
        )

        req = urllib.request.Request(url, headers={"Accept": "application/json"})
        with urllib.request.urlopen(req, timeout=10) as response:
            data = json.loads(response.read().decode())

        if data and isinstance(data, list) and len(data) > 0:
            if isinstance(data[0], list) and len(data[0]) > 0:
                record = data[0][0]
                return {
                    "kingdom": record.get("kingdom"),
                    "phylum": record.get("phylum"),
                    "class": record.get("class"),
                    "order": record.get("order"),
                    "family": record.get("family"),
                    "genus": record.get("genus"),
                    "rank": record.get("rank"),
                    "valid_name": record.get("valid_name"),
                    "authority": record.get("authority"),
                }

        return None

    except Exception as e:
        print(f"  WoRMS error for {scientific_name}: {e}")
        return None


def extract_morphology(wikipedia_text: str) -> dict:
    """
    Extract key morphological features from Wikipedia text.
    Returns structured data about body, color, size, etc.
    """
    text_lower = wikipedia_text.lower()
    result = {}

    # Size patterns
    size_patterns = [
        r"(?:grows? to|reaches?|up to|maximum|length of|can grow|averaging?)\s*(\d+[\d.,]*)\s*(cm|mm|m|inch|feet|ft)",
        r"(\d+[\d.,]*)\s*(cm|mm|m)\s*(?:in length|long|wide|across)",
    ]
    for pattern in size_patterns:
        match = re.search(pattern, text_lower)
        if match:
            result["size"] = f"{match.group(1)} {match.group(2)}"
            break

    # Color patterns
    color_words = ["white", "black", "red", "orange", "yellow", "green", "blue", "purple",
                   "brown", "grey", "gray", "pink", "cream", "tan", "olive", "silver",
                   "golden", "iridescent", "translucent", "transparent", "mottled",
                   "striped", "spotted", "banded"]
    found_colors = []
    for color in color_words:
        if color in text_lower:
            found_colors.append(color)
    if found_colors:
        result["colors"] = found_colors[:5]  # Top 5

    # Body type detection
    body_types = {
        "shell": ["shell", "conch", "spiral", "gastropod", "bivalve", "mollusk", "mollusc"],
        "crab": ["crab", "carapace", "chelipeds", "claws", "decapod"],
        "shrimp": ["shrimp", "prawn", "rostrum", "pleopods", "caridean"],
        "lobster": ["lobster", "spiny lobster", "crayfish"],
        "octopus": ["octopus", "cephalopod", "tentacles", "suckers", "mantle"],
        "squid": ["squid", "cuttlefish", "gladius", "pen"],
        "fish": ["fish", "fins", "scales", "gills", "lateral line"],
        "shark": ["shark", "cartilaginous", "dermal denticles"],
        "ray": ["ray", "skate", "disc", "pectoral fins"],
        "turtle": ["turtle", "tortoise", "carapace", "plastron", "flipper"],
        "nudibranch": ["nudibranch", "sea slug", "rhinophores", "cerata", "branchial"],
        "jellyfish": ["jellyfish", "medusa", "bell", "tentacles", "cnidarian"],
        "starfish": ["starfish", "sea star", "asteroid", "arms", "tube feet"],
        "urchin": ["urchin", "echinoid", "spines", "test"],
        "cucumber": ["sea cucumber", "holothurian", "tube feet"],
        "worm": ["worm", "polychaete", "annelid", "tube worm"],
        "coral": ["coral", "polyp", "colony"],
        "anemone": ["anemone", "actiniarian"],
        "sponge": ["sponge", "porifera"],
    }

    for body_type, keywords in body_types.items():
        for keyword in keywords:
            if keyword in text_lower:
                result["body_type"] = body_type
                break
        if "body_type" in result:
            break

    # Extract first few sentences that often contain description
    sentences = wikipedia_text.split(". ")
    description_sentences = []
    for sentence in sentences[:5]:
        # Look for sentences with descriptive content
        if any(word in sentence.lower() for word in
               ["is a", "are a", "has", "have", "grows", "reach", "characterized",
                "known for", "distinguished", "features", "color", "pattern"]):
            description_sentences.append(sentence.strip())

    if description_sentences:
        result["description"] = ". ".join(description_sentences[:3])

    return result


def get_body_class_from_taxonomy(worms_data: dict) -> str:
    """
    Determine the broad body class from WoRMS taxonomy.
    This helps us know what type of animal we're dealing with.
    """
    if not worms_data:
        return "unknown"

    phylum = (worms_data.get("phylum") or "").lower()
    class_name = (worms_data.get("class") or "").lower()
    order = (worms_data.get("order") or "").lower()
    family = (worms_data.get("family") or "").lower()

    # Mollusks
    if phylum == "mollusca":
        if class_name == "gastropoda":
            return "gastropod_shell"  # Snails, sea slugs
        if class_name == "bivalvia":
            return "bivalve_shell"  # Clams, mussels
        if class_name == "cephalopoda":
            return "cephalopod"  # Octopus, squid
        return "mollusk"

    # Arthropods
    if phylum == "arthropoda":
        if "decapoda" in order:
            if "palinur" in family.lower():  # Spiny lobsters
                return "spiny_lobster_no_claws"
            if "nephrop" in family.lower():  # True lobsters
                return "clawed_lobster"
            if "portun" in family.lower():  # Swimming crabs
                return "swimming_crab"
            if "crab" in family or "brachyura" in order:
                return "crab"
            if "shrimp" in family or "prawn" in family or "penaeid" in family or "caridea" in order:
                return "shrimp"
            return "decapod"
        if "stomatopoda" in order:
            return "mantis_shrimp"
        return "crustacean"

    # Chordates
    if phylum == "chordata":
        if class_name in ["actinopterygii", "osteichthyes"]:
            return "bony_fish"
        if class_name in ["chondrichthyes", "elasmobranchii"]:
            if "raj" in order or "myliobat" in order or "torpedini" in order:
                return "ray"
            return "shark"
        if class_name == "reptilia":
            if "testudines" in order or "cheloni" in order:
                return "sea_turtle"
            return "reptile"
        if class_name == "mammalia":
            return "marine_mammal"
        return "vertebrate"

    # Echinoderms
    if phylum == "echinodermata":
        if "asteroidea" in class_name:
            return "starfish"
        if "echinoidea" in class_name:
            return "sea_urchin"
        if "holothuroidea" in class_name:
            return "sea_cucumber"
        if "ophiuroidea" in class_name:
            return "brittle_star"
        return "echinoderm"

    # Cnidarians
    if phylum == "cnidaria":
        if "scyphozoa" in class_name or "cubozoa" in class_name or "hydrozoa" in class_name:
            return "jellyfish"
        if "anthozoa" in class_name:
            return "coral_or_anemone"
        return "cnidarian"

    # Annelids
    if phylum == "annelida":
        return "marine_worm"

    # Porifera
    if phylum == "porifera":
        return "sponge"

    return "unknown"


# Body class to constraints mapping
BODY_CLASS_CONSTRAINTS = {
    "gastropod_shell": {
        "type": "Marine Gastropod (Snail/Sea Slug)",
        "constraints": "This is a SHELLED MOLLUSK. It has NO FINS, NO FISH-LIKE BODY, NO SCALES. The body is a spiral or conical SHELL. May have a soft foot visible. If nudibranch, NO shell - soft body with rhinophores and gills.",
        "view": "Shell aperture view showing spiral structure and ornamentation",
    },
    "bivalve_shell": {
        "type": "Marine Bivalve (Clam/Mussel/Oyster)",
        "constraints": "This is a TWO-SHELLED MOLLUSK. NO FINS, NO EYES, NO LEGS. Two hinged shell valves. May show mantle tissue if open.",
        "view": "View showing both valve patterns, slightly open to show interior",
    },
    "cephalopod": {
        "type": "Cephalopod (Octopus/Squid/Cuttlefish)",
        "constraints": "Soft-bodied mollusk with arms/tentacles. Octopus: 8 arms, 2 rows of suckers, NO shell. Squid: 8 arms + 2 tentacles, 1 row of suckers. Cuttlefish: W-shaped pupil, full-length fin.",
        "view": "Natural pose showing arm arrangement and eye",
    },
    "spiny_lobster_no_claws": {
        "type": "Spiny Lobster (Palinuridae)",
        "constraints": "CRITICAL: NO LARGE FRONT CLAWS. This is a SPINY LOBSTER, not a true lobster. All five pairs of legs are similar-sized walking legs. Has two MASSIVE spiny antennae longer than body. Heavily spined carapace.",
        "view": "Dorsal-lateral view showing antennae and walking legs",
    },
    "clawed_lobster": {
        "type": "True Lobster (Nephropidae)",
        "constraints": "HAS one pair of large asymmetrical claws - one crusher, one cutter. Long thin antennae. Segmented body.",
        "view": "Lateral view showing both claws",
    },
    "swimming_crab": {
        "type": "Swimming Crab (Portunidae)",
        "constraints": "Fifth pair of legs modified into paddle-shaped SWIMMING appendages. Lateral spines on carapace. Has front claws.",
        "view": "Dorsal view showing paddle legs clearly",
    },
    "crab": {
        "type": "Crab (Brachyura)",
        "constraints": "Broad carapace, walking legs, typically has front claws (chelipeds). Reduced abdomen tucked under body.",
        "view": "Dorsal view showing carapace and claw detail",
    },
    "shrimp": {
        "type": "Shrimp/Prawn",
        "constraints": "Elongated laterally compressed body. Long antennae. Small claws on first few leg pairs only. Fan-shaped tail. Rostrum (beak) projecting forward.",
        "view": "Lateral view showing body curve and antennae",
    },
    "mantis_shrimp": {
        "type": "Mantis Shrimp (Stomatopoda)",
        "constraints": "NOT a true shrimp. Has raptorial appendages (smashers or spearers). Unique compound eyes on stalks. Flattened body.",
        "view": "Anterior view showing raptorial appendages and eyes",
    },
    "bony_fish": {
        "type": "Bony Fish (Actinopterygii)",
        "constraints": "Has bony skeleton, operculum (gill cover), swim bladder. Fins with rays. Scales typical.",
        "view": "Full lateral view showing all fins and scaling",
    },
    "shark": {
        "type": "Shark (Chondrichthyes)",
        "constraints": "Cartilaginous skeleton (NO bones). NO operculum - exposed gill slits. NO swim bladder. Dermal denticles instead of scales.",
        "view": "Full lateral view showing gill slits and fins",
    },
    "ray": {
        "type": "Ray/Skate",
        "constraints": "Flattened body with expanded pectoral fins forming disc. Eyes on top, mouth underneath. May have venomous tail spine (stingrays) or NOT (mantas).",
        "view": "Dorsal view showing full disc shape",
    },
    "sea_turtle": {
        "type": "Sea Turtle (Cheloniidae)",
        "constraints": "Cannot retract head into shell. Paddle-shaped flippers, NOT legs. Streamlined shell (carapace).",
        "view": "Three-quarter dorsal view showing carapace and flippers",
    },
    "marine_mammal": {
        "type": "Marine Mammal",
        "constraints": "Warm-blooded, breathes air through blowhole. Horizontal tail flukes (not vertical like fish). No scales - smooth skin.",
        "view": "Lateral view showing full body profile",
    },
    "starfish": {
        "type": "Sea Star (Asteroidea)",
        "constraints": "Radially symmetrical. Five or more arms radiating from central disc. Tube feet on underside. NO skeleton - water vascular system.",
        "view": "Dorsal view showing arm arrangement",
    },
    "sea_urchin": {
        "type": "Sea Urchin (Echinoidea)",
        "constraints": "Spherical test (shell) covered in moveable spines. Five-fold symmetry. Mouth on underside with 'Aristotle's lantern'.",
        "view": "Oblique view showing spine arrangement",
    },
    "sea_cucumber": {
        "type": "Sea Cucumber (Holothuroidea)",
        "constraints": "Elongated leathery body. Tube feet. Ring of feeding tentacles around mouth. NO spines, NO shell.",
        "view": "Lateral view showing body and tentacles",
    },
    "jellyfish": {
        "type": "Jellyfish (Cnidaria)",
        "constraints": "Gelatinous bell-shaped body. Trailing tentacles and/or oral arms. NO skeleton. Mostly transparent.",
        "view": "View from below showing bell and tentacles",
    },
    "coral_or_anemone": {
        "type": "Coral or Anemone (Anthozoa)",
        "constraints": "Sessile (attached). Ring of tentacles around central mouth. Colonial (coral) or solitary (anemone).",
        "view": "Top view showing tentacle arrangement",
    },
    "marine_worm": {
        "type": "Marine Worm (Polychaete/Annelida)",
        "constraints": "Segmented body. May have tube. Feathery feeding crown (fanworms) or bristled segments.",
        "view": "View showing segmentation and feeding structures",
    },
    "sponge": {
        "type": "Sponge (Porifera)",
        "constraints": "NO true tissues. Porous body. Various growth forms (encrusting, tubular, branching). Oscula (large openings) visible.",
        "view": "View showing growth form and surface texture",
    },
}


def search_species(species: dict) -> dict:
    """
    Search for species information and return enriched data.
    """
    name = species["name"]
    scientific_name = species["scientificName"]

    result = {
        "id": species["id"],
        "name": name,
        "scientificName": scientific_name,
        "original_description": species.get("description", ""),
        "searched": True,
    }

    # 1. Get taxonomic info from WoRMS (quick, just classification)
    print(f"  Searching WoRMS for {scientific_name}...")
    worms_data = worms_search(scientific_name)
    if worms_data:
        result["taxonomy"] = worms_data
        result["body_class"] = get_body_class_from_taxonomy(worms_data)
        print(f"    -> Found: {worms_data.get('phylum')} / {worms_data.get('class')} / {worms_data.get('family')}")
    else:
        result["body_class"] = "unknown"

    time.sleep(DELAY_BETWEEN_REQUESTS)

    # 2. Get description from Wikipedia (richer descriptions)
    print(f"  Searching Wikipedia for {scientific_name}...")
    wiki_text = wikipedia_search(scientific_name)
    if wiki_text:
        result["wikipedia_extract"] = wiki_text
        morphology = extract_morphology(wiki_text)
        result["extracted_morphology"] = morphology
        print(f"    -> Found {len(wiki_text)} chars, colors: {morphology.get('colors', [])}")
    else:
        # Try common name
        print(f"  Trying common name: {name}...")
        wiki_text = wikipedia_search(name)
        if wiki_text:
            result["wikipedia_extract"] = wiki_text
            result["extracted_morphology"] = extract_morphology(wiki_text)
            print(f"    -> Found via common name")
        else:
            print(f"    -> No Wikipedia data found")

    time.sleep(DELAY_BETWEEN_REQUESTS)

    return result


def generate_grounded_prompt(enriched_species: dict) -> str:
    """
    Generate a prompt using searched data.
    """
    name = enriched_species["name"]
    scientific_name = enriched_species["scientificName"]
    body_class = enriched_species.get("body_class", "unknown")

    # Get constraints for this body class
    class_info = BODY_CLASS_CONSTRAINTS.get(body_class, {
        "type": "Marine Species",
        "constraints": "Anatomical accuracy critical - verify features against scientific references.",
        "view": "View showing key identifying features",
    })

    # Build description from searched data
    morphology = enriched_species.get("extracted_morphology", {})
    wiki_desc = morphology.get("description", "")
    colors = morphology.get("colors", [])
    size = morphology.get("size", "")

    # Build visual description
    visual_parts = []

    if wiki_desc:
        visual_parts.append(f"Description from reference: {wiki_desc}")

    if colors:
        visual_parts.append(f"Documented colors: {', '.join(colors)}")

    if size:
        visual_parts.append(f"Size: approximately {size}")

    # Add taxonomy info
    taxonomy = enriched_species.get("taxonomy", {})
    if taxonomy:
        family = taxonomy.get("family", "")
        if family:
            visual_parts.append(f"Family: {family}")

    visual_description = "\n• ".join(visual_parts) if visual_parts else "Reference images should be consulted for accurate coloration and pattern."

    prompt = f"""A scientific biological illustration plate of a {name} ({scientific_name}), rendered in exquisite 19th-century chromolithograph style.

COMPOSITION: {class_info['view']}. The specimen is centered on the plate with ample space to appreciate anatomical details.

SPECIES CLASSIFICATION: {class_info['type']}

CRITICAL ANATOMICAL CONSTRAINTS (FROM SCIENTIFIC DATABASE):
{class_info['constraints']}

VISUAL DESCRIPTION (FROM VERIFIED SOURCES):
• {visual_description}

ARTISTIC TECHNIQUE: Masterful stippling (pointillism) for tonal gradation, with delicate cross-hatching to define form and volume. Fine brushwork captures textures. Naturalistic watercolor washes. Edges defined purely through color value transitions and textural contrast—absolutely NO heavy black outlines or cartoon-like borders.

AESTHETIC: The plate has the organic, aged quality of an archival museum specimen illustration from a 19th-century natural history expedition.

BACKGROUND: Solid, uniform deep navy blue (#0B1C2C), providing dramatic contrast that makes the specimen luminous."""

    return prompt


def load_progress() -> dict:
    """Load search progress from file."""
    if PROGRESS_FILE.exists():
        with open(PROGRESS_FILE) as f:
            return json.load(f)
    return {"completed": [], "results": []}


def save_progress(progress: dict):
    """Save search progress to file."""
    with open(PROGRESS_FILE, "w") as f:
        json.dump(progress, f, indent=2)


def main():
    print("=" * 60)
    print("Search-Augmented Species Description Generator")
    print("Using FREE APIs: Wikipedia + WoRMS")
    print("=" * 60)

    # Load species data
    with open(INPUT_FILE) as f:
        data = json.load(f)

    species_list = data["species"]
    print(f"\nTotal species: {len(species_list)}")

    # Load progress
    progress = load_progress()
    completed_ids = set(progress["completed"])
    print(f"Already processed: {len(completed_ids)}")

    # Filter to species not yet processed
    to_process = [s for s in species_list if s["id"] not in completed_ids]
    print(f"Remaining: {len(to_process)}")

    if not to_process:
        print("\nAll species already processed!")
        # Generate prompts from saved results
        results = progress["results"]
    else:
        # Process species
        print(f"\nStarting search (this will take ~{len(to_process) * 1.5 / 60:.1f} minutes)...")
        print("Progress is saved - you can stop and resume anytime.\n")

        results = progress["results"]

        for i, species in enumerate(to_process):
            print(f"\n[{i+1}/{len(to_process)}] {species['name']} ({species['scientificName']})")

            try:
                enriched = search_species(species)
                results.append(enriched)

                # Save progress
                progress["completed"].append(species["id"])
                progress["results"] = results
                save_progress(progress)

            except KeyboardInterrupt:
                print("\n\nInterrupted! Progress saved. Run again to resume.")
                return

            except Exception as e:
                print(f"  ERROR: {e}")
                # Still mark as completed to avoid infinite loops
                progress["completed"].append(species["id"])
                results.append({
                    "id": species["id"],
                    "name": species["name"],
                    "scientificName": species["scientificName"],
                    "error": str(e),
                    "body_class": "unknown",
                })
                save_progress(progress)

    # Generate final prompts
    print("\n" + "=" * 60)
    print("Generating grounded prompts...")
    print("=" * 60)

    final_output = []
    for enriched in results:
        prompt = generate_grounded_prompt(enriched)
        final_output.append({
            "id": enriched["id"],
            "name": enriched["name"],
            "scientificName": enriched["scientificName"],
            "body_class": enriched.get("body_class", "unknown"),
            "taxonomy": enriched.get("taxonomy", {}),
            "prompt": prompt,
        })

    # Save final output
    with open(OUTPUT_FILE, "w") as f:
        json.dump({
            "prompts": final_output,
            "count": len(final_output),
            "sources": ["Wikipedia", "WoRMS (World Register of Marine Species)"],
        }, f, indent=2)

    print(f"\nSaved {len(final_output)} grounded prompts to {OUTPUT_FILE}")

    # Print sample
    print("\n" + "=" * 60)
    print("SAMPLE GROUNDED PROMPTS")
    print("=" * 60)

    for r in final_output[:3]:
        print(f"\n--- {r['name']} ({r['scientificName']}) ---")
        print(f"Body class: {r['body_class']}")
        if r.get('taxonomy'):
            print(f"Taxonomy: {r['taxonomy'].get('phylum')} > {r['taxonomy'].get('class')} > {r['taxonomy'].get('family')}")
        print(f"\nPrompt preview:\n{r['prompt'][:800]}...")


if __name__ == "__main__":
    main()
