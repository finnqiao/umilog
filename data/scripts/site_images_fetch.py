#!/usr/bin/env python3
"""
Fetch dive site images from Wikimedia Commons and prepare for R2 upload.

Usage:
    python3 site_images_fetch.py <sites_json> <output_dir>

Example:
    python3 data/scripts/site_images_fetch.py data/export/sites_validated.json data/images

Output:
    - Thumbnail images in output_dir/thumbs/{site_id}.webp (400x400)
    - site_media.json manifest with URLs, attribution, licensing
"""

import sys
import json
import os
import time
import hashlib
import urllib.parse
import urllib.request
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime

# Image processing - optional PIL for resize
try:
    from PIL import Image
    HAS_PIL = True
except ImportError:
    HAS_PIL = False
    print("Warning: PIL not installed. Images will not be resized. Install with: pip3 install Pillow")


# Constants
THUMB_SIZE = 400  # 400x400 pixels
MAX_DOWNLOAD_SIZE = 10 * 1024 * 1024  # 10MB max download
REQUEST_DELAY = 0.5  # seconds between requests (be respectful to Wikimedia)
MAX_WORKERS = 4  # parallel downloads
USER_AGENT = "UmiLogBot/1.0 (https://github.com/yourusername/umilog; dive site image fetcher)"


def get_commons_thumb_url(file_url: str, width: int = 800) -> str:
    """
    Convert a Special:FilePath URL to a thumbnail URL.

    Input:  http://commons.wikimedia.org/wiki/Special:FilePath/Example.jpg
    Output: https://upload.wikimedia.org/wikipedia/commons/thumb/a/ab/Example.jpg/800px-Example.jpg
    """
    # Extract filename from Special:FilePath URL
    if "Special:FilePath/" in file_url:
        filename = file_url.split("Special:FilePath/")[-1]
        filename = urllib.parse.unquote(filename)
    else:
        # Already a direct URL
        return file_url

    # Use the Wikimedia thumbnail API instead of computing hash
    # This URL will redirect to the actual thumbnail
    thumb_api = f"https://commons.wikimedia.org/wiki/Special:FilePath/{urllib.parse.quote(filename)}?width={width}"
    return thumb_api


def download_image(url: str, timeout: int = 30) -> bytes | None:
    """Download image from URL, following redirects."""
    try:
        req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
        with urllib.request.urlopen(req, timeout=timeout) as response:
            # Check content length
            content_length = response.headers.get("Content-Length")
            if content_length and int(content_length) > MAX_DOWNLOAD_SIZE:
                print(f"  Skipping: too large ({int(content_length) // 1024}KB)")
                return None

            data = response.read()
            if len(data) > MAX_DOWNLOAD_SIZE:
                print(f"  Skipping: too large ({len(data) // 1024}KB)")
                return None
            return data
    except Exception as e:
        print(f"  Download failed: {e}")
        return None


def resize_to_thumb(image_data: bytes, size: int = THUMB_SIZE) -> bytes | None:
    """Resize image to square thumbnail, convert to WebP."""
    if not HAS_PIL:
        return image_data  # Return as-is without PIL

    try:
        from io import BytesIO
        img = Image.open(BytesIO(image_data))

        # Convert to RGB if necessary (for WebP)
        if img.mode in ("RGBA", "P"):
            img = img.convert("RGB")

        # Crop to square (center crop)
        width, height = img.size
        min_dim = min(width, height)
        left = (width - min_dim) // 2
        top = (height - min_dim) // 2
        img = img.crop((left, top, left + min_dim, top + min_dim))

        # Resize
        img = img.resize((size, size), Image.LANCZOS)

        # Save as WebP
        output = BytesIO()
        img.save(output, format="WEBP", quality=80)
        return output.getvalue()
    except Exception as e:
        print(f"  Resize failed: {e}")
        return None


def process_site(site: dict, output_dir: Path) -> dict | None:
    """
    Process a single site: download image, resize, save.
    Returns media record or None if failed.
    """
    site_id = site.get("id") or site.get("wikidataId")
    image_url = site.get("imageUrl")
    commons_category = site.get("commonsCategory")

    if not site_id:
        return None
    if not image_url:
        return None

    thumb_path = output_dir / "thumbs" / f"{site_id}.webp"

    # Skip if already exists
    if thumb_path.exists():
        # Return existing record
        with open(thumb_path, "rb") as f:
            sha256 = hashlib.sha256(f.read()).hexdigest()
        return {
            "site_id": site_id,
            "thumb_path": str(thumb_path.relative_to(output_dir)),
            "width": THUMB_SIZE,
            "height": THUMB_SIZE,
            "license": "CC-BY-SA-4.0",  # Default for Wikimedia Commons
            "attribution": "Wikimedia Commons",
            "source_url": image_url,
            "sha256": sha256,
            "cached": True
        }

    print(f"Processing {site_id}: {site.get('name', 'Unknown')[:40]}...")

    # Get thumbnail URL
    thumb_url = get_commons_thumb_url(image_url, width=800)

    # Download
    image_data = download_image(thumb_url)
    if not image_data:
        return None

    # Resize to square thumbnail
    thumb_data = resize_to_thumb(image_data)
    if not thumb_data:
        return None

    # Save
    thumb_path.parent.mkdir(parents=True, exist_ok=True)
    with open(thumb_path, "wb") as f:
        f.write(thumb_data)

    # Compute hash
    sha256 = hashlib.sha256(thumb_data).hexdigest()

    return {
        "site_id": site_id,
        "thumb_path": str(thumb_path.relative_to(output_dir)),
        "width": THUMB_SIZE,
        "height": THUMB_SIZE,
        "license": "CC-BY-SA-4.0",
        "attribution": "Wikimedia Commons",
        "source_url": image_url,
        "sha256": sha256,
        "cached": False
    }


def main():
    if len(sys.argv) != 3:
        print("Usage: site_images_fetch.py <sites_json> <output_dir>")
        print("Example: python3 data/scripts/site_images_fetch.py data/export/sites_validated.json data/images")
        sys.exit(1)

    sites_path = Path(sys.argv[1])
    output_dir = Path(sys.argv[2])

    if not sites_path.exists():
        print(f"Error: Sites file not found: {sites_path}")
        sys.exit(1)

    # Load sites
    print(f"Loading sites from {sites_path}...")
    with open(sites_path, "r", encoding="utf-8") as f:
        data = json.load(f)

    sites = data.get("sites", [])
    sites_with_images = [s for s in sites if s.get("imageUrl")]

    print(f"Found {len(sites)} total sites, {len(sites_with_images)} with images")

    # Create output directory
    output_dir.mkdir(parents=True, exist_ok=True)
    (output_dir / "thumbs").mkdir(exist_ok=True)

    # Process sites
    media_records = []
    failed = 0
    cached = 0

    for i, site in enumerate(sites_with_images):
        record = process_site(site, output_dir)
        if record:
            media_records.append(record)
            if record.get("cached"):
                cached += 1
        else:
            failed += 1

        # Progress
        if (i + 1) % 50 == 0:
            print(f"Progress: {i + 1}/{len(sites_with_images)} ({len(media_records)} success, {failed} failed, {cached} cached)")

        # Rate limiting (skip for cached)
        if record and not record.get("cached"):
            time.sleep(REQUEST_DELAY)

    # Write manifest
    manifest = {
        "images": media_records,
        "generated_at": datetime.utcnow().isoformat() + "Z",
        "total_sites_with_images": len(media_records),
        "total_failed": failed,
        "thumb_size": THUMB_SIZE
    }

    manifest_path = output_dir / "site_media.json"
    with open(manifest_path, "w", encoding="utf-8") as f:
        json.dump(manifest, f, indent=2, ensure_ascii=False)

    print()
    print(f"=== Complete ===")
    print(f"Successfully processed: {len(media_records)} images")
    print(f"Failed: {failed}")
    print(f"Cached (skipped): {cached}")
    print(f"Manifest: {manifest_path}")
    print(f"Images: {output_dir / 'thumbs'}")


if __name__ == "__main__":
    main()
