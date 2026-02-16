#!/usr/bin/env python3
"""
Merge species images from multiple sources into a unified manifest.

Consolidates images from iNaturalist, Wikimedia Commons, and FishBase,
deduplicates by hash, ranks by source quality, and prepares for deployment.

Usage:
    python3 merge_species_images.py <images_dir> <output_manifest>

Example:
    python3 data/scripts/merge_species_images.py data/images/species_refs data/export/species_reference_images.json

Output:
    - Unified manifest with ranked, deduplicated images per species
    - Stats on coverage and source distribution
"""

import sys
import json
from pathlib import Path
from datetime import datetime
from collections import defaultdict

# Source priority (higher = preferred)
SOURCE_PRIORITY = {
    "iNaturalist": 3,      # Best: research-grade, licensed, community verified
    "fishbase": 2,         # Good: authoritative for fish
    "wikimedia_commons": 1  # Fallback: variable quality
}

# Target images per species
TARGET_IMAGES = 5


def load_manifest(manifest_path: Path) -> dict:
    """Load a source manifest file."""
    if not manifest_path.exists():
        return {"species": {}}

    with open(manifest_path, "r", encoding="utf-8") as f:
        return json.load(f)


def merge_species_images(images_dir: Path) -> dict:
    """Merge images from all sources."""
    # Load all manifests
    inat_manifest = load_manifest(images_dir / "species_images_inaturalist.json")
    wiki_manifest = load_manifest(images_dir / "species_images_wikimedia.json")
    fishbase_manifest = load_manifest(images_dir / "species_images_fishbase.json")

    # Collect all species IDs
    all_species_ids = set()
    all_species_ids.update(inat_manifest.get("species", {}).keys())
    all_species_ids.update(wiki_manifest.get("species", {}).keys())
    all_species_ids.update(fishbase_manifest.get("species", {}).keys())

    print(f"Total unique species across sources: {len(all_species_ids)}")
    print(f"  iNaturalist: {len(inat_manifest.get('species', {}))}")
    print(f"  Wikimedia:   {len(wiki_manifest.get('species', {}))}")
    print(f"  FishBase:    {len(fishbase_manifest.get('species', {}))}")

    # Merge images per species
    merged = {}
    stats = {
        "total_species": 0,
        "with_images": 0,
        "without_images": 0,
        "source_counts": defaultdict(int),
        "coverage": {
            "1_image": 0,
            "2_images": 0,
            "3_images": 0,
            "4_images": 0,
            "5+_images": 0
        }
    }

    for species_id in sorted(all_species_ids):
        stats["total_species"] += 1

        # Gather photos from all sources
        all_photos = []
        seen_hashes = set()

        # iNaturalist (highest priority)
        inat_data = inat_manifest.get("species", {}).get(species_id, {})
        for photo in inat_data.get("photos", []):
            sha = photo.get("sha256", "")
            if sha and sha not in seen_hashes:
                seen_hashes.add(sha)
                all_photos.append({
                    **photo,
                    "source": "iNaturalist",
                    "priority": SOURCE_PRIORITY["iNaturalist"]
                })

        # FishBase (medium priority)
        fishbase_data = fishbase_manifest.get("species", {}).get(species_id, {})
        for photo in fishbase_data.get("photos", []):
            sha = photo.get("sha256", "")
            if sha and sha not in seen_hashes:
                seen_hashes.add(sha)
                all_photos.append({
                    **photo,
                    "source": "fishbase",
                    "priority": SOURCE_PRIORITY["fishbase"]
                })

        # Wikimedia (lowest priority)
        wiki_data = wiki_manifest.get("species", {}).get(species_id, {})
        for photo in wiki_data.get("photos", []):
            sha = photo.get("sha256", "")
            if sha and sha not in seen_hashes:
                seen_hashes.add(sha)
                all_photos.append({
                    **photo,
                    "source": "wikimedia_commons",
                    "priority": SOURCE_PRIORITY["wikimedia_commons"]
                })

        # Sort by priority (descending) and take top N
        all_photos.sort(key=lambda p: p.get("priority", 0), reverse=True)
        selected = all_photos[:TARGET_IMAGES]

        # Get species metadata from any source
        scientific_name = (
            inat_data.get("scientific_name") or
            fishbase_data.get("scientific_name") or
            wiki_data.get("scientific_name") or
            ""
        )
        common_name = (
            inat_data.get("common_name") or
            fishbase_data.get("common_name") or
            wiki_data.get("common_name") or
            ""
        )

        merged[species_id] = {
            "species_id": species_id,
            "scientific_name": scientific_name,
            "common_name": common_name,
            "photo_count": len(selected),
            "sources": list(set(p.get("source", "") for p in selected)),
            "photos": selected
        }

        # Update stats
        if selected:
            stats["with_images"] += 1
            for photo in selected:
                stats["source_counts"][photo.get("source", "unknown")] += 1

            count = len(selected)
            if count >= 5:
                stats["coverage"]["5+_images"] += 1
            else:
                stats["coverage"][f"{count}_image{'s' if count > 1 else ''}"] += 1
        else:
            stats["without_images"] += 1

    return merged, stats


def generate_r2_manifest(merged: dict, images_dir: Path) -> list:
    """Generate manifest for R2 CDN upload."""
    uploads = []

    for species_id, data in merged.items():
        for i, photo in enumerate(data.get("photos", [])):
            local_path = photo.get("local_path", "")
            if not local_path:
                continue

            full_path = images_dir / local_path
            if not full_path.exists():
                continue

            # R2 destination path
            r2_key = f"species/{species_id}/ref{i + 1}.jpg"

            uploads.append({
                "local_path": str(full_path),
                "r2_key": r2_key,
                "sha256": photo.get("sha256", ""),
                "source": photo.get("source", ""),
                "license": photo.get("license", ""),
                "attribution": photo.get("attribution", photo.get("artist", photo.get("author", "")))
            })

    return uploads


def main():
    if len(sys.argv) != 3:
        print("Usage: merge_species_images.py <images_dir> <output_manifest>")
        print("Example: python3 data/scripts/merge_species_images.py data/images/species_refs data/export/species_reference_images.json")
        sys.exit(1)

    images_dir = Path(sys.argv[1])
    output_path = Path(sys.argv[2])

    if not images_dir.exists():
        print(f"Error: Images directory not found: {images_dir}")
        sys.exit(1)

    output_path.parent.mkdir(parents=True, exist_ok=True)

    print(f"Merging species images from {images_dir}...")
    merged, stats = merge_species_images(images_dir)

    # Generate R2 upload manifest
    r2_uploads = generate_r2_manifest(merged, images_dir)

    # Build output
    output = {
        "generated_at": datetime.utcnow().isoformat() + "Z",
        "stats": {
            "total_species": stats["total_species"],
            "with_images": stats["with_images"],
            "without_images": stats["without_images"],
            "coverage_percent": round(100 * stats["with_images"] / max(stats["total_species"], 1), 1),
            "total_photos": sum(d.get("photo_count", 0) for d in merged.values()),
            "photos_by_source": dict(stats["source_counts"]),
            "coverage_distribution": stats["coverage"]
        },
        "species": merged,
        "r2_uploads": r2_uploads
    }

    # Write output
    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(output, f, indent=2, ensure_ascii=False)

    # Summary
    print("\n" + "=" * 60)
    print("MERGE COMPLETE")
    print("=" * 60)
    print(f"Total species:    {stats['total_species']}")
    print(f"With images:      {stats['with_images']} ({output['stats']['coverage_percent']}%)")
    print(f"Without images:   {stats['without_images']}")
    print(f"Total photos:     {output['stats']['total_photos']}")
    print()
    print("Photos by source:")
    for source, count in sorted(stats["source_counts"].items()):
        print(f"  {source}: {count}")
    print()
    print("Coverage distribution:")
    for bucket, count in stats["coverage"].items():
        if count > 0:
            print(f"  {bucket}: {count} species")
    print()
    print(f"R2 uploads ready: {len(r2_uploads)} files")
    print(f"Output: {output_path}")


if __name__ == "__main__":
    main()
