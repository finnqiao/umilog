#!/usr/bin/env python3
"""
Generate 19th-century chromolithograph-style illustration prompts for marine species.
"""

import json
import re
import csv
from pathlib import Path

# Color palettes by species type
COLOR_PALETTES = {
    "shark": "metallic steel-gray and slate blue with counter-shaded cream-white underneath",
    "hammerhead": "metallic bronze-gray and olive with pale cream underside",
    "whale_shark": "deep slate blue with constellation of cream-white spots, pale gray underside",
    "ray": "dusky brown and warm gray dorsally with pure white ventral surface",
    "manta": "velvety black dorsally with stark white ventral markings",
    "eagle_ray": "deep indigo with golden-white spots, pure white underneath",
    "turtle": "olive-brown and amber carapace with warm cream plastron",
    "octopus": "rich russet-brown and burnt sienna with cream suckers",
    "squid": "translucent pearl-white with rose-pink and iridescent purple undertones",
    "cuttlefish": "mottled sepia-brown and cream with subtle purple iridescence",
    "crab": "deep crimson-red and burnt orange with cream-colored joints",
    "lobster": "rich vermillion-red and deep coral with cream antennae",
    "shrimp": "translucent coral-pink and rose with delicate red striping",
    "jellyfish": "translucent azure-blue and ethereal violet with trailing white tentacles",
    "nudibranch": "vivid electric blue and vibrant orange with delicate cerata",
    "seahorse": "warm amber-gold and burnt orange with delicate banding",
    "pipefish": "elongated jade-green and brown with subtle banding",
    "eel": "sleek olive-brown and golden-yellow, often with intricate spotted patterns",
    "moray": "mottled chocolate-brown and cream with distinctive jaw pattern",
    "grouper": "warm brown and russet with cream mottling and dark spots",
    "snapper": "vibrant coral-red and pink with silver-white underside",
    "wrasse": "brilliant turquoise, emerald-green, and coral-pink with intricate patterns",
    "parrotfish": "vibid turquoise-blue, emerald-green, and coral-pink scales",
    "angelfish": "bold electric blue and sunshine-yellow with dark vertical bars",
    "butterflyfish": "bright lemon-yellow and white with bold black eye-stripe",
    "clownfish": "vivid tangerine-orange with bold white bands edged in black",
    "damselfish": "electric cobalt-blue with subtle darker markings",
    "surgeonfish": "powder-blue and bright yellow with dark accents",
    "tang": "vivid royal-blue or bright yellow with contrasting markings",
    "triggerfish": "bold geometric patterns in slate-gray, brown, and yellow",
    "pufferfish": "mottled tan and cream with distinctive spotted pattern",
    "boxfish": "geometric yellow with black spots or blue-gray with intricate patterns",
    "scorpionfish": "heavily mottled crimson-red, brown, and cream with elaborate fins",
    "lionfish": "dramatic cream and maroon-brown stripes with elaborate fan-like fins",
    "goby": "subtle tan and brown with delicate spotting, translucent fins",
    "blenny": "mottled olive-brown and cream with distinctive head profile",
    "barracuda": "sleek silver-blue with dark chevron markings",
    "tuna": "metallic dark blue dorsally fading to silver-white ventrally",
    "mackerel": "iridescent blue-green with dark wavy stripes, silver sides",
    "mullet": "silver-gray with subtle olive tones and darker dorsal surface",
    "dolphin": "sleek blue-gray dorsally fading to pale cream-white underneath",
    "whale": "deep charcoal-gray and slate-blue with pale mottled underside",
    "seal": "sleek silver-gray with darker spotting",
    "starfish": "rich orange-vermillion and coral-red with textured surface",
    "urchin": "deep purple-black or vibrant red with prominent spines",
    "cucumber": "mottled brown and cream with leathery textured skin",
    "anemone": "vibid magenta-pink and green with flowing tentacles",
    "coral": "warm coral-pink, cream, and amber with intricate polyp texture",
    "sponge": "warm ochre-yellow and burnt orange with porous texture",
    "worm": "iridescent blue-green and cream with feathery gills",
    "default_fish": "silver-blue with subtle iridescence and pale underside",
    "default_invertebrate": "warm amber-brown and cream with subtle patterning",
}

# View/pose descriptions by body type
VIEW_DESCRIPTIONS = {
    "shark": "Lateral view showing the full streamlined body with prominent dorsal fin and powerful caudal fin",
    "hammerhead": "Lateral view showcasing the distinctive cephalofoil (hammer-shaped head) and streamlined body",
    "ray": "Dorsal view displaying the full disc-shaped body with elegant pectoral wings and whip-like tail",
    "manta": "Dorsal-oblique view showing the magnificent wingspan and distinctive cephalic fins",
    "turtle": "Three-quarter dorsal view displaying the ornate carapace pattern and powerful flippers",
    "octopus": "Dynamic view with arms gracefully arranged showing suckers and intelligent eye",
    "squid": "Lateral view displaying the torpedo-shaped mantle, fins, and tentacle arrangement",
    "cuttlefish": "Lateral view showing the oval body, undulating fin, and distinctive W-shaped pupil",
    "crab": "Dorsal view displaying the full carapace, chelipeds (claws), and walking legs",
    "lobster": "Lateral view showing the segmented body, large claws, and long antennae",
    "shrimp": "Lateral view displaying the curved body, rostrum, and delicate swimming legs",
    "jellyfish": "View from below showing the translucent bell and trailing oral arms",
    "nudibranch": "Dorsal-oblique view showing the ornate body, rhinophores, and cerata or gills",
    "seahorse": "Lateral view displaying the distinctive curved body, horse-like head, and prehensile tail",
    "pipefish": "Lateral view showing the extremely elongated tubular body and tiny fins",
    "eel": "Sinuous lateral view displaying the elongated serpentine body",
    "moray": "Emerging from rocky crevice, mouth slightly agape showing distinctive dentition",
    "fish_elongated": "Lateral view showing the full elongated body profile with all fin detail",
    "fish_deep": "Lateral view displaying the deep, laterally compressed body with ornate finnage",
    "fish_standard": "Lateral view showing the full body profile with detailed fin structure and scaling",
    "starfish": "Dorsal view displaying all arms radiating from central disc with textured surface",
    "urchin": "Oblique view showing the spherical test with prominent spine arrangement",
    "cucumber": "Lateral view showing the elongated cylindrical body with tube feet",
    "anemone": "View showing the column and crown of tentacles in natural expanded state",
    "worm": "Lateral view showing the segmented body and feathery feeding appendages",
}


def classify_species(name: str, description: str) -> tuple[str, str]:
    """Classify species to determine color palette and view type."""
    name_lower = name.lower()
    desc_lower = description.lower() if description else ""
    combined = f"{name_lower} {desc_lower}"

    # Sharks
    if "hammerhead" in combined:
        return "hammerhead", "hammerhead"
    if "whale shark" in combined:
        return "whale_shark", "shark"
    if "shark" in combined:
        return "shark", "shark"

    # Rays
    if "manta" in combined:
        return "manta", "manta"
    if "eagle ray" in combined:
        return "eagle_ray", "ray"
    if "ray" in combined or "skate" in combined:
        return "ray", "ray"

    # Reptiles
    if "turtle" in combined or "tortoise" in combined:
        return "turtle", "turtle"

    # Mammals
    if "dolphin" in combined or "porpoise" in combined:
        return "dolphin", "fish_standard"
    if "whale" in combined:
        return "whale", "fish_standard"
    if "seal" in combined or "sea lion" in combined:
        return "seal", "fish_standard"

    # Cephalopods
    if "octopus" in combined:
        return "octopus", "octopus"
    if "squid" in combined:
        return "squid", "squid"
    if "cuttlefish" in combined:
        return "cuttlefish", "cuttlefish"

    # Crustaceans
    if "crab" in combined:
        return "crab", "crab"
    if "lobster" in combined:
        return "lobster", "lobster"
    if "shrimp" in combined or "prawn" in combined:
        return "shrimp", "shrimp"

    # Cnidarians
    if "jellyfish" in combined or "jelly" in combined:
        return "jellyfish", "jellyfish"
    if "anemone" in combined:
        return "anemone", "anemone"

    # Echinoderms
    if "starfish" in combined or "sea star" in combined:
        return "starfish", "starfish"
    if "urchin" in combined:
        return "urchin", "urchin"
    if "cucumber" in combined:
        return "cucumber", "cucumber"

    # Specific fish families
    if "nudibranch" in combined or "sea slug" in combined:
        return "nudibranch", "nudibranch"
    if "seahorse" in combined:
        return "seahorse", "seahorse"
    if "pipefish" in combined:
        return "pipefish", "pipefish"
    if "moray" in combined:
        return "moray", "moray"
    if "eel" in combined:
        return "eel", "eel"
    if "grouper" in combined:
        return "grouper", "fish_standard"
    if "snapper" in combined:
        return "snapper", "fish_standard"
    if "wrasse" in combined:
        return "wrasse", "fish_standard"
    if "parrotfish" in combined:
        return "parrotfish", "fish_standard"
    if "angelfish" in combined:
        return "angelfish", "fish_deep"
    if "butterflyfish" in combined or "butterfly" in combined:
        return "butterflyfish", "fish_deep"
    if "clownfish" in combined or "anemonefish" in combined:
        return "clownfish", "fish_standard"
    if "damselfish" in combined or "damsel" in combined:
        return "damselfish", "fish_standard"
    if "surgeonfish" in combined:
        return "surgeonfish", "fish_standard"
    if "tang" in combined:
        return "tang", "fish_deep"
    if "triggerfish" in combined:
        return "triggerfish", "fish_deep"
    if "pufferfish" in combined or "puffer" in combined:
        return "pufferfish", "fish_standard"
    if "boxfish" in combined:
        return "boxfish", "fish_standard"
    if "scorpionfish" in combined:
        return "scorpionfish", "fish_standard"
    if "lionfish" in combined:
        return "lionfish", "fish_standard"
    if "goby" in combined:
        return "goby", "fish_standard"
    if "blenny" in combined:
        return "blenny", "fish_standard"
    if "barracuda" in combined:
        return "barracuda", "fish_elongated"
    if "tuna" in combined:
        return "tuna", "fish_standard"
    if "mackerel" in combined:
        return "mackerel", "fish_standard"
    if "mullet" in combined:
        return "mullet", "fish_standard"
    if "worm" in combined or "polychaete" in combined:
        return "worm", "worm"
    if "sponge" in combined:
        return "sponge", "anemone"
    if "coral" in combined:
        return "coral", "anemone"

    # Infer from description
    if "invertebrate" in desc_lower:
        return "default_invertebrate", "fish_standard"

    # Default for fish
    return "default_fish", "fish_standard"


def extract_features(description: str) -> str:
    """Extract and enhance physical features from description."""
    if not description:
        return ""

    # Remove the species name prefix if present (before colon)
    if ":" in description:
        description = description.split(":", 1)[1].strip()

    # Clean up and enhance the description
    features = description

    # Make more vivid
    replacements = [
        ("marine fish", "marine fish specimen"),
        ("reef fish", "tropical reef fish"),
        ("typical", "characteristic"),
        ("found on coral reefs", "native to coral reef ecosystems"),
    ]

    for old, new in replacements:
        features = features.replace(old, new)

    return features


def generate_prompt(species: dict) -> str:
    """Generate a detailed chromolithograph-style illustration prompt."""
    name = species["name"]
    scientific_name = species["scientificName"]
    description = species.get("description", "")

    # Classify species
    color_key, view_key = classify_species(name, description)

    # Get color palette
    colors = COLOR_PALETTES.get(color_key, COLOR_PALETTES["default_fish"])

    # Get view description
    view = VIEW_DESCRIPTIONS.get(view_key, VIEW_DESCRIPTIONS["fish_standard"])

    # Extract features
    features = extract_features(description)
    if features:
        features = f" The specimen displays {features}."
    else:
        features = ""

    prompt = (
        f"A scientific biological illustration plate of a {name} ({scientific_name}), "
        f"rendered in a 19th-century chromolithograph style. {view}.{features} "
        f"The illustration uses fine stippling (dots) and delicate cross-hatching for shading, "
        f"with realistic watercolor washes in {colors}. "
        f"There are NO thick black cartoon outlines; edges are defined by texture and color contrast against the background. "
        f"The texture should feel organic and aged, like an archival museum plate. "
        f"The background is a solid, uniform deep navy blue (#0B1C2C)."
    )

    return prompt


def main():
    input_path = Path("/Users/finn/dev/umilog/data/export/species_catalog_full.json")
    output_path = Path("/Users/finn/dev/umilog/data/export/species_illustration_prompts.json")
    csv_output_path = Path("/Users/finn/dev/umilog/data/export/species_illustration_prompts.csv")

    with open(input_path) as f:
        data = json.load(f)

    species_list = data["species"]
    results = []

    for species in species_list:
        prompt = generate_prompt(species)
        results.append({
            "id": species["id"],
            "name": species["name"],
            "scientificName": species["scientificName"],
            "prompt": prompt
        })

    # Write JSON output
    with open(output_path, "w") as f:
        json.dump({"prompts": results, "count": len(results)}, f, indent=2)

    # Write CSV output
    with open(csv_output_path, "w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=["id", "name", "scientificName", "prompt"])
        writer.writeheader()
        writer.writerows(results)

    print(f"Generated {len(results)} prompts")
    print(f"JSON: {output_path}")
    print(f"CSV: {csv_output_path}")

    # Print a few samples
    print("\n--- SAMPLE PROMPTS ---\n")
    samples = [0, 1, 10, 50, 100]
    for i in samples:
        if i < len(results):
            print(f"[{results[i]['name']}]")
            print(results[i]['prompt'])
            print()


if __name__ == "__main__":
    main()
