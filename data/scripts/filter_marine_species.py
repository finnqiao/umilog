#!/usr/bin/env python3
"""
Filter GBIF species data to true marine species relevant for dive logging.
Removes lichens, freshwater fish, and other non-marine organisms.
"""

import json
import sys

# Marine fish families (reef fish, sharks, rays, etc.)
MARINE_FISH_FAMILIES = {
    # Reef fish
    "labridae",          # Wrasses
    "pomacentridae",     # Damselfish, clownfish
    "chaetodontidae",    # Butterflyfish
    "pomacanthidae",     # Angelfish
    "serranidae",        # Groupers, sea bass
    "carangidae",        # Jacks, trevallies
    "balistidae",        # Triggerfish
    "acanthuridae",      # Surgeonfish, tangs
    "muraenidae",        # Moray eels
    "scaridae",          # Parrotfish
    "lutjanidae",        # Snappers
    "haemulidae",        # Grunts
    "mullidae",          # Goatfish
    "blenniidae",        # Blennies
    "gobiidae",          # Gobies
    "syngnathidae",      # Seahorses, pipefish
    "tetraodontidae",    # Pufferfish
    "diodontidae",       # Porcupinefish
    "ostraciidae",       # Boxfish
    "scorpaenidae",      # Scorpionfish, lionfish
    "antennariidae",     # Frogfish
    "monacanthidae",     # Filefish
    "zanclidae",         # Moorish idol
    "siganidae",         # Rabbitfish
    "nemipteridae",      # Threadfin bream
    "lethrinidae",       # Emperors
    "cirrhitidae",       # Hawkfish
    "pinguipedidae",     # Sandperches
    "apogonidae",        # Cardinalfish
    "caesionidae",       # Fusiliers
    "holocentridae",     # Squirrelfish, soldierfish
    "priacanthidae",     # Bigeyes
    "ephippidae",        # Batfish
    "kyphosidae",        # Sea chubs
    "sparidae",          # Sea breams
    "mugilidae",         # Mullets (some marine)
    "atherinidae",       # Silversides
    "plotosidae",        # Eeltail catfish
    "congridae",         # Conger eels
    "ophichthidae",      # Snake eels
    "fistulariidae",     # Cornetfish
    "aulostomidae",      # Trumpetfish
    "sphyraenidae",      # Barracudas

    # Sharks
    "carcharhinidae",    # Reef sharks
    "sphyrnidae",        # Hammerhead sharks
    "ginglymostomatidae", # Nurse sharks
    "rhincodontidae",    # Whale shark
    "stegostomatidae",   # Zebra shark
    "hemiscylliidae",    # Bamboo sharks
    "orectolobidae",     # Wobbegongs
    "triakidae",         # Hound sharks
    "scyliorhinidae",    # Cat sharks
    "alopiidae",         # Thresher sharks
    "lamnidae",          # Mackerel sharks (great white, mako)

    # Rays
    "dasyatidae",        # Stingrays
    "myliobatidae",      # Eagle rays
    "mobulidae",         # Manta rays
    "aetobatidae",       # Spotted eagle rays
    "rhinobatidae",      # Guitarfish
    "torpedinidae",      # Electric rays
    "rajidae",           # Skates

    # Pelagic fish
    "scombridae",        # Tuna, mackerel
    "istiophoridae",     # Marlin, sailfish
    "xiphiidae",         # Swordfish
    "coryphaenidae",     # Mahi-mahi
    "echeneidae",        # Remoras
    "molidae",           # Ocean sunfish
}

# Marine invertebrate families
MARINE_INVERTEBRATE_FAMILIES = {
    # Nudibranchs and sea slugs
    "chromodorididae",   # Chromodorid nudibranchs
    "polyceridae",       # Polycera nudibranchs
    "hexabranchidae",    # Spanish dancers
    "discodorididae",    # Dorid nudibranchs
    "phyllidiidae",      # Phyllidiid nudibranchs
    "aeolidiidae",       # Aeolid nudibranchs
    "flabellinidae",     # Flabellina nudibranchs
    "glaucidae",         # Blue dragon
    "aplysiidae",        # Sea hares

    # Cephalopods
    "octopodidae",       # Octopus
    "sepiidae",          # Cuttlefish
    "loliginidae",       # Squid
    "nautilidae",        # Nautilus
    "argonautidae",      # Paper nautilus
    "hapalochlaenidae",  # Blue-ringed octopus

    # Crustaceans
    "palaemonidae",      # Cleaner shrimp
    "stenopodidae",      # Banded coral shrimp
    "palinuridae",       # Spiny lobsters
    "nephropidae",       # True lobsters
    "portunidae",        # Swimming crabs
    "majidae",           # Spider crabs
    "xanthidae",         # Mud crabs
    "grapsidae",         # Shore crabs
    "diogenidae",        # Hermit crabs
    "alpheidae",         # Snapping shrimp
    "gnathophyllidae",   # Harlequin shrimp
    "penaeidae",         # Prawns
    "squillidae",        # Mantis shrimp
    "odontodactylidae",  # Peacock mantis shrimp

    # Echinoderms
    "ophidiasteridae",   # Starfish
    "oreasteridae",      # Cushion stars
    "acanthasteridae",   # Crown-of-thorns
    "linckiidae",        # Sea stars
    "asteriidae",        # Common starfish
    "diadematidae",      # Sea urchins
    "echinometridae",    # Rock boring urchins
    "toxopneustidae",    # Flower urchins
    "holothuriidae",     # Sea cucumbers
    "stichopodidae",     # Sea cucumbers
    "crinoidea",         # Feather stars
    "comasteridae",      # Feather stars
    "mariametridae",     # Feather stars

    # Molluscs (shells)
    "tridacnidae",       # Giant clams
    "conidae",           # Cone shells
    "cypraeidae",        # Cowries
    "strombidae",        # Conch shells
    "muricidae",         # Murex shells (some)
    "veneridae",         # Venus clams
    "pectinidae",        # Scallops
    "spondylidae",       # Thorny oysters
    "pinnidae",          # Pen shells
    "pteriidae",         # Pearl oysters

    # Cnidarians (non-coral)
    "cassiopeidae",      # Upside-down jellyfish
    "rhizostomatidae",   # Barrel jellyfish
    "pelagiidae",        # Sea nettles
    "catostylidae",      # Blue blubber jellyfish
    "carybdeidae",       # Box jellyfish
    "physaliidae",       # Portuguese man-of-war
    "actiniidae",        # Sea anemones
    "stichodactylidae",  # Carpet anemones
    "thalassianthidae",  # Anemones

    # Worms
    "serpulidae",        # Christmas tree worms
    "sabellidae",        # Feather duster worms

    # Tunicates
    "pyuridae",          # Sea squirts
    "ascidiidae",        # Sea squirts
}

# Families to exclude (lichens, freshwater, terrestrial)
EXCLUDE_FAMILIES = {
    # Lichens (definitely not marine!)
    "parmeliaceae", "physciaceae", "cladoniaceae", "graphidaceae",
    "ramalinaceae", "caliciaceae", "teloschistaceae", "lobariaceae",
    "lecanoraceae", "collemataceae", "umbilicariaceae", "pertusariaceae",
    "roccellaceae", "ochrolechiaceae", "aspergillaceae", "nectriaceae",

    # Freshwater fish
    "cyprinidae",        # Carp, minnows, goldfish
    "salmonidae",        # Salmon, trout
    "cichlidae",         # Cichlids (mostly freshwater)
    "characidae",        # Tetras, piranhas
    "cobitidae",         # Loaches
    "siluridae",         # Catfish
    "esocidae",          # Pike
    "percidae",          # Perch
    "centrarchidae",     # Sunfish, bass
    "ictaluridae",       # Freshwater catfish
    "poeciliidae",       # Guppies, mollies
    "leuciscidae",       # Minnows
    "balitoridae",       # River loaches
    "nemacheilidae",     # Stone loaches
    "gasterosteidae",    # Sticklebacks

    # Land snails
    "camaenidae",        # Land snails
    "helicidae",         # Land snails
    "clausiliidae",      # Door snails
    "hygromiidae",       # Land snails

    # Freshwater crustaceans
    "astacidae",         # Freshwater crayfish
    "cambaridae",        # Freshwater crayfish

    # Terrestrial/freshwater
    "lacertidae",        # Wall lizards
    "corycaeidae",       # Copepods (too small for divers)
}


def main():
    if len(sys.argv) < 3:
        print("Usage: filter_marine_species.py <input.json> <output.json>")
        sys.exit(1)

    input_file = sys.argv[1]
    output_file = sys.argv[2]

    with open(input_file, 'r') as f:
        data = json.load(f)

    all_species = data['species']
    print(f"Input: {len(all_species)} species")

    filtered = []
    excluded_reasons = {}

    for sp in all_species:
        family = (sp.get('family') or '').lower()
        name = sp.get('name', '')
        category = sp.get('category', '')

        # Skip if in exclude list
        if family in EXCLUDE_FAMILIES:
            excluded_reasons[family] = excluded_reasons.get(family, 0) + 1
            continue

        # Include if in marine families
        if family in MARINE_FISH_FAMILIES or family in MARINE_INVERTEBRATE_FAMILIES:
            filtered.append(sp)
            continue

        # Skip unknown families for fish (likely freshwater)
        if category == 'Fish' and family not in MARINE_FISH_FAMILIES:
            excluded_reasons[f"unknown_fish:{family}"] = excluded_reasons.get(f"unknown_fish:{family}", 0) + 1
            continue

        # For invertebrates, be more selective - only include known marine families
        if category == 'Invertebrate' and family not in MARINE_INVERTEBRATE_FAMILIES:
            excluded_reasons[f"unknown_invert:{family}"] = excluded_reasons.get(f"unknown_invert:{family}", 0) + 1
            continue

        # Include reptiles (sea turtles, sea snakes)
        if category == 'Reptile':
            filtered.append(sp)
            continue

        # Include mammals (dolphins, whales, seals)
        if category == 'Mammal':
            filtered.append(sp)
            continue

        # Include corals
        if category == 'Coral':
            filtered.append(sp)
            continue

    # Recalculate rarity based on filtered set
    if filtered:
        max_count = max(s['total_occurrences'] for s in filtered)
        for sp in filtered:
            ratio = sp['total_occurrences'] / max_count
            if ratio >= 0.1:
                sp['rarity'] = "Common"
            elif ratio >= 0.03:
                sp['rarity'] = "Uncommon"
            elif ratio >= 0.005:
                sp['rarity'] = "Rare"
            else:
                sp['rarity'] = "Very Rare"

    # Sort by occurrence count (most common first)
    filtered.sort(key=lambda x: -x['total_occurrences'])

    output = {
        'species': filtered,
        'metadata': {
            **data.get('metadata', {}),
            'filtered_count': len(filtered),
            'original_count': len(all_species),
        }
    }

    with open(output_file, 'w') as f:
        json.dump(output, f, ensure_ascii=False, indent=2)

    print(f"Output: {len(filtered)} marine species -> {output_file}")
    print()
    print("Excluded:")
    for reason, count in sorted(excluded_reasons.items(), key=lambda x: -x[1])[:15]:
        print(f"  {count:>4} - {reason}")

    # Category breakdown
    cats = {}
    for sp in filtered:
        c = sp['category']
        cats[c] = cats.get(c, 0) + 1
    print()
    print("By category:")
    for c, n in sorted(cats.items(), key=lambda x: -x[1]):
        print(f"  {c}: {n}")

    # Rarity breakdown
    rars = {}
    for sp in filtered:
        r = sp['rarity']
        rars[r] = rars.get(r, 0) + 1
    print()
    print("By rarity:")
    for r in ['Common', 'Uncommon', 'Rare', 'Very Rare']:
        print(f"  {r}: {rars.get(r, 0)}")


if __name__ == "__main__":
    main()
