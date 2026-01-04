#!/usr/bin/env python3
"""
Upload site images to Cloudflare R2.

Usage:
    python3 upload_to_r2.py <images_dir>

Prerequisites:
    - pip install boto3
    - Set environment variables:
        R2_ACCOUNT_ID
        R2_ACCESS_KEY_ID
        R2_SECRET_ACCESS_KEY
        R2_BUCKET_NAME (default: umilog-media)

Example:
    export R2_ACCOUNT_ID="your_account_id"
    export R2_ACCESS_KEY_ID="your_access_key"
    export R2_SECRET_ACCESS_KEY="your_secret_key"
    python3 data/scripts/upload_to_r2.py data/images

Output:
    Updates site_media.json with CDN URLs
"""

import sys
import os
import json
from pathlib import Path
from datetime import datetime

try:
    import boto3
    from botocore.config import Config
    HAS_BOTO3 = True
except ImportError:
    HAS_BOTO3 = False
    print("Error: boto3 not installed. Install with: pip3 install boto3")
    sys.exit(1)


# Configuration from environment
R2_ACCOUNT_ID = os.environ.get("R2_ACCOUNT_ID")
R2_ACCESS_KEY_ID = os.environ.get("R2_ACCESS_KEY_ID")
R2_SECRET_ACCESS_KEY = os.environ.get("R2_SECRET_ACCESS_KEY")
R2_BUCKET_NAME = os.environ.get("R2_BUCKET_NAME", "umilog-media")
R2_PUBLIC_URL = os.environ.get("R2_PUBLIC_URL", f"https://media.umilog.app")


def get_r2_client():
    """Create R2 S3-compatible client."""
    if not all([R2_ACCOUNT_ID, R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY]):
        print("Error: Missing R2 credentials. Set environment variables:")
        print("  R2_ACCOUNT_ID")
        print("  R2_ACCESS_KEY_ID")
        print("  R2_SECRET_ACCESS_KEY")
        sys.exit(1)

    return boto3.client(
        "s3",
        endpoint_url=f"https://{R2_ACCOUNT_ID}.r2.cloudflarestorage.com",
        aws_access_key_id=R2_ACCESS_KEY_ID,
        aws_secret_access_key=R2_SECRET_ACCESS_KEY,
        config=Config(signature_version="s3v4"),
        region_name="auto"
    )


def upload_file(client, local_path: Path, r2_key: str) -> bool:
    """Upload a single file to R2."""
    try:
        content_type = "image/webp" if local_path.suffix == ".webp" else "image/jpeg"
        client.upload_file(
            str(local_path),
            R2_BUCKET_NAME,
            r2_key,
            ExtraArgs={
                "ContentType": content_type,
                "CacheControl": "public, max-age=31536000"  # 1 year cache
            }
        )
        return True
    except Exception as e:
        print(f"  Upload failed: {e}")
        return False


def main():
    if len(sys.argv) != 2:
        print("Usage: upload_to_r2.py <images_dir>")
        print("Example: python3 data/scripts/upload_to_r2.py data/images")
        sys.exit(1)

    images_dir = Path(sys.argv[1])
    manifest_path = images_dir / "site_media.json"

    if not manifest_path.exists():
        print(f"Error: Manifest not found: {manifest_path}")
        print("Run site_images_fetch.py first to download images.")
        sys.exit(1)

    # Load manifest
    with open(manifest_path, "r", encoding="utf-8") as f:
        manifest = json.load(f)

    images = manifest.get("images", [])
    print(f"Found {len(images)} images to upload")

    # Create R2 client
    client = get_r2_client()

    # Upload images
    uploaded = 0
    failed = 0
    skipped = 0

    for i, record in enumerate(images):
        site_id = record.get("site_id")
        thumb_path = images_dir / record.get("thumb_path", "")

        if not thumb_path.exists():
            print(f"  Skipping {site_id}: file not found")
            skipped += 1
            continue

        # R2 key: sites/{site_id}/thumb.webp
        r2_key = f"sites/{site_id}/thumb.webp"

        # Check if already has CDN URL (already uploaded)
        if record.get("cdn_url"):
            skipped += 1
            continue

        print(f"Uploading {site_id}...")
        if upload_file(client, thumb_path, r2_key):
            # Update record with CDN URL
            record["cdn_url"] = f"{R2_PUBLIC_URL}/{r2_key}"
            uploaded += 1
        else:
            failed += 1

        # Progress
        if (i + 1) % 100 == 0:
            print(f"Progress: {i + 1}/{len(images)} ({uploaded} uploaded, {failed} failed)")

    # Update manifest with CDN URLs
    manifest["uploaded_at"] = datetime.utcnow().isoformat() + "Z"
    manifest["cdn_base_url"] = R2_PUBLIC_URL
    manifest["total_uploaded"] = uploaded

    with open(manifest_path, "w", encoding="utf-8") as f:
        json.dump(manifest, f, indent=2, ensure_ascii=False)

    # Also write iOS seed file format
    seed_records = []
    for record in images:
        if record.get("cdn_url"):
            seed_records.append({
                "id": f"media_{record['site_id']}",
                "siteId": record["site_id"],
                "kind": "photo",
                "url": record["cdn_url"],
                "width": record.get("width", 400),
                "height": record.get("height", 400),
                "license": record.get("license", "CC-BY-SA-4.0"),
                "attribution": record.get("attribution", "Wikimedia Commons"),
                "sourceUrl": record.get("source_url"),
                "sha256": record.get("sha256"),
                "isRedistributable": True
            })

    seed_path = images_dir / "site_media_seed.json"
    with open(seed_path, "w", encoding="utf-8") as f:
        json.dump({"media": seed_records}, f, indent=2, ensure_ascii=False)

    print()
    print(f"=== Complete ===")
    print(f"Uploaded: {uploaded}")
    print(f"Failed: {failed}")
    print(f"Skipped: {skipped}")
    print(f"Manifest updated: {manifest_path}")
    print(f"iOS seed file: {seed_path}")


if __name__ == "__main__":
    main()
