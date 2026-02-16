#!/usr/bin/env python3
"""
Fetch species reference images from FishBase.

Downloads fish photos from the FishBase database (fish species only).

Usage:
    python3 species_images_fishbase.py <species_catalog_json> <output_dir>

Example:
    python3 data/scripts/species_images_fishbase.py data/export/species_catalog_full.json data/images/species_refs

Output:
    - Images in output_dir/{species_id}/fishbase_{n}.jpg
    - Manifest: output_dir/species_images_fishbase.json
"""

import sys
import json
import time
import hashlib
import urllib.parse
import urllib.request
from pathlib import Path
from datetime import datetime
from typing import Optional

# Constants
FISHBASE_API = "https://fishbase.ropensci.org"
PHOTOS_PER_SPECIES = 3
REQUEST_DELAY = 0.2  # seconds between requests (10/sec allowed)
MAX_DOWNLOAD_SIZE = 15 * 1024 * 1024
USER_AGENT = "UmiLogBot/1.0 (dive logging app; species reference image fetcher)"
CHECKPOINT_INTERVAL = 50

# Fish categories in our catalog
FISH_CATEGORIES = {"fish", "Fish"}


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


def api_request(endpoint: str, params: dict = None) -> Optional[dict]:
    """Make a request to FishBase API."""
    url = f"{FISHBASE_API}/{endpoint}"
    if params:
        url += "?" + urllib.parse.urlencode(params)

    try:
        req = urllib.request.Request(url, headers={
            "User-Agent": USER_AGENT,
            "Accept": "application/json"
        })
        with urllib.request.urlopen(req, timeout=30) as response:
            return json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        if e.code == 404:
            return None
        print(f"  API error {e.code}: {e.reason}")
        return None
    except Exception as e:
        print(f"  Request failed: {e}")
        return None


def search_species(scientific_name: str) -> Optional[int]:
    """Search for species SpecCode by scientific name."""
    # Parse genus and species from scientific name
    parts = scientific_name.split()
    if len(parts) < 2:
        return None

    genus = parts[0]
    species = parts[1]

    # Search by genus and species
    data = api_request("species", {"Genus": genus, "Species": species})

    if not data or not data.get("data"):
        # Try by scientific name directly
        data = api_request("species", {"ScientificName": scientific_name})

    if data and data.get("data"):
        return data["data"][0].get("SpecCode")

    return None


def fetch_photos(spec_code: int) -> list[dict]:
    """Fetch photos for a species by SpecCode."""
    data = api_request("picturesmain", {"SpecCode": spec_code})

    if not data or not data.get("data"):
        return []

    photos = []
    for pic in data["data"]:
        pic_num = pic.get("PicName", "")
        if not pic_num:
            continue

        # Construct image URL
        # FishBase images are at: https://www.fishbase.se/images/species/{PicName}
        image_url = f"https://www.fishbase.se/images/species/{pic_num}"

        photos.append({
            "url": image_url,
            "pic_name": pic_num,
            "author": pic.get("AuthName", ""),
            "locality": pic.get("Locality", ""),
            "sex": pic.get("Sex", ""),
            "remarks": pic.get("Remarks", "")
        })

    return photos[:PHOTOS_PER_SPECIES]


def download_image(url: str, output_path: Path) -> Optional[str]:
    """Download image and return SHA256 hash."""
    try:
        req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
        with urllib.request.urlopen(req, timeout=60) as response:
            content_length = response.headers.get("Content-Length")
            if content_length and int(content_length) > MAX_DOWNLOAD_SIZE:
                return None

            data = response.read()
            if len(data) > MAX_DOWNLOAD_SIZE or len(data) < 1000:
                return None

            output_path.parent.mkdir(parents=True, exist_ok=True)
            with open(output_path, "wb") as f:
                f.write(data)

            return hashlib.sha256(data).hexdigest()

    except Exception as e:
        print(f"    Download failed: {e}")
        return None


def process_species(species: dict, output_dir: Path) -> Optional[dict]:
    """Process a single fish species."""
    species_id = species.get("id")
    scientific_name = species.get("scientificName")
    common_name = species.get("name")
    category = species.get("category", "")

    # Skip non-fish species
    if category not in FISH_CATEGORIES:
        return None

    if not species_id or not scientific_name:
        return None

    print(f"\nProcessing: {common_name} ({scientific_name})")

    # Check if we have a fishbase_id already
    fishbase_id = species.get("fishbaseId") or species.get("fishbase_id")

    if not fishbase_id:
        # Search for SpecCode
        fishbase_id = search_species(scientific_name)
        time.sleep(REQUEST_DELAY)

    if not fishbase_id:
        print("  No FishBase record found")
        return {"species_id": species_id, "photos": [], "error": "not_found"}

    print(f"  Found SpecCode: {fishbase_id}")

    # Fetch photos
    photos = fetch_photos(fishbase_id)
    time.sleep(REQUEST_DELAY)

    if not photos:
        print("  No photos available")
        return {"species_id": species_id, "spec_code": fishbase_id, "photos": [], "error": "no_photos"}

    print(f"  Found {len(photos)} photos, downloading...")

    # Download photos
    downloaded = []
    species_dir = output_dir / species_id

    for i, photo in enumerate(photos):
        filename = f"fishbase_{i + 1}.jpg"
        output_path = species_dir / filename

        # Skip if cached
        if output_path.exists():
            print(f"    {filename}: cached")
            with open(output_path, "rb") as f:
                sha256 = hashlib.sha256(f.read()).hexdigest()
            downloaded.append({
                "source": "fishbase",
                "url": photo["url"],
                "author": photo["author"],
                "locality": photo["locality"],
                "local_path": str(output_path.relative_to(output_dir)),
                "sha256": sha256,
                "cached": True
            })
            continue

        sha256 = download_image(photo["url"], output_path)

        if sha256:
            print(f"    {filename}: downloaded")
            downloaded.append({
                "source": "fishbase",
                "url": photo["url"],
                "author": photo["author"],
                "locality": photo["locality"],
                "local_path": str(output_path.relative_to(output_dir)),
                "sha256": sha256,
                "cached": False
            })
            time.sleep(REQUEST_DELAY)

    return {
        "species_id": species_id,
        "scientific_name": scientific_name,
        "common_name": common_name,
        "spec_code": fishbase_id,
        "photos": downloaded,
        "photo_count": len(downloaded)
    }


def main():
    if len(sys.argv) != 3:
        print("Usage: species_images_fishbase.py <species_catalog_json> <output_dir>")
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

    # Filter to fish only
    fish_species = [s for s in species_list if s.get("category") in FISH_CATEGORIES]
    print(f"Found {len(fish_species)} fish species (of {len(species_list)} total)")

    # Setup output directory
    output_dir.mkdir(parents=True, exist_ok=True)

    # Load checkpoint
    checkpoint_path = output_dir / ".checkpoint_fishbase.json"
    checkpoint = load_checkpoint(checkpoint_path)
    processed_ids = set(checkpoint.get("processed_ids", []))
    results = checkpoint.get("results", {})

    print(f"Resuming from checkpoint: {len(processed_ids)} already processed")

    # Process fish species
    stats = {"success": 0, "not_found": 0, "no_photos": 0, "failed": 0, "skipped": 0}

    for i, species in enumerate(fish_species):
        species_id = species.get("id")

        if species_id in processed_ids:
            stats["skipped"] += 1
            continue

        result = process_species(species, output_dir)

        if result:
            results[species_id] = result
            processed_ids.add(species_id)

            if result.get("error") == "not_found":
                stats["not_found"] += 1
            elif result.get("error") == "no_photos":
                stats["no_photos"] += 1
            elif result.get("photo_count", 0) > 0:
                stats["success"] += 1
            else:
                stats["failed"] += 1
        else:
            # Non-fish species skipped
            pass

        # Save checkpoint
        if (i + 1) % CHECKPOINT_INTERVAL == 0:
            checkpoint["processed_ids"] = list(processed_ids)
            checkpoint["results"] = results
            save_checkpoint(checkpoint_path, checkpoint)
            print(f"\n--- Checkpoint saved: {len(processed_ids)}/{len(fish_species)} ---")

    # Final checkpoint
    checkpoint["processed_ids"] = list(processed_ids)
    checkpoint["results"] = results
    save_checkpoint(checkpoint_path, checkpoint)

    # Write manifest
    manifest = {
        "source": "FishBase",
        "generated_at": datetime.utcnow().isoformat() + "Z",
        "species_count": len(results),
        "total_photos": sum(r.get("photo_count", 0) for r in results.values()),
        "species": results
    }

    manifest_path = output_dir / "species_images_fishbase.json"
    with open(manifest_path, "w", encoding="utf-8") as f:
        json.dump(manifest, f, indent=2, ensure_ascii=False)

    print("\n" + "=" * 50)
    print("COMPLETE")
    print("=" * 50)
    print(f"Species with photos: {stats['success']}")
    print(f"Not in FishBase:     {stats['not_found']}")
    print(f"No photos available: {stats['no_photos']}")
    print(f"Failed:              {stats['failed']}")
    print(f"Skipped (cached):    {stats['skipped']}")
    print(f"Total photos:        {manifest['total_photos']}")
    print(f"Manifest: {manifest_path}")


if __name__ == "__main__":
    main()
