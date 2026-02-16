#!/usr/bin/env python3
"""
Fetch species reference images from iNaturalist.

Downloads CC-licensed, research-grade observation photos for marine species.

Usage:
    python3 species_images_inaturalist.py <species_catalog_json> <output_dir>

Example:
    python3 data/scripts/species_images_inaturalist.py data/export/species_catalog_full.json data/images/species_refs

Output:
    - Images in output_dir/{species_id}/inat_{n}.jpg
    - Manifest: output_dir/species_images_inaturalist.json
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
INAT_API = "https://api.inaturalist.org/v1"
PHOTOS_PER_SPECIES = 5  # Target number of photos per species
REQUEST_DELAY = 1.0  # seconds between requests (respect rate limit: 60/min)
MAX_DOWNLOAD_SIZE = 15 * 1024 * 1024  # 15MB max per image
USER_AGENT = "UmiLogBot/1.0 (dive logging app; species reference image fetcher)"
CHECKPOINT_INTERVAL = 25  # Save progress every N species

# CC licenses accepted
ALLOWED_LICENSES = [
    "cc-by", "cc-by-nc", "cc-by-sa", "cc-by-nc-sa", "cc0", "cc-by-nd", "cc-by-nc-nd"
]


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


def api_request(endpoint: str, params: dict) -> Optional[dict]:
    """Make a rate-limited request to iNaturalist API."""
    url = f"{INAT_API}/{endpoint}"
    if params:
        url += "?" + urllib.parse.urlencode(params)

    try:
        req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
        with urllib.request.urlopen(req, timeout=30) as response:
            return json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        print(f"  API error {e.code}: {e.reason}")
        return None
    except Exception as e:
        print(f"  Request failed: {e}")
        return None


def search_taxon(scientific_name: str) -> Optional[int]:
    """Search for taxon ID by scientific name."""
    data = api_request("taxa/autocomplete", {
        "q": scientific_name,
        "rank": "species,subspecies",
        "is_active": "true"
    })

    if not data or not data.get("results"):
        return None

    # Find exact or close match
    for result in data["results"]:
        if result.get("name", "").lower() == scientific_name.lower():
            return result["id"]

    # Fallback to first result if reasonable match
    first = data["results"][0]
    if first.get("matched_term", "").lower() == scientific_name.lower():
        return first["id"]

    # Accept first result if it's the only one
    if len(data["results"]) == 1:
        return first["id"]

    return None


def fetch_observation_photos(taxon_id: int, limit: int = PHOTOS_PER_SPECIES) -> list[dict]:
    """Fetch CC-licensed photos for a taxon from research-grade observations."""
    photos = []

    # Fetch observations with photos, ordered by quality (votes/faves)
    data = api_request("observations", {
        "taxon_id": taxon_id,
        "quality_grade": "research",
        "photos": "true",
        "photo_license": ",".join(ALLOWED_LICENSES),
        "per_page": limit * 3,  # Over-fetch to filter
        "order_by": "votes",
        "order": "desc",
        "identified": "true"
    })

    if not data or not data.get("results"):
        return photos

    seen_urls = set()

    for obs in data["results"]:
        for photo in obs.get("photos", []):
            if len(photos) >= limit:
                break

            license_code = photo.get("license_code")
            if not license_code or license_code.lower() not in ALLOWED_LICENSES:
                continue

            # Get large size URL
            url = photo.get("url", "")
            if not url:
                continue

            # Convert to large size (replace 'square' with 'large')
            large_url = url.replace("/square.", "/large.").replace("square.jpg", "large.jpg")

            # Skip duplicates
            if large_url in seen_urls:
                continue
            seen_urls.add(large_url)

            photos.append({
                "url": large_url,
                "license": license_code,
                "attribution": photo.get("attribution", ""),
                "photo_id": photo.get("id"),
                "observer": obs.get("user", {}).get("login", "unknown"),
                "observation_id": obs.get("id"),
                "observed_on": obs.get("observed_on"),
                "location": obs.get("place_guess", "")
            })

        if len(photos) >= limit:
            break

    return photos


def download_image(url: str, output_path: Path) -> Optional[str]:
    """Download image and return SHA256 hash."""
    try:
        req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
        with urllib.request.urlopen(req, timeout=60) as response:
            content_length = response.headers.get("Content-Length")
            if content_length and int(content_length) > MAX_DOWNLOAD_SIZE:
                print(f"    Skipping: too large ({int(content_length) // 1024}KB)")
                return None

            data = response.read()
            if len(data) > MAX_DOWNLOAD_SIZE:
                print(f"    Skipping: too large ({len(data) // 1024}KB)")
                return None

            # Ensure directory exists
            output_path.parent.mkdir(parents=True, exist_ok=True)

            with open(output_path, "wb") as f:
                f.write(data)

            return hashlib.sha256(data).hexdigest()

    except Exception as e:
        print(f"    Download failed: {e}")
        return None


def process_species(species: dict, output_dir: Path) -> Optional[dict]:
    """Process a single species: search, fetch photos, download."""
    species_id = species.get("id")
    scientific_name = species.get("scientificName")
    common_name = species.get("name")

    if not species_id or not scientific_name:
        return None

    print(f"\nProcessing: {common_name} ({scientific_name})")

    # Search for taxon
    taxon_id = search_taxon(scientific_name)
    time.sleep(REQUEST_DELAY)

    if not taxon_id:
        print(f"  No taxon found for: {scientific_name}")
        return {"species_id": species_id, "taxon_id": None, "photos": [], "error": "taxon_not_found"}

    print(f"  Found taxon ID: {taxon_id}")

    # Fetch photo metadata
    photos = fetch_observation_photos(taxon_id)
    time.sleep(REQUEST_DELAY)

    if not photos:
        print(f"  No CC-licensed photos found")
        return {"species_id": species_id, "taxon_id": taxon_id, "photos": [], "error": "no_photos"}

    print(f"  Found {len(photos)} photos, downloading...")

    # Download photos
    downloaded = []
    species_dir = output_dir / species_id

    for i, photo in enumerate(photos):
        filename = f"inat_{i + 1}.jpg"
        output_path = species_dir / filename

        # Skip if already exists
        if output_path.exists():
            print(f"    {filename}: cached")
            # Compute hash of existing file
            with open(output_path, "rb") as f:
                sha256 = hashlib.sha256(f.read()).hexdigest()
            downloaded.append({
                **photo,
                "local_path": str(output_path.relative_to(output_dir)),
                "sha256": sha256,
                "cached": True
            })
            continue

        sha256 = download_image(photo["url"], output_path)

        if sha256:
            print(f"    {filename}: downloaded")
            downloaded.append({
                **photo,
                "local_path": str(output_path.relative_to(output_dir)),
                "sha256": sha256,
                "cached": False
            })
            time.sleep(REQUEST_DELAY * 0.5)  # Shorter delay for image downloads
        else:
            print(f"    {filename}: failed")

    return {
        "species_id": species_id,
        "scientific_name": scientific_name,
        "common_name": common_name,
        "taxon_id": taxon_id,
        "photos": downloaded,
        "photo_count": len(downloaded)
    }


def main():
    if len(sys.argv) != 3:
        print("Usage: species_images_inaturalist.py <species_catalog_json> <output_dir>")
        print("Example: python3 data/scripts/species_images_inaturalist.py data/export/species_catalog_full.json data/images/species_refs")
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
    checkpoint_path = output_dir / ".checkpoint_inaturalist.json"
    checkpoint = load_checkpoint(checkpoint_path)
    processed_ids = set(checkpoint.get("processed_ids", []))
    results = checkpoint.get("results", {})

    print(f"Resuming from checkpoint: {len(processed_ids)} already processed")

    # Process species
    stats = {"success": 0, "no_taxon": 0, "no_photos": 0, "failed": 0, "skipped": 0}

    for i, species in enumerate(species_list):
        species_id = species.get("id")

        if species_id in processed_ids:
            stats["skipped"] += 1
            continue

        result = process_species(species, output_dir)

        if result:
            results[species_id] = result
            processed_ids.add(species_id)

            if result.get("error") == "taxon_not_found":
                stats["no_taxon"] += 1
            elif result.get("error") == "no_photos":
                stats["no_photos"] += 1
            elif result.get("photo_count", 0) > 0:
                stats["success"] += 1
            else:
                stats["failed"] += 1
        else:
            stats["failed"] += 1

        # Save checkpoint periodically
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
        "source": "iNaturalist",
        "generated_at": datetime.utcnow().isoformat() + "Z",
        "species_count": len(results),
        "total_photos": sum(r.get("photo_count", 0) for r in results.values()),
        "species": results
    }

    manifest_path = output_dir / "species_images_inaturalist.json"
    with open(manifest_path, "w", encoding="utf-8") as f:
        json.dump(manifest, f, indent=2, ensure_ascii=False)

    # Summary
    print("\n" + "=" * 50)
    print("COMPLETE")
    print("=" * 50)
    print(f"Species with photos: {stats['success']}")
    print(f"No taxon found:      {stats['no_taxon']}")
    print(f"No CC photos:        {stats['no_photos']}")
    print(f"Failed:              {stats['failed']}")
    print(f"Skipped (cached):    {stats['skipped']}")
    print(f"Total photos:        {manifest['total_photos']}")
    print(f"Manifest: {manifest_path}")


if __name__ == "__main__":
    main()
