#!/usr/bin/env python3
"""
Search for dive site descriptions from the web.

Fetches information about dive sites from web search and Wikipedia
to gather raw content for LLM refinement.

Usage:
    python3 site_descriptions_search.py <sites_json> <output_json>

Example:
    python3 data/scripts/site_descriptions_search.py data/export/sites_validated.json data/raw/site_descriptions_raw.json

Output:
    - JSON with raw search results and Wikipedia extracts per site
"""

import sys
import json
import time
import urllib.parse
import urllib.request
from pathlib import Path
from datetime import datetime
from typing import Optional

# API endpoints
WIKIPEDIA_API = "https://en.wikipedia.org/w/api.php"
DUCKDUCKGO_API = "https://api.duckduckgo.com/"

# Rate limits
REQUEST_DELAY = 1.0  # Be respectful to free APIs
CHECKPOINT_INTERVAL = 100
BATCH_SIZE = 500  # Process in batches

USER_AGENT = "UmiLogBot/1.0 (dive logging app; site description enrichment)"


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


def api_get(url: str, timeout: int = 30) -> Optional[dict]:
    """Make GET request and return JSON."""
    try:
        req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
        with urllib.request.urlopen(req, timeout=timeout) as response:
            return json.loads(response.read().decode("utf-8"))
    except Exception:
        return None


def fetch_wikipedia(site_name: str, location: str = "") -> Optional[dict]:
    """Fetch Wikipedia extract for a site."""
    # Build search terms
    search_terms = [site_name]
    if location:
        search_terms.append(f"{site_name} {location}")

    for term in search_terms:
        # Search Wikipedia
        search_params = {
            "action": "query",
            "list": "search",
            "srsearch": term,
            "format": "json",
            "srlimit": 3
        }
        search_url = WIKIPEDIA_API + "?" + urllib.parse.urlencode(search_params)
        search_data = api_get(search_url)

        if not search_data or "query" not in search_data:
            continue

        results = search_data["query"].get("search", [])
        if not results:
            continue

        # Get extract for first relevant result
        for result in results:
            title = result.get("title", "")
            # Skip obviously wrong results
            if any(skip in title.lower() for skip in ["disambiguation", "list of", "category:"]):
                continue

            # Fetch extract
            extract_params = {
                "action": "query",
                "titles": title,
                "prop": "extracts",
                "exintro": "true",
                "explaintext": "true",
                "format": "json"
            }
            extract_url = WIKIPEDIA_API + "?" + urllib.parse.urlencode(extract_params)
            extract_data = api_get(extract_url)

            if extract_data and "query" in extract_data:
                pages = extract_data["query"].get("pages", {})
                for page_id, page in pages.items():
                    if page_id != "-1":
                        extract = page.get("extract", "")
                        if extract and len(extract) > 50:
                            return {
                                "source": "wikipedia",
                                "title": title,
                                "extract": extract[:2000]
                            }

    return None


def fetch_duckduckgo(site_name: str, region: str = "", country: str = "") -> Optional[dict]:
    """Fetch instant answer from DuckDuckGo."""
    # Build query
    query_parts = [f'"{site_name}"', "diving"]
    if region:
        query_parts.append(region)
    if country:
        query_parts.append(country)

    query = " ".join(query_parts)

    params = {
        "q": query,
        "format": "json",
        "no_html": "1",
        "skip_disambig": "1"
    }
    url = DUCKDUCKGO_API + "?" + urllib.parse.urlencode(params)
    data = api_get(url)

    if not data:
        return None

    # Extract relevant fields
    result = {}

    # Abstract/summary
    abstract = data.get("Abstract", "")
    if abstract:
        result["abstract"] = abstract

    # Related topics
    related = data.get("RelatedTopics", [])
    if related:
        snippets = []
        for topic in related[:5]:
            if isinstance(topic, dict):
                text = topic.get("Text", "")
                if text and "dive" in text.lower():
                    snippets.append(text)
        if snippets:
            result["related_snippets"] = snippets

    # Infobox
    infobox = data.get("Infobox", {})
    if infobox and infobox.get("content"):
        result["infobox"] = infobox.get("content", [])[:5]

    if result:
        result["source"] = "duckduckgo"
        return result

    return None


def process_site(site: dict) -> dict:
    """Process a single site to gather descriptions."""
    site_id = site.get("id") or site.get("wikidataId")
    name = site.get("name", "")
    region = site.get("region", "")
    country = site.get("country", "")
    site_type = site.get("type", "")
    existing_desc = site.get("description", "")

    result = {
        "site_id": site_id,
        "name": name,
        "region": region,
        "country": country,
        "type": site_type,
        "existing_description": existing_desc,
        "search_results": []
    }

    # Skip if we already have a good description
    if existing_desc and len(existing_desc) > 100:
        result["skipped"] = "has_description"
        return result

    # Fetch Wikipedia
    wiki_result = fetch_wikipedia(name, country)
    if wiki_result:
        result["search_results"].append(wiki_result)
    time.sleep(REQUEST_DELAY * 0.5)

    # Fetch DuckDuckGo
    ddg_result = fetch_duckduckgo(name, region, country)
    if ddg_result:
        result["search_results"].append(ddg_result)
    time.sleep(REQUEST_DELAY * 0.5)

    return result


def main():
    if len(sys.argv) != 3:
        print("Usage: site_descriptions_search.py <sites_json> <output_json>")
        sys.exit(1)

    sites_path = Path(sys.argv[1])
    output_path = Path(sys.argv[2])

    if not sites_path.exists():
        print(f"Error: Sites file not found: {sites_path}")
        sys.exit(1)

    output_path.parent.mkdir(parents=True, exist_ok=True)

    # Load sites
    print(f"Loading sites from {sites_path}...")
    with open(sites_path, "r", encoding="utf-8") as f:
        data = json.load(f)

    sites = data.get("sites", [])
    print(f"Found {len(sites)} sites")

    # Load checkpoint
    checkpoint_path = output_path.parent / ".checkpoint_site_search.json"
    checkpoint = load_checkpoint(checkpoint_path)
    processed_ids = set(checkpoint.get("processed_ids", []))
    results = checkpoint.get("results", {})

    print(f"Resuming from checkpoint: {len(processed_ids)} already processed")

    # Filter sites needing processing
    sites_to_process = []
    for site in sites:
        site_id = site.get("id") or site.get("wikidataId")
        if site_id and site_id not in processed_ids:
            # Skip sites with good descriptions
            desc = site.get("description", "")
            if not desc or len(desc) < 100:
                sites_to_process.append(site)

    print(f"Sites to process: {len(sites_to_process)}")

    # Process sites
    stats = {"searched": 0, "found": 0, "empty": 0, "skipped": 0}

    for i, site in enumerate(sites_to_process[:BATCH_SIZE]):  # Limit batch size
        site_id = site.get("id") or site.get("wikidataId")
        name = site.get("name", "Unknown")

        if i % 50 == 0:
            print(f"\nProgress: {i}/{min(len(sites_to_process), BATCH_SIZE)}")

        print(f"  [{i+1}] {name[:40]}...", end=" ")

        result = process_site(site)
        results[site_id] = result
        processed_ids.add(site_id)

        if result.get("skipped"):
            stats["skipped"] += 1
            print("skipped")
        elif result.get("search_results"):
            stats["found"] += 1
            print(f"found {len(result['search_results'])} results")
        else:
            stats["empty"] += 1
            print("no results")

        stats["searched"] += 1

        # Save checkpoint
        if (i + 1) % CHECKPOINT_INTERVAL == 0:
            checkpoint["processed_ids"] = list(processed_ids)
            checkpoint["results"] = results
            save_checkpoint(checkpoint_path, checkpoint)
            print(f"\n--- Checkpoint saved: {len(processed_ids)} total ---")

    # Final checkpoint
    checkpoint["processed_ids"] = list(processed_ids)
    checkpoint["results"] = results
    save_checkpoint(checkpoint_path, checkpoint)

    # Write output
    output = {
        "generated_at": datetime.utcnow().isoformat() + "Z",
        "total_sites": len(results),
        "with_results": stats["found"],
        "empty": stats["empty"],
        "skipped": stats["skipped"],
        "sites": results
    }

    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(output, f, indent=2, ensure_ascii=False)

    print("\n" + "=" * 50)
    print("COMPLETE")
    print("=" * 50)
    print(f"Searched:    {stats['searched']}")
    print(f"Found info:  {stats['found']}")
    print(f"No results:  {stats['empty']}")
    print(f"Skipped:     {stats['skipped']}")
    print(f"Output:      {output_path}")
    print()
    print(f"Note: Process in batches of {BATCH_SIZE}. Run again to continue.")


if __name__ == "__main__":
    main()
