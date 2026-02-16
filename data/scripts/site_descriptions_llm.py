#!/usr/bin/env python3
"""
Generate enticing dive site descriptions using LLM.

Refines raw search results into compelling descriptions for users.

Usage:
    python3 site_descriptions_llm.py <raw_search_json> <sites_json> <output_json>

Example:
    python3 data/scripts/site_descriptions_llm.py data/raw/site_descriptions_raw.json data/export/sites_validated.json data/export/sites_enriched.json

Environment:
    GEMINI_API_KEY - Google Gemini API key

Output:
    - JSON with enhanced site descriptions
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
MODEL = "gemini-2.0-flash"
REQUESTS_PER_MINUTE = 15
CHECKPOINT_INTERVAL = 50
BATCH_SIZE = 500

SYSTEM_PROMPT = """You are a dive travel writer creating enticing descriptions for dive sites.

Given information about a dive site, write a compelling 2-3 sentence description that:
1. Highlights what makes this site special for divers
2. Mentions key attractions (marine life, features, conditions)
3. Is factual but engaging
4. Avoids marketing superlatives like "world's best" or "incredible"

Output as JSON:
{
  "description": "2-3 sentence description",
  "highlights": ["key highlight 1", "key highlight 2", "key highlight 3"],
  "best_for": "what type of diver or experience"
}

Be concise and accurate. If limited information, focus on the site type and location."""


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


def build_prompt(site: dict, search_data: dict) -> str:
    """Build prompt from site and search data."""
    parts = []

    name = site.get("name", search_data.get("name", "Unknown"))
    region = site.get("region", search_data.get("region", ""))
    country = site.get("country", search_data.get("country", ""))
    site_type = site.get("type", search_data.get("type", ""))
    max_depth = site.get("maxDepth", "")
    difficulty = site.get("difficulty", "")
    existing = site.get("description", search_data.get("existing_description", ""))

    parts.append(f"Site: {name}")
    if region:
        parts.append(f"Region: {region}")
    if country:
        parts.append(f"Country: {country}")
    if site_type:
        parts.append(f"Type: {site_type}")
    if max_depth:
        parts.append(f"Max depth: {max_depth}m")
    if difficulty:
        parts.append(f"Difficulty: {difficulty}")
    if existing:
        parts.append(f"Existing description: {existing}")

    # Add search results
    search_results = search_data.get("search_results", [])
    for result in search_results:
        source = result.get("source", "")
        if source == "wikipedia":
            extract = result.get("extract", "")
            if extract:
                parts.append(f"Wikipedia: {extract[:800]}")
        elif source == "duckduckgo":
            abstract = result.get("abstract", "")
            if abstract:
                parts.append(f"Info: {abstract}")
            snippets = result.get("related_snippets", [])
            if snippets:
                parts.append(f"Related: {' '.join(snippets[:3])}")

    return "\n".join(parts)


def generate_description(client, site: dict, search_data: dict) -> Optional[dict]:
    """Generate site description using Gemini."""
    prompt = build_prompt(site, search_data)

    try:
        response = client.models.generate_content(
            model=MODEL,
            contents=[
                {"role": "user", "parts": [{"text": SYSTEM_PROMPT}]},
                {"role": "model", "parts": [{"text": "I'll create compelling dive site descriptions based on the provided information. Please share the site details."}]},
                {"role": "user", "parts": [{"text": prompt}]}
            ],
            config={
                "temperature": 0.4,
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

    except json.JSONDecodeError:
        return None
    except Exception as e:
        print(f"    API error: {e}")
        return None


def main():
    if len(sys.argv) != 4:
        print("Usage: site_descriptions_llm.py <raw_search_json> <sites_json> <output_json>")
        sys.exit(1)

    search_path = Path(sys.argv[1])
    sites_path = Path(sys.argv[2])
    output_path = Path(sys.argv[3])

    if not search_path.exists():
        print(f"Error: Search results not found: {search_path}")
        sys.exit(1)
    if not sites_path.exists():
        print(f"Error: Sites file not found: {sites_path}")
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
    print(f"Loading search results from {search_path}...")
    with open(search_path, "r", encoding="utf-8") as f:
        search_data = json.load(f)

    print(f"Loading sites from {sites_path}...")
    with open(sites_path, "r", encoding="utf-8") as f:
        sites_data = json.load(f)

    # Build site lookup
    sites_by_id = {}
    for site in sites_data.get("sites", []):
        site_id = site.get("id") or site.get("wikidataId")
        if site_id:
            sites_by_id[site_id] = site

    search_results = search_data.get("sites", {})
    print(f"Search results: {len(search_results)}, Sites: {len(sites_by_id)}")

    # Load checkpoint
    checkpoint_path = output_path.parent / ".checkpoint_site_llm.json"
    checkpoint = load_checkpoint(checkpoint_path)
    processed_ids = set(checkpoint.get("processed_ids", []))
    results = checkpoint.get("results", {})

    print(f"Resuming: {len(processed_ids)} already processed")

    # Rate limit delay
    delay = 60.0 / REQUESTS_PER_MINUTE

    # Process sites with search results
    sites_to_process = []
    for site_id, search_info in search_results.items():
        if site_id in processed_ids:
            continue
        if search_info.get("skipped"):
            continue
        if not search_info.get("search_results"):
            continue
        sites_to_process.append((site_id, search_info))

    print(f"Sites to process: {len(sites_to_process)}")

    stats = {"success": 0, "failed": 0, "skipped": 0}

    for i, (site_id, search_info) in enumerate(sites_to_process[:BATCH_SIZE]):
        site = sites_by_id.get(site_id, {})
        name = site.get("name", search_info.get("name", "Unknown"))

        print(f"\n[{i+1}/{min(len(sites_to_process), BATCH_SIZE)}] {name[:40]}...")

        generated = generate_description(client, site, search_info)

        if generated:
            # Merge with original site data
            enriched_site = {**site}
            enriched_site["description"] = generated.get("description", "")
            enriched_site["highlights"] = generated.get("highlights", [])
            enriched_site["best_for"] = generated.get("best_for", "")
            enriched_site["enriched"] = True

            results[site_id] = enriched_site
            stats["success"] += 1
            print(f"    OK: {generated.get('description', '')[:60]}...")
        else:
            # Keep original
            results[site_id] = {**site, "enriched": False}
            stats["failed"] += 1
            print("    Failed")

        processed_ids.add(site_id)
        time.sleep(delay)

        # Checkpoint
        if (i + 1) % CHECKPOINT_INTERVAL == 0:
            checkpoint["processed_ids"] = list(processed_ids)
            checkpoint["results"] = results
            save_checkpoint(checkpoint_path, checkpoint)
            print(f"\n--- Checkpoint: {len(processed_ids)} ---")

    # Final save
    checkpoint["processed_ids"] = list(processed_ids)
    checkpoint["results"] = results
    save_checkpoint(checkpoint_path, checkpoint)

    # Merge all sites (enriched + originals)
    final_sites = []
    for site_id, site in sites_by_id.items():
        if site_id in results:
            final_sites.append(results[site_id])
        else:
            final_sites.append(site)

    output = {
        "generated_at": datetime.utcnow().isoformat() + "Z",
        "total_sites": len(final_sites),
        "enriched_count": stats["success"],
        "sites": final_sites
    }

    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(output, f, indent=2, ensure_ascii=False)

    print("\n" + "=" * 50)
    print("COMPLETE")
    print("=" * 50)
    print(f"Success:  {stats['success']}")
    print(f"Failed:   {stats['failed']}")
    print(f"Output:   {output_path}")
    print()
    print(f"Note: Process in batches of {BATCH_SIZE}. Run again to continue.")


if __name__ == "__main__":
    main()
