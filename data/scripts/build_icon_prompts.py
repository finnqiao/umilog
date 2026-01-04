#!/usr/bin/env python3
"""
Build image generation prompts from species data.
Generates prompts for both white (field guide) and navy (chromolithograph) styles.
"""

import csv
import json
import sys
from pathlib import Path
from dataclasses import dataclass


@dataclass
class Species:
    scientific_name: str
    common_name: str
    key_identifiers: str
    view_description: str = "Lateral view"
    color_palette: str = "natural species coloring"


def build_white_prompt(species: Species) -> str:
    """Build field-guide style prompt with white background."""
    return f"""Create a single {species.common_name} ({species.scientific_name}) icon illustration for a tracking app.
Key identifiers: {species.key_identifiers}

Hard constraints
• One subject only: {species.common_name} ({species.scientific_name}). No other animals, objects, text, labels, UI, borders, badges, shadows, or masks.
• Composition: centered, full body visible, not cropped, ~12% padding around the subject, square 1:1.
• Background: pure solid white (#FFFFFF) only. Absolutely no texture, paper grain, vignette, gradient, checkerboard, or grid.

Style (keep consistent across a whole set)
• Vintage natural-history / field-guide engraving look adapted for UI.
• Bold clean outer contour, consistent stroke weight.
• Minimal interior linework with fine hatching + very light stipple (sparse; do not make it noisy).
• Limited muted palette (2–4 flat tones), high contrast, crisp edges, readable at small sizes.

Anatomy
• Keep the silhouette and proportions characteristic of {species.common_name} ({species.scientific_name}); do not genericize into a default shape.
• Emphasize the animal's most distinctive identifiers: {species.key_identifiers}.

Avoid
checkerboard, grid, "transparent background", background pattern, gray cast, paper texture, drop shadow, glow, frame, badge, cartoon simplification, photorealism, 3D render, extra fins/limbs, distorted anatomy."""


def build_navy_prompt(species: Species) -> str:
    """Build chromolithograph style prompt with navy background."""
    return f"""A scientific biological illustration plate of a {species.common_name} ({species.scientific_name}), rendered in a 19th-century chromolithograph style. {species.view_description} showing the full body with {species.key_identifiers}. The illustration uses fine stippling (dots) and delicate cross-hatching for shading, with realistic watercolor washes in {species.color_palette}. There are NO thick black cartoon outlines; edges are defined by texture and color contrast against the background. The texture should feel organic and aged, like an archival museum plate. The background is a solid, uniform deep navy blue (#0B1C2C)."""


def load_species_csv(filepath: Path) -> list[Species]:
    """Load species data from CSV file."""
    species_list = []
    with open(filepath, 'r', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        for row in reader:
            species = Species(
                scientific_name=row['scientific_name'],
                common_name=row['common_name'],
                key_identifiers=row['key_identifiers'],
                view_description=row.get('view_description', 'Lateral view'),
                color_palette=row.get('color_palette', 'natural species coloring'),
            )
            species_list.append(species)
    return species_list


def main():
    if len(sys.argv) < 2:
        print("Usage: build_icon_prompts.py <species.csv> [output.json]")
        print("\nCSV format: scientific_name,common_name,key_identifiers[,view_description,color_palette]")
        sys.exit(1)

    input_path = Path(sys.argv[1])
    output_path = Path(sys.argv[2]) if len(sys.argv) > 2 else input_path.with_suffix('.json')

    species_list = load_species_csv(input_path)

    output = {
        "species": []
    }

    for species in species_list:
        entry = {
            "scientific_name": species.scientific_name,
            "common_name": species.common_name,
            "prompts": {
                "white": build_white_prompt(species),
                "navy": build_navy_prompt(species),
            }
        }
        output["species"].append(entry)

    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump(output, f, indent=2, ensure_ascii=False)

    print(f"Generated prompts for {len(species_list)} species → {output_path}")


if __name__ == "__main__":
    main()
