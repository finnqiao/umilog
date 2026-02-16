#!/usr/bin/env python3
"""
Generate enhanced visual descriptions for species using LLM.

Uses Gemini API to synthesize visual descriptions from aggregated data,
optimized for accurate image generation prompts.

Usage:
    python3 species_descriptions_llm.py <visual_data_json> <output_json>

Example:
    python3 data/scripts/species_descriptions_llm.py data/export/species_visual_data.json data/export/species_descriptions_enhanced.json

Environment:
    GEMINI_API_KEY - Google Gemini API key

Output:
    - JSON with enhanced visual descriptions per species
"""

import json
import os
import sys
import time
from pathlib import Path
from datetime import datetime
from typing import Optional

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


# Configuration
MODEL = "gemini-2.0-flash"  # Fast, cheap text model
REQUESTS_PER_MINUTE = 15
CHECKPOINT_INTERVAL = 20

SYSTEM_PROMPT = """You are a marine biology expert helping create accurate visual descriptions for AI image generation.

Given species data from scientific databases, generate a structured visual description that would help an AI create an accurate illustration.

Focus on:
1. Specific colors (not generic terms like "colorful")
2. Distinctive visual patterns with locations
3. Body shape and proportions
4. Notable anatomical features
5. Size context

Output as JSON with this structure:
{
  "colors": {
    "primary": "main body color",
    "secondary": "secondary color if present",
    "accents": "accent colors/markings"
  },
  "patterns": ["list of pattern descriptions with locations"],
  "distinctive_features": ["list of notable visual features"],
  "size_cm": estimated size in cm (number),
  "body_shape": "description of body shape",
  "prompt_additions": "concise description suitable for image generation prompt"
}

Be specific and accurate. If information is uncertain, use reasonable defaults based on the species family/category."""


def load_checkpoint(checkpoint_path: Path) -> dict:
    """Load processing checkpoint."""
    if checkpoint_path.exists():
        with open(checkpoint_path, "r", encoding="utf-8") as f:
            return json.load(f)
    return {"processed_ids": [], "results": {}}


def save_checkpoint(checkpoint_path: Path, data: dict):
    """Save processing checkpoint."""
    with open(checkpoint_path, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)


def build_prompt(species_data: dict) -> str:
    """Build prompt from aggregated species data."""
    parts = []

    species_id = species_data.get("species_id", "")
    scientific_name = species_data.get("scientific_name", "")
    common_name = species_data.get("common_name", "")
    category = species_data.get("category", "")

    parts.append(f"Species: {common_name} ({scientific_name})")
    parts.append(f"Category: {category}")

    # WoRMS data
    worms = species_data.get("worms", {})
    if worms:
        classification = worms.get("classification", {})
        if classification:
            parts.append(f"Classification: {json.dumps(classification)}")
        for key, value in worms.items():
            if key != "classification" and value:
                parts.append(f"WoRMS {key}: {value}")

    # FishBase data
    fishbase = species_data.get("fishbase", {})
    if fishbase:
        parts.append("FishBase morphology:")
        for key, value in fishbase.items():
            if value:
                parts.append(f"  {key}: {value}")

    # Extracted keywords
    keywords = species_data.get("extracted_keywords", {})
    if keywords:
        if keywords.get("colors"):
            parts.append(f"Mentioned colors: {', '.join(keywords['colors'])}")
        if keywords.get("patterns"):
            parts.append(f"Mentioned patterns: {', '.join(keywords['patterns'])}")
        if keywords.get("features"):
            parts.append(f"Mentioned features: {', '.join(keywords['features'])}")

    # Existing description
    existing = species_data.get("existing_description", "")
    if existing:
        parts.append(f"Current description: {existing}")

    # Wikipedia extract (truncated)
    wiki = species_data.get("wikipedia_extract", "")
    if wiki:
        parts.append(f"Wikipedia: {wiki[:800]}")

    return "\n".join(parts)


def generate_description(client, species_data: dict) -> Optional[dict]:
    """Generate visual description using Gemini."""
    prompt = build_prompt(species_data)

    try:
        response = client.models.generate_content(
            model=MODEL,
            contents=[
                {"role": "user", "parts": [{"text": SYSTEM_PROMPT}]},
                {"role": "model", "parts": [{"text": "I understand. I'll generate structured visual descriptions for marine species based on the scientific data provided. Please share the species data."}]},
                {"role": "user", "parts": [{"text": prompt}]}
            ],
            config={
                "temperature": 0.3,
                "max_output_tokens": 1024
            }
        )

        # Extract JSON from response
        text = response.text.strip()

        # Handle markdown code blocks
        if "```json" in text:
            text = text.split("```json")[1].split("```")[0].strip()
        elif "```" in text:
            text = text.split("```")[1].split("```")[0].strip()

        return json.loads(text)

    except json.JSONDecodeError as e:
        print(f"    JSON parse error: {e}")
        return None
    except Exception as e:
        print(f"    API error: {e}")
        return None


def main():
    if len(sys.argv) != 3:
        print("Usage: species_descriptions_llm.py <visual_data_json> <output_json>")
        sys.exit(1)

    input_path = Path(sys.argv[1])
    output_path = Path(sys.argv[2])

    if not input_path.exists():
        print(f"Error: Input file not found: {input_path}")
        sys.exit(1)

    # Check API key
    api_key = os.environ.get("GEMINI_API_KEY")
    if not api_key:
        print("Error: GEMINI_API_KEY environment variable not set")
        sys.exit(1)

    output_path.parent.mkdir(parents=True, exist_ok=True)

    # Initialize Gemini client
    genai = get_genai()
    client = genai.Client(api_key=api_key)

    # Load input data
    print(f"Loading visual data from {input_path}...")
    with open(input_path, "r", encoding="utf-8") as f:
        data = json.load(f)

    species_data = data.get("species", {})
    print(f"Found {len(species_data)} species")

    # Load checkpoint
    checkpoint_path = output_path.parent / ".checkpoint_descriptions_llm.json"
    checkpoint = load_checkpoint(checkpoint_path)
    processed_ids = set(checkpoint.get("processed_ids", []))
    results = checkpoint.get("results", {})

    print(f"Resuming from checkpoint: {len(processed_ids)} already processed")

    # Calculate rate limit delay
    delay = 60.0 / REQUESTS_PER_MINUTE

    # Process species
    stats = {"success": 0, "failed": 0, "skipped": 0}
    species_list = list(species_data.items())

    for i, (species_id, species_info) in enumerate(species_list):
        if species_id in processed_ids:
            stats["skipped"] += 1
            continue

        common_name = species_info.get("common_name", "")
        scientific_name = species_info.get("scientific_name", "")
        print(f"\n[{i+1}/{len(species_list)}] {common_name} ({scientific_name})")

        # Generate description
        visual_desc = generate_description(client, species_info)

        if visual_desc:
            results[species_id] = {
                "species_id": species_id,
                "scientific_name": scientific_name,
                "common_name": common_name,
                "category": species_info.get("category", ""),
                "visual_description": visual_desc
            }
            stats["success"] += 1
            print(f"    Generated: {visual_desc.get('body_shape', 'OK')[:50]}...")
        else:
            # Store failure
            results[species_id] = {
                "species_id": species_id,
                "scientific_name": scientific_name,
                "common_name": common_name,
                "category": species_info.get("category", ""),
                "error": "generation_failed"
            }
            stats["failed"] += 1

        processed_ids.add(species_id)

        # Rate limit
        time.sleep(delay)

        # Save checkpoint
        if (i + 1) % CHECKPOINT_INTERVAL == 0:
            checkpoint["processed_ids"] = list(processed_ids)
            checkpoint["results"] = results
            save_checkpoint(checkpoint_path, checkpoint)
            print(f"\n--- Checkpoint saved: {len(processed_ids)}/{len(species_list)} ---")

    # Final checkpoint
    checkpoint["processed_ids"] = list(processed_ids)
    checkpoint["results"] = results
    save_checkpoint(checkpoint_path, checkpoint)

    # Write output
    output = {
        "generated_at": datetime.utcnow().isoformat() + "Z",
        "model": MODEL,
        "total_species": len(results),
        "success_count": stats["success"],
        "failed_count": stats["failed"],
        "species": results
    }

    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(output, f, indent=2, ensure_ascii=False)

    print("\n" + "=" * 50)
    print("COMPLETE")
    print("=" * 50)
    print(f"Success:  {stats['success']}")
    print(f"Failed:   {stats['failed']}")
    print(f"Skipped:  {stats['skipped']}")
    print(f"Output:   {output_path}")


if __name__ == "__main__":
    main()
