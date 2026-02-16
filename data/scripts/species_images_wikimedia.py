#!/usr/bin/env python3
"""
Fetch species reference images from Wikimedia Commons.

Searches for CC-licensed species photos as a fallback/supplement to iNaturalist.

Usage:
    python3 species_images_wikimedia.py <species_catalog_json> <output_dir>

Example:
    python3 data/scripts/species_images_wikimedia.py data/export/species_catalog_full.json data/images/species_refs

Output:
    - Images in output_dir/{species_id}/wiki_{n}.jpg
    - Manifest: output_dir/species_images_wikimedia.json
"""

import sys
import json
import os
import time
import hashlib
import urllib.parse
import urllib.request
from pathlib import Path
from datetime import datetime
from typing import Optional

# Constants
COMMONS_API = "https://commons.wikimedia.org/w/api.php"
PHOTOS_PER_SPECIES = 3  # Fewer than iNat since it's a fallback
REQUEST_DELAY = 0.5  # seconds between requests (200/min allowed)
MAX_DOWNLOAD_SIZE = 15 * 1024 * 1024  # 15MB max
USER_AGENT = "UmiLogBot/1.0 (dive logging app; species reference image fetcher)"
CHECKPOINT_INTERVAL = 50

# Image extensions to accept
VALID_EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp"}


def load_checkpoint(checkpoint_path: Path) -> dict:
    """Load processing checkpoint if exists."""
    if checkpoint_path.exists():
        with open(checkpoint_path, "r", encoding="utf-8") as f:
            return json.load(f)
    return {"processed_ids": [], "results": {}}


def save_checkpoint(checkpoint_path: Path, data: dict):
    """Save processing checkpoint."""
    with open(checkpoint_path, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)


def api_request(params: dict) -> Optional[dict]:
    """Make a request to Wikimedia Commons API."""
    params["format"] = "json"
    url = COMMONS_API + "?" + urllib.parse.urlencode(params)

    try:
        req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
        with urllib.request.urlopen(req, timeout=30) as response:
            return json.loads(response.read().decode("utf-8"))
    except Exception as e:
        print(f"  API error: {e}")
        return None


def search_species_images(scientific_name: str, common_name: str) -> list[dict]:
    """Search Wikimedia Commons for species images."""
    images = []

    # Try scientific name first, then common name
    search_terms = [scientific_name]
    if common_name and common_name.lower() != scientific_name.lower():
        search_terms.append(common_name)

    for term in search_terms:
        if len(images) >= PHOTOS_PER_SPECIES:
            break

        # Search for images
        data = api_request({
            "action": "query",
            "list": "search",
            "srsearch": f"{term} filetype:bitmap",
            "srnamespace": "6",  # File namespace
            "srlimit": 10
        })

        if not data or "query" not in data:
            continue

        for result in data["query"].get("search", []):
            if len(images) >= PHOTOS_PER_SPECIES:
                break

            title = result.get("title", "")
            if not title.startswith("File:"):
                continue

            # Check extension
            ext = Path(title).suffix.lower()
            if ext not in VALID_EXTENSIONS:
                continue

            images.append({"title": title, "search_term": term})

    return images


def get_image_info(titles: list[str]) -> dict:
    """Get image URLs and license info for multiple files."""
    if not titles:
        return {}

    data = api_request({
        "action": "query",
        "titles": "|".join(titles),
        "prop": "imageinfo|categories",
        "iiprop": "url|size|extmetadata",
        "iiurlwidth": 1024  # Request 1024px wide version
    })

    if not data or "query" not in data:
        return {}

    results = {}
    pages = data["query"].get("pages", {})

    for page_id, page in pages.items():
        if page_id == "-1":
            continue

        title = page.get("title", "")
        imageinfo = page.get("imageinfo", [{}])[0]

        if not imageinfo:
            continue

        # Extract metadata
        extmeta = imageinfo.get("extmetadata", {})
        license_short = extmeta.get("LicenseShortName", {}).get("value", "")
        artist = extmeta.get("Artist", {}).get("value", "")
        description = extmeta.get("ImageDescription", {}).get("value", "")

        # Get URL (prefer thumburl for reasonable size)
        url = imageinfo.get("thumburl") or imageinfo.get("url", "")

        if url:
            results[title] = {
                "url": url,
                "width": imageinfo.get("thumbwidth") or imageinfo.get("width"),
                "height": imageinfo.get("thumbheight") or imageinfo.get("height"),
                "license": license_short,
                "artist": artist[:200] if artist else "",
                "description": description[:500] if description else ""
            }

    return results


def download_image(url: str, output_path: Path) -> Optional[str]:
    """Download image and return SHA256 hash."""
    try:
        req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
        with urllib.request.urlopen(req, timeout=60) as response:
            content_length = response.headers.get("Content-Length")
            if content_length and int(content_length) > MAX_DOWNLOAD_SIZE:
                return None

            data = response.read()
            if len(data) > MAX_DOWNLOAD_SIZE:
                return None

            output_path.parent.mkdir(parents=True, exist_ok=True)
            with open(output_path, "wb") as f:
                f.write(data)

            return hashlib.sha256(data).hexdigest()

    except Exception as e:
        print(f"    Download failed: {e}")
        return None


def process_species(species: dict, output_dir: Path) -> Optional[dict]:
    """Process a single species: search and download images."""
    species_id = species.get("id")
    scientific_name = species.get("scientificName")
    common_name = species.get("name")

    if not species_id or not scientific_name:
        return None

    print(f"\nProcessing: {common_name} ({scientific_name})")

    # Search for images
    search_results = search_species_images(scientific_name, common_name)
    time.sleep(REQUEST_DELAY)

    if not search_results:
        print("  No images found")
        return {"species_id": species_id, "photos": [], "error": "no_results"}

    # Get image info
    titles = [r["title"] for r in search_results]
    image_info = get_image_info(titles)
    time.sleep(REQUEST_DELAY)

    if not image_info:
        print("  No image info retrieved")
        return {"species_id": species_id, "photos": [], "error": "no_info"}

    print(f"  Found {len(image_info)} images, downloading...")

    # Download images
    downloaded = []
    species_dir = output_dir / species_id

    for i, (title, info) in enumerate(image_info.items()):
        if len(downloaded) >= PHOTOS_PER_SPECIES:
            break

        filename = f"wiki_{i + 1}.jpg"
        output_path = species_dir / filename

        # Skip if already exists
        if output_path.exists():
            print(f"    {filename}: cached")
            with open(output_path, "rb") as f:
                sha256 = hashlib.sha256(f.read()).hexdigest()
            downloaded.append({
                "source": "wikimedia_commons",
                "title": title,
                "url": info["url"],
                "license": info["license"],
                "artist": info["artist"],
                "local_path": str(output_path.relative_to(output_dir)),
                "sha256": sha256,
                "cached": True
            })
            continue

        sha256 = download_image(info["url"], output_path)

        if sha256:
            print(f"    {filename}: downloaded")
            downloaded.append({
                "source": "wikimedia_commons",
                "title": title,
                "url": info["url"],
                "license": info["license"],
                "artist": info["artist"],
                "local_path": str(output_path.relative_to(output_dir)),
                "sha256": sha256,
                "cached": False
            })
            time.sleep(REQUEST_DELAY * 0.5)

    return {
        "species_id": species_id,
        "scientific_name": scientific_name,
        "common_name": common_name,
        "photos": downloaded,
        "photo_count": len(downloaded)
    }


def main():
    if len(sys.argv) != 3:
        print("Usage: species_images_wikimedia.py <species_catalog_json> <output_dir>")
        sys.exit(1)

    catalog_path = Path(sys.argv[1])
    output_dir = Path(sys.argv[2])

    if not catalog_path.exists():
        print(f"Error: Species catalog not found: {catalog_path}")
        sys.exit(1)

    # Load species catalog
    print(f"Loading species catalog from {catalog_path}...")
    with open(catalog_path, "r", encoding="utf-8") as f:
        data = json.load(f)

    species_list = data.get("species", [])
    print(f"Found {len(species_list)} species")

    # Setup output directory
    output_dir.mkdir(parents=True, exist_ok=True)

    # Load checkpoint
    checkpoint_path = output_dir / ".checkpoint_wikimedia.json"
    checkpoint = load_checkpoint(checkpoint_path)
    processed_ids = set(checkpoint.get("processed_ids", []))
    results = checkpoint.get("results", {})

    print(f"Resuming from checkpoint: {len(processed_ids)} already processed")

    # Process species
    stats = {"success": 0, "no_results": 0, "failed": 0, "skipped": 0}

    for i, species in enumerate(species_list):
        species_id = species.get("id")

        if species_id in processed_ids:
            stats["skipped"] += 1
            continue

        result = process_species(species, output_dir)

        if result:
            results[species_id] = result
            processed_ids.add(species_id)

            if result.get("photo_count", 0) > 0:
                stats["success"] += 1
            elif result.get("error"):
                stats["no_results"] += 1
            else:
                stats["failed"] += 1
        else:
            stats["failed"] += 1

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

    # Write manifest
    manifest = {
        "source": "Wikimedia Commons",
        "generated_at": datetime.utcnow().isoformat() + "Z",
        "species_count": len(results),
        "total_photos": sum(r.get("photo_count", 0) for r in results.values()),
        "species": results
    }

    manifest_path = output_dir / "species_images_wikimedia.json"
    with open(manifest_path, "w", encoding="utf-8") as f:
        json.dump(manifest, f, indent=2, ensure_ascii=False)

    print("\n" + "=" * 50)
    print("COMPLETE")
    print("=" * 50)
    print(f"Species with photos: {stats['success']}")
    print(f"No results found:    {stats['no_results']}")
    print(f"Failed:              {stats['failed']}")
    print(f"Skipped (cached):    {stats['skipped']}")
    print(f"Total photos:        {manifest['total_photos']}")
    print(f"Manifest: {manifest_path}")


if __name__ == "__main__":
    main()
