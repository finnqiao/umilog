#!/usr/bin/env python3
"""
Batch generate species icons using Google Gemini Imagen API.
Supports checkpoint/resume and generates both style variants.
"""

import asyncio
import json
import os
import sys
from pathlib import Path
from datetime import datetime
from dataclasses import dataclass, field
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


@dataclass
class GenerationConfig:
    """Configuration for image generation."""
    model: str = "imagen-3.0-generate-002"  # or imagen-4.0-generate-001
    aspect_ratio: str = "1:1"
    output_mime_type: str = "image/png"
    requests_per_minute: int = 10
    max_retries: int = 3
    retry_delay: float = 2.0


@dataclass
class ManifestEntry:
    """Status tracking for a single species/style combination."""
    status: str = "pending"  # pending, done, failed
    file: Optional[str] = None
    error: Optional[str] = None
    attempts: int = 0
    timestamp: Optional[str] = None


@dataclass
class Manifest:
    """Progress manifest for checkpoint/resume."""
    total: int = 0
    completed: int = 0
    failed: int = 0
    species: dict = field(default_factory=dict)

    def to_dict(self) -> dict:
        return {
            "total": self.total,
            "completed": self.completed,
            "failed": self.failed,
            "species": {
                k: {
                    "status": v.status,
                    "file": v.file,
                    "error": v.error,
                    "attempts": v.attempts,
                    "timestamp": v.timestamp,
                }
                for k, v in self.species.items()
            }
        }

    @classmethod
    def from_dict(cls, data: dict) -> "Manifest":
        manifest = cls(
            total=data.get("total", 0),
            completed=data.get("completed", 0),
            failed=data.get("failed", 0),
        )
        for key, entry_data in data.get("species", {}).items():
            manifest.species[key] = ManifestEntry(
                status=entry_data.get("status", "pending"),
                file=entry_data.get("file"),
                error=entry_data.get("error"),
                attempts=entry_data.get("attempts", 0),
                timestamp=entry_data.get("timestamp"),
            )
        return manifest


class IconGenerator:
    """Batch icon generator with checkpoint support."""

    def __init__(
        self,
        api_key: str,
        output_dir: Path,
        config: Optional[GenerationConfig] = None,
        dry_run: bool = False,
    ):
        self.api_key = api_key
        self.output_dir = Path(output_dir)
        self.config = config or GenerationConfig()
        self.dry_run = dry_run
        self._client = None
        self._semaphore = asyncio.Semaphore(1)  # One at a time for rate limiting
        self._last_request_time = 0.0

        # Create output directories
        self.output_dir.mkdir(parents=True, exist_ok=True)
        (self.output_dir / "white").mkdir(exist_ok=True)
        (self.output_dir / "navy").mkdir(exist_ok=True)

        # Load or create manifest
        self.manifest_path = self.output_dir / "manifest.json"
        self.manifest = self._load_manifest()

    @property
    def client(self):
        """Get or create the Gemini client."""
        if self._client is None:
            genai = get_genai()
            self._client = genai.Client(api_key=self.api_key)
        return self._client

    def _load_manifest(self) -> Manifest:
        """Load existing manifest or create new one."""
        if self.manifest_path.exists():
            with open(self.manifest_path, 'r') as f:
                return Manifest.from_dict(json.load(f))
        return Manifest()

    def _save_manifest(self):
        """Save manifest to disk."""
        with open(self.manifest_path, 'w') as f:
            json.dump(self.manifest.to_dict(), f, indent=2)

    async def _rate_limit(self):
        """Enforce rate limiting."""
        import time
        min_interval = 60.0 / self.config.requests_per_minute
        now = time.time()
        elapsed = now - self._last_request_time
        if elapsed < min_interval:
            await asyncio.sleep(min_interval - elapsed)
        self._last_request_time = time.time()

    async def generate_image(self, prompt: str, output_path: Path) -> bool:
        """Generate a single image from prompt."""
        if self.dry_run:
            print(f"  [DRY RUN] Would generate: {output_path.name}")
            print(f"  Prompt preview: {prompt[:100]}...")
            return True

        async with self._semaphore:
            await self._rate_limit()

            try:
                response = self.client.models.generate_images(
                    model=self.config.model,
                    prompt=prompt,
                    config={
                        "number_of_images": 1,
                        "aspect_ratio": self.config.aspect_ratio,
                        "output_mime_type": self.config.output_mime_type,
                    }
                )

                # Save the image
                if response.generated_images:
                    image_data = response.generated_images[0].image.image_bytes
                    with open(output_path, 'wb') as f:
                        f.write(image_data)
                    return True
                else:
                    print(f"  No image generated for {output_path.name}")
                    return False

            except Exception as e:
                print(f"  Error generating {output_path.name}: {e}")
                raise

    async def process_species(
        self,
        scientific_name: str,
        common_name: str,
        prompts: dict[str, str],
    ):
        """Process a single species, generating both style variants."""
        # Sanitize filename
        safe_name = scientific_name.lower().replace(" ", "_").replace(".", "")

        for style, prompt in prompts.items():
            key = f"{scientific_name}_{style}"
            entry = self.manifest.species.get(key, ManifestEntry())

            # Skip if already done
            if entry.status == "done":
                print(f"  ✓ {style}: Already generated")
                continue

            output_path = self.output_dir / style / f"{safe_name}.png"
            entry.attempts += 1

            try:
                success = await self.generate_image(prompt, output_path)
                if success:
                    entry.status = "done"
                    entry.file = str(output_path.relative_to(self.output_dir))
                    entry.timestamp = datetime.now().isoformat()
                    self.manifest.completed += 1
                    print(f"  ✓ {style}: Generated")
                else:
                    entry.status = "failed"
                    entry.error = "No image returned"
                    self.manifest.failed += 1

            except Exception as e:
                if entry.attempts >= self.config.max_retries:
                    entry.status = "failed"
                    entry.error = str(e)
                    self.manifest.failed += 1
                    print(f"  ✗ {style}: Failed after {entry.attempts} attempts - {e}")
                else:
                    entry.status = "pending"
                    entry.error = str(e)
                    print(f"  ⚠ {style}: Attempt {entry.attempts} failed - {e}")
                    await asyncio.sleep(self.config.retry_delay * entry.attempts)

            self.manifest.species[key] = entry
            self._save_manifest()

    async def run(self, prompts_file: Path):
        """Run batch generation from prompts JSON file."""
        with open(prompts_file, 'r') as f:
            data = json.load(f)

        species_list = data["species"]
        self.manifest.total = len(species_list) * 2  # Two styles per species

        print(f"\n{'='*60}")
        print(f"Species Icon Generator")
        print(f"{'='*60}")
        print(f"Model: {self.config.model}")
        print(f"Output: {self.output_dir}")
        print(f"Species: {len(species_list)}")
        print(f"Total images: {self.manifest.total}")
        print(f"Dry run: {self.dry_run}")
        print(f"{'='*60}\n")

        for i, species in enumerate(species_list, 1):
            scientific = species["scientific_name"]
            common = species["common_name"]
            prompts = species["prompts"]

            print(f"[{i}/{len(species_list)}] {common} ({scientific})")
            await self.process_species(scientific, common, prompts)
            print()

        # Final summary
        print(f"{'='*60}")
        print(f"Complete!")
        print(f"  Generated: {self.manifest.completed}")
        print(f"  Failed: {self.manifest.failed}")
        print(f"  Manifest: {self.manifest_path}")
        print(f"{'='*60}")


def main():
    import argparse

    parser = argparse.ArgumentParser(
        description="Generate species icons using Gemini Imagen API"
    )
    parser.add_argument(
        "prompts_file",
        type=Path,
        help="JSON file with species prompts (from build_icon_prompts.py)"
    )
    parser.add_argument(
        "-o", "--output",
        type=Path,
        default=Path("species_icons"),
        help="Output directory (default: species_icons)"
    )
    parser.add_argument(
        "--model",
        default="imagen-3.0-generate-002",
        choices=["imagen-3.0-generate-002", "imagen-4.0-generate-001"],
        help="Imagen model to use"
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print what would be generated without calling API"
    )
    parser.add_argument(
        "--rpm",
        type=int,
        default=10,
        help="Requests per minute rate limit (default: 10)"
    )

    args = parser.parse_args()

    # Get API key
    api_key = os.environ.get("GEMINI_API_KEY")
    if not api_key and not args.dry_run:
        print("Error: GEMINI_API_KEY environment variable not set")
        print("Set it with: export GEMINI_API_KEY='your-api-key'")
        sys.exit(1)

    config = GenerationConfig(
        model=args.model,
        requests_per_minute=args.rpm,
    )

    generator = IconGenerator(
        api_key=api_key or "dry-run-key",
        output_dir=args.output,
        config=config,
        dry_run=args.dry_run,
    )

    asyncio.run(generator.run(args.prompts_file))


if __name__ == "__main__":
    main()
