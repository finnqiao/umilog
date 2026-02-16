#!/usr/bin/env python3
"""
Generate region descriptions and taglines.

Creates compelling descriptions for dive regions to inspire travel.

Usage:
    python3 region_descriptions.py <regions_json> <sites_json> <species_json> <output_json>

Example:
    python3 data/scripts/region_descriptions.py Resources/SeedData/regions.json data/export/sites_validated.json data/export/species_catalog_full.json data/export/regions_enriched.json

Environment:
    GEMINI_API_KEY - Google Gemini API key

Output:
    - JSON with enriched region data including taglines and descriptions
"""

import json
import os
import sys
import time
from pathlib import Path
from datetime import datetime
from collections import defaultdict

# Lazy import for google-genai
_genai = None


def get_genai():
    """Lazy import google.genai."""
    global _genai
    if _genai is None:
        try:
            from google import genai
            _genai = genai
        except ImportError:
            raise ImportError(
                "google-genai is required. Install with: pip install google-genai"
            )
    return _genai


MODEL = "gemini-2.0-flash"

SYSTEM_PROMPT = """You are a dive travel expert creating inspiring descriptions for dive regions.

Given statistics and information about a dive region, create:
1. A tagline (max 10 words) - evocative but not hyperbolic
2. A description (2-3 sentences) - informative and inspiring
3. 3-5 highlights - key attractions for divers

Output as JSON:
{
  "tagline": "short evocative tagline",
  "description": "2-3 sentence description of diving in this region",
  "highlights": ["highlight 1", "highlight 2", "highlight 3"],
  "best_season": "when to dive here (if known)",
  "typical_conditions": "water temp, visibility, currents"
}

Be factual and inspiring without using superlatives like "best" or "incredible"."""


def aggregate_region_stats(regions: list, sites: list, species: list) -> dict:
    """Aggregate statistics per region."""
    stats = defaultdict(lambda: {
        "site_count": 0,
        "site_types": defaultdict(int),
        "countries": set(),
        "species_ids": set(),
        "species_count": 0
    })

    # Count sites per region
    for site in sites:
        region_id = site.get("region") or site.get("region_id")
        if region_id:
            # Normalize region ID
            region_id = region_id.lower().replace(" ", "-")
            stats[region_id]["site_count"] += 1
            site_type = site.get("type", "Unknown")
            stats[region_id]["site_types"][site_type] += 1
            country = site.get("country", "")
            if country:
                stats[region_id]["countries"].add(country)

    # Count species per region
    for sp in species:
        regions_list = sp.get("regions", [])
        for region_id in regions_list:
            if region_id:
                region_id = region_id.lower().replace(" ", "-")
                stats[region_id]["species_ids"].add(sp.get("id"))

    # Calculate species counts
    for region_id in stats:
        stats[region_id]["species_count"] = len(stats[region_id]["species_ids"])
        stats[region_id]["countries"] = list(stats[region_id]["countries"])
        stats[region_id]["site_types"] = dict(stats[region_id]["site_types"])
        del stats[region_id]["species_ids"]

    return dict(stats)


def build_prompt(region: dict, stats: dict) -> str:
    """Build prompt for region description generation."""
    parts = []

    name = region.get("name", "")
    region_id = region.get("id", "")

    parts.append(f"Region: {name}")

    # Get stats for this region
    region_stats = stats.get(region_id, stats.get(region_id.lower().replace(" ", "-"), {}))

    if region_stats:
        parts.append(f"Number of dive sites: {region_stats.get('site_count', 0)}")
        parts.append(f"Number of species: {region_stats.get('species_count', 0)}")

        site_types = region_stats.get("site_types", {})
        if site_types:
            type_str = ", ".join(f"{k}: {v}" for k, v in sorted(site_types.items(), key=lambda x: -x[1])[:5])
            parts.append(f"Site types: {type_str}")

        countries = region_stats.get("countries", [])
        if countries:
            parts.append(f"Countries: {', '.join(countries[:10])}")

    # Add any existing description
    existing = region.get("description", "")
    if existing:
        parts.append(f"Existing info: {existing}")

    return "\n".join(parts)


def generate_description(client, region: dict, stats: dict) -> dict:
    """Generate region description using Gemini."""
    prompt = build_prompt(region, stats)

    try:
        response = client.models.generate_content(
            model=MODEL,
            contents=[
                {"role": "user", "parts": [{"text": SYSTEM_PROMPT}]},
                {"role": "model", "parts": [{"text": "I'll create inspiring descriptions for dive regions. Please share the region details."}]},
                {"role": "user", "parts": [{"text": prompt}]}
            ],
            config={
                "temperature": 0.5,
                "max_output_tokens": 512
            }
        )

        text = response.text.strip()

        # Handle markdown code blocks
        if "```json" in text:
            text = text.split("```json")[1].split("```")[0].strip()
        elif "```" in text:
            text = text.split("```")[1].split("```")[0].strip()

        return json.loads(text)

    except Exception as e:
        print(f"    Error: {e}")
        return {}


def main():
    if len(sys.argv) != 5:
        print("Usage: region_descriptions.py <regions_json> <sites_json> <species_json> <output_json>")
        sys.exit(1)

    regions_path = Path(sys.argv[1])
    sites_path = Path(sys.argv[2])
    species_path = Path(sys.argv[3])
    output_path = Path(sys.argv[4])

    for path in [regions_path, sites_path, species_path]:
        if not path.exists():
            print(f"Error: File not found: {path}")
            sys.exit(1)

    # Check API key
    api_key = os.environ.get("GEMINI_API_KEY")
    if not api_key:
        print("Error: GEMINI_API_KEY environment variable not set")
        sys.exit(1)

    output_path.parent.mkdir(parents=True, exist_ok=True)

    # Initialize Gemini
    genai = get_genai()
    client = genai.Client(api_key=api_key)

    # Load data
    print("Loading data...")
    with open(regions_path, "r", encoding="utf-8") as f:
        regions_data = json.load(f)
    with open(sites_path, "r", encoding="utf-8") as f:
        sites_data = json.load(f)
    with open(species_path, "r", encoding="utf-8") as f:
        species_data = json.load(f)

    regions = regions_data.get("regions", regions_data) if isinstance(regions_data, dict) else regions_data
    sites = sites_data.get("sites", [])
    species = species_data.get("species", [])

    print(f"Regions: {len(regions)}, Sites: {len(sites)}, Species: {len(species)}")

    # Aggregate stats
    print("Aggregating region statistics...")
    stats = aggregate_region_stats(regions, sites, species)

    # Process regions
    print("\nGenerating descriptions...")
    enriched_regions = []

    for i, region in enumerate(regions):
        name = region.get("name", "Unknown")
        region_id = region.get("id", "")

        print(f"\n[{i+1}/{len(regions)}] {name}")

        # Get stats
        region_stats = stats.get(region_id, stats.get(region_id.lower().replace(" ", "-"), {}))
        print(f"    Sites: {region_stats.get('site_count', 0)}, Species: {region_stats.get('species_count', 0)}")

        # Generate description
        generated = generate_description(client, region, stats)

        if generated:
            enriched = {
                **region,
                "tagline": generated.get("tagline", ""),
                "description": generated.get("description", ""),
                "highlights": generated.get("highlights", []),
                "best_season": generated.get("best_season", ""),
                "typical_conditions": generated.get("typical_conditions", ""),
                "site_count": region_stats.get("site_count", 0),
                "species_count": region_stats.get("species_count", 0)
            }
            print(f"    Tagline: {enriched['tagline']}")
        else:
            enriched = {
                **region,
                "site_count": region_stats.get("site_count", 0),
                "species_count": region_stats.get("species_count", 0)
            }
            print("    Failed to generate")

        enriched_regions.append(enriched)
        time.sleep(4)  # Conservative rate limit for small batch

    # Write output
    output = {
        "generated_at": datetime.utcnow().isoformat() + "Z",
        "total_regions": len(enriched_regions),
        "regions": enriched_regions
    }

    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(output, f, indent=2, ensure_ascii=False)

    print("\n" + "=" * 50)
    print("COMPLETE")
    print("=" * 50)
    print(f"Regions processed: {len(enriched_regions)}")
    print(f"Output: {output_path}")


if __name__ == "__main__":
    main()
