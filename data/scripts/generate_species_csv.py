#!/usr/bin/env python3
"""
Generate CSV for species image generation prompts.
Creates descriptions suitable for AI image generators like Nano Banana.
"""

import json
import csv
import sys

# Visual descriptions by family for common species
FAMILY_DESCRIPTIONS = {
    # Sharks
    "carcharhinidae": "sleek grey shark with streamlined body, white underside, prominent dorsal fin, dark eyes",
    "sphyrnidae": "distinctive hammer-shaped head with eyes at tips, grey body, tall dorsal fin",
    "ginglymostomatidae": "yellowish-brown shark with broad flat head, small eyes, barbels near nostrils",
    "rhincodontidae": "massive shark with dark blue-grey body covered in white spots and pale stripes, wide flat head, huge terminal mouth",
    "stegostomatidae": "leopard-spotted shark with long tail, ridged body, small nasal barbels",
    "hemiscylliidae": "small spotted shark with elongated body, paddle-like fins for walking on reef",
    "orectolobidae": "camouflaged shark with flattened body, intricate patterns, fringed lobes around mouth",
    "alopiidae": "shark with extremely long scythe-like upper tail lobe, large eyes, pointed snout",
    "lamnidae": "powerful torpedo-shaped shark with conical snout, black eyes, crescent tail",
    "triakidae": "slender grey shark with large oval eyes, pointed snout, small teeth",

    # Rays
    "dasyatidae": "flat diamond-shaped ray with whip-like tail, smooth body, spiracles behind eyes",
    "myliobatidae": "ray with broad triangular wings, pronounced head, long whip tail with spine",
    "mobulidae": "massive ray with wing-like pectoral fins, cephalic fins flanking mouth, black upper surface with white patches",
    "aetobatidae": "elegant ray with dark body covered in white spots and rings, pointed duck-bill snout, long whip tail",
    "torpedinidae": "rounded disc-shaped ray with short thick tail, capable of electric discharge",

    # Reef fish - Wrasses
    "labridae": "elongated colorful fish with thick lips, continuous dorsal fin, often with intricate patterns",

    # Damselfish
    "pomacentridae": "small oval-shaped fish, often brightly colored, territorial behavior near coral",

    # Butterflyfish
    "chaetodontidae": "disc-shaped fish with pointed snout, bold stripes or spots, often yellow and white coloring",

    # Angelfish
    "pomacanthidae": "laterally compressed fish with vivid colors, often with blue, yellow, or orange patterns, extended fins",

    # Groupers
    "serranidae": "robust stocky fish with large mouth, mottled coloring, heavy body",

    # Jacks
    "carangidae": "powerful silvery fish with forked tail, streamlined body, large eyes",

    # Triggerfish
    "balistidae": "oval-shaped fish with tough skin, small mouth with strong teeth, can lock dorsal spine",

    # Surgeonfish
    "acanthuridae": "oval compressed fish with small mouth, often blue or yellow, scalpel-like spine near tail",

    # Moray eels
    "muraenidae": "snake-like body, no pectoral fins, constantly gaping mouth showing teeth, patterns vary",

    # Parrotfish
    "scaridae": "robust colorful fish with fused beak-like teeth, often blue, green, or pink coloring",

    # Snappers
    "lutjanidae": "medium-sized fish with sloping head profile, often reddish or yellowish, forked tail",

    # Grunts
    "haemulidae": "oval fish with thick lips, often silvery with stripes, named for grunting sounds",

    # Goatfish
    "mullidae": "elongated fish with pair of sensory barbels under chin, often pinkish or yellowish",

    # Gobies
    "gobiidae": "small bottom-dwelling fish with fused pelvic fins forming suction disc, large head",

    # Seahorses
    "syngnathidae": "upright posture with horse-like head, prehensile tail, bony armor plating",

    # Pufferfish
    "tetraodontidae": "rounded fish that can inflate with water, beak-like fused teeth, often spotted",

    # Scorpionfish
    "scorpaenidae": "heavily camouflaged fish with venomous spines, elaborate fin rays, mottled coloring",

    # Frogfish
    "antennariidae": "globular fish with textured warty skin, leg-like pectoral fins, modified lure on head",

    # Batfish
    "ephippidae": "tall disc-shaped fish with elongated dorsal and anal fins, often silvery with dark bands",

    # Barracuda
    "sphyraenidae": "elongated silvery fish with pointed head, prominent underbite with sharp teeth",

    # Nudibranchs
    "chromodorididae": "soft-bodied sea slug with vibrant colors, rhinophores on head, feathery gills on back",
    "hexabranchidae": "large red-orange nudibranch with ruffled body edges, six feathery gills",
    "phyllidiidae": "rounded nudibranch with tubercles on back, often black and pink or yellow patterns",
    "aeolidiidae": "slender nudibranch covered in finger-like cerata, often translucent with bright tips",

    # Cephalopods
    "octopodidae": "eight arms with suckers, large intelligent eyes, highly textured skin that changes color",
    "sepiidae": "cuttlefish with W-shaped pupils, undulating fin fringe, eight arms plus two tentacles",
    "loliginidae": "torpedo-shaped squid with triangular fins, ten arms, large eyes",
    "nautilidae": "spiral chambered shell, many small tentacles, primitive appearance",

    # Crustaceans
    "palaemonidae": "translucent shrimp with long antennae, often with colored markings",
    "stenopodidae": "shrimp with banded red and white pattern, long slender claws, white antennae",
    "palinuridae": "spiny lobster with long antennae, no large claws, segmented tail, armored body",
    "portunidae": "swimming crab with paddle-shaped rear legs, broad carapace",
    "majidae": "spider crab with long legs, often decorated with sponges or algae",
    "squillidae": "mantis shrimp with powerful raptorial claws, stalked eyes, colorful segmented body",

    # Echinoderms
    "ophidiasteridae": "five-armed starfish with smooth skin, often orange or blue coloring",
    "oreasteridae": "large cushion-like starfish with short thick arms, often with nodules",
    "acanthasteridae": "crown-of-thorns starfish with many venomous spines covering body",
    "diadematidae": "sea urchin with extremely long black spines radiating from round body",
    "holothuriidae": "elongated cylindrical body, tube feet, leathery skin, tentacles around mouth",

    # Sea turtles
    "cheloniidae": "large sea turtle with heart-shaped shell, non-retractable flippers, rounded head",

    # Marine mammals
    "delphinidae": "streamlined grey body with dorsal fin, bottle-shaped snout, intelligent dark eyes",
    "balaenopteridae": "massive whale with pleated throat, small dorsal fin, long flippers",
    "physeteridae": "large blocky head, wrinkled skin, small flippers, blowhole on left side",
}

# Specific species descriptions for well-known animals
SPECIES_DESCRIPTIONS = {
    "amphiprion ocellaris": "bright orange body with three vertical white bands outlined in thin black, small oval fish swimming near anemone",
    "rhincodon typus": "enormous filter-feeding shark with dark blue-grey body covered in white spots and pale vertical stripes, wide flat head, huge terminal mouth",
    "mobula birostris": "massive manta ray with 7m wingspan, black upper surface with white shoulder patches, cephalic fins flanking wide mouth",
    "chelonia mydas": "large sea turtle with olive-brown heart-shaped shell, pale plastron, serrated beak, approximately 1m long",
    "eretmochelys imbricata": "hawksbill turtle with amber tortoiseshell-patterned shell, pointed hawk-like beak, overlapping scutes",
    "tursiops truncatus": "sleek grey dolphin with lighter underside, curved dorsal fin, bottle-shaped snout with permanent smile",
    "megaptera novaeangliae": "massive humpback whale with long white flippers, knobby head, pleated throat, barnacles on skin",
    "octopus vulgaris": "large octopus with reddish-brown mottled skin, eight arms with suckers, large intelligent eyes with horizontal pupils",
    "panulirus argus": "large spiny lobster with reddish-brown carapace, extremely long antennae, no claws, white spots on segmented tail",
    "pterois volitans": "striking lionfish with bold maroon and white stripes, elaborate fan-like venomous spines, feathery appendages",
    "gymnothorax javanicus": "massive moray eel with leopard-like dark brown spots on tan body, constantly gaping mouth, small eyes",
    "hapalochlaena lunulata": "small octopus with iridescent blue rings that flash bright when threatened, highly venomous",
    "hippocampus": "tiny seahorse with bulbous tubercles, prehensile tail, camouflaged to match host coral",
    "mola mola": "bizarre disc-shaped sunfish with silver-grey rough skin, tiny mouth, no true tail fin",
    "sphyrna lewini": "scalloped hammerhead with uniquely shaped head featuring scalloped front edge, eyes at tips",
    "galeocerdo cuvier": "tiger shark with dark vertical stripes on grey body, broad flat head, serrated teeth",
    "carcharodon carcharias": "great white shark with grey upper body, white underside, conical snout, black eyes",
    "aetobatus narinari": "spotted eagle ray with dark body covered in white spots and rings, pointed duck-bill snout, long whip tail",
}


def get_description(species):
    """Generate description for a species."""
    name = species.get('name', '')
    scientific = (species.get('canonical_name') or species.get('scientific_name', '')).lower()
    family = (species.get('family') or '').lower()
    category = species.get('category', '')

    # Check for specific species description
    for key, desc in SPECIES_DESCRIPTIONS.items():
        if key in scientific:
            return desc

    # Check for family description
    if family in FAMILY_DESCRIPTIONS:
        base = FAMILY_DESCRIPTIONS[family]
        # Add species-specific name
        return f"{name}: {base}"

    # Generic fallback by category
    if category == "Fish":
        return f"{name}: marine fish with typical reef fish body shape, scales, and fins"
    elif category == "Invertebrate":
        return f"{name}: marine invertebrate found on coral reefs"
    elif category == "Reptile":
        return f"{name}: marine reptile with flippers adapted for swimming"
    elif category == "Mammal":
        return f"{name}: marine mammal with streamlined body for ocean life"
    elif category == "Coral":
        return f"{name}: coral colony with calcium carbonate skeleton"
    else:
        return f"{name}: marine organism"


def main():
    if len(sys.argv) < 3:
        print("Usage: generate_species_csv.py <input.json> <output.csv>")
        sys.exit(1)

    input_file = sys.argv[1]
    output_file = sys.argv[2]

    with open(input_file, 'r') as f:
        data = json.load(f)

    species_list = data['species']

    with open(output_file, 'w', newline='', encoding='utf-8') as f:
        writer = csv.writer(f)
        writer.writerow(['bucket', 'scientific_name', 'common_name', 'description'])

        for sp in species_list:
            bucket = sp.get('rarity', 'Common')
            # Normalize rarity names
            if bucket == "Very Rare":
                bucket = "VeryRare"

            scientific = sp.get('canonical_name') or sp.get('scientific_name', '')
            # Clean up scientific name (remove author citations)
            if '(' in scientific:
                scientific = scientific.split('(')[0].strip()
            if ',' in scientific:
                scientific = scientific.split(',')[0].strip()

            common = sp.get('name', '')
            # Take first name if multiple
            if ',' in common:
                common = common.split(',')[0].strip()

            description = get_description(sp)

            writer.writerow([bucket, scientific, common, description])

    print(f"Wrote {len(species_list)} species to {output_file}")


if __name__ == "__main__":
    main()
