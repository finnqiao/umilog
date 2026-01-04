#!/usr/bin/env python3
"""
Generate a small sample of species illustrations for audit.
Uses existing prompts from species_illustration_prompts.json
"""

import json
import os
import random
import sys
from pathlib import Path
from datetime import datetime

try:
    from google import genai
except ImportError:
    print("Error: google-genai is required. Install with: pip install google-genai")
    sys.exit(1)


def main():
    import argparse

    parser = argparse.ArgumentParser(description="Generate sample species illustrations")
    parser.add_argument("-n", "--count", type=int, default=10, help="Number of samples (default: 10)")
    parser.add_argument("--seed", type=int, help="Random seed for reproducibility")
    parser.add_argument("--dry-run", action="store_true", help="Show what would be generated")
    parser.add_argument("-o", "--output", type=Path, default=Path("data/export/sample_illustrations"),
                       help="Output directory")
    args = parser.parse_args()

    # Get API key
    api_key = os.environ.get("GEMINI_API_KEY")
    if not api_key and not args.dry_run:
        print("Error: GEMINI_API_KEY environment variable not set")
        sys.exit(1)

    # Load prompts
    prompts_file = Path(__file__).parent.parent / "data/export/species_illustration_prompts.json"
    if not prompts_file.exists():
        print(f"Error: Prompts file not found: {prompts_file}")
        sys.exit(1)

    with open(prompts_file, 'r') as f:
        data = json.load(f)

    all_prompts = data["prompts"]
    print(f"Loaded {len(all_prompts)} species prompts")

    # Random sample
    if args.seed is not None:
        random.seed(args.seed)

    sample = random.sample(all_prompts, min(args.count, len(all_prompts)))

    print(f"\nSelected {len(sample)} species for sample generation:")
    for i, sp in enumerate(sample, 1):
        print(f"  {i}. {sp['name']} ({sp['scientificName']})")

    if args.dry_run:
        print("\n[DRY RUN] Would generate images for the above species")
        return

    # Create output directory
    args.output.mkdir(parents=True, exist_ok=True)

    # Initialize client
    client = genai.Client(api_key=api_key)

    # Generate images
    print(f"\nGenerating images to: {args.output}")
    print("-" * 60)

    results = []
    for i, sp in enumerate(sample, 1):
        name = sp['name']
        scientific = sp['scientificName']
        prompt = sp['prompt']

        # Safe filename
        safe_name = scientific.lower().replace(" ", "_").replace(".", "")
        output_path = args.output / f"{safe_name}.png"

        print(f"[{i}/{len(sample)}] {name} ({scientific})...", end=" ", flush=True)

        try:
            response = client.models.generate_images(
                model="imagen-4.0-generate-001",
                prompt=prompt,
                config={
                    "number_of_images": 1,
                    "aspect_ratio": "1:1",
                    "output_mime_type": "image/png",
                }
            )

            if response.generated_images:
                image_data = response.generated_images[0].image.image_bytes
                with open(output_path, 'wb') as f:
                    f.write(image_data)
                print(f"OK -> {output_path.name}")
                results.append({"species": name, "scientific": scientific, "file": str(output_path), "status": "ok"})
            else:
                print("FAILED (no image returned)")
                results.append({"species": name, "scientific": scientific, "status": "failed", "error": "no image"})

        except Exception as e:
            print(f"ERROR: {e}")
            results.append({"species": name, "scientific": scientific, "status": "error", "error": str(e)})

    # Save manifest
    manifest_path = args.output / "sample_manifest.json"
    with open(manifest_path, 'w') as f:
        json.dump({
            "generated_at": datetime.now().isoformat(),
            "count": len(sample),
            "seed": args.seed,
            "results": results
        }, f, indent=2)

    # Summary
    ok_count = sum(1 for r in results if r["status"] == "ok")
    print("-" * 60)
    print(f"Done! Generated {ok_count}/{len(sample)} images")
    print(f"Output: {args.output}")
    print(f"Manifest: {manifest_path}")


if __name__ == "__main__":
    main()
