#!/usr/bin/env python3
"""
Enrich dive site descriptions using web scraping + Claude Haiku synthesis.

Outputs: data/stage/enrichment_checkpoint.json  (checkpoint, not committed)

Flow per site (skipped if already in checkpoint when --incremental):
  1. PADI site search scrape
  2. DuckDuckGo → ScubaBoard forum excerpts
  3. Claude Haiku synthesis → description + user_quotes + best_season

Required env: ANTHROPIC_API_KEY

Run: python3 scripts/enrich_descriptions.py [--incremental] [--limit N] [--region REGION_ID]
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
import time
import urllib.parse
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SEED_DATA = ROOT / "Resources" / "SeedData"
STAGE_DIR = ROOT / "data" / "stage"
INPUT_PATH = SEED_DATA / "canonical_site_list.json"
OUTPUT_PATH = STAGE_DIR / "enrichment_checkpoint.json"

RATE_LIMIT_S = 0.6   # ~2 req/s
CHECKPOINT_EVERY = 20


def slugify(text: str) -> str:
    return re.sub(r"-+", "-", re.sub(r"[^a-z0-9]+", "-", text.lower())).strip("-")


def site_id(region_id: str, site_name: str) -> str:
    return f"canonical_{region_id}_{slugify(site_name)}"


# ── HTTP helpers ──────────────────────────────────────────────────────────────

HEADERS = {
    "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 "
                  "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
}


def http_get(url: str, timeout: int = 10) -> str | None:
    try:
        req = urllib.request.Request(url, headers=HEADERS)
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            return resp.read().decode("utf-8", errors="ignore")
    except Exception:
        return None


# ── PADI scraping ─────────────────────────────────────────────────────────────

def scrape_padi(site_name: str, region_name: str) -> str:
    query = urllib.parse.quote_plus(f"{site_name} {region_name}")
    url = f"https://www.padi.com/dive-sites/?q={query}"
    html = http_get(url)
    if not html:
        return ""
    # Extract text from description-like blocks
    text = re.sub(r"<[^>]+>", " ", html)
    text = re.sub(r"\s+", " ", text)
    # Find sentences mentioning the site name
    sentences = re.split(r"(?<=[.!?])\s+", text)
    relevant = [s.strip() for s in sentences
                if len(s) > 40 and any(kw in s.lower() for kw in
                ["dive", "reef", "depth", "visibility", "current", "wreck", "coral", "fish", "marine"])]
    return " ".join(relevant[:8])


# ── ScubaBoard scraping ───────────────────────────────────────────────────────

def scrape_scubaboard(site_name: str, region_name: str) -> list[str]:
    query = urllib.parse.quote_plus(f'site:scubaboard.com "{site_name}" "{region_name}"')
    ddg_url = f"https://html.duckduckgo.com/html/?q={query}"
    html = http_get(ddg_url)
    if not html:
        return []

    # Extract result URLs
    urls = re.findall(r'href="(https://www\.scubaboard\.com/[^"]+)"', html)
    urls = list(dict.fromkeys(urls))[:4]  # dedupe, limit 4

    excerpts = []
    for url in urls:
        time.sleep(RATE_LIMIT_S)
        page = http_get(url)
        if not page:
            continue
        text = re.sub(r"<[^>]+>", " ", page)
        text = re.sub(r"\s+", " ", text)
        sentences = re.split(r"(?<=[.!?])\s+", text)
        dive_keywords = {"dive", "reef", "depth", "visibility", "current", "wreck",
                         "coral", "fish", "manta", "shark", "turtle", "nudibranch",
                         "surge", "thermocline", "drift", "wall", "pinnacle"}
        good = [s.strip() for s in sentences
                if len(s) >= 40 and any(kw in s.lower() for kw in dive_keywords)]
        excerpts.extend(good[:3])
        if len(excerpts) >= 10:
            break

    return excerpts[:10]


# ── Claude Haiku synthesis ────────────────────────────────────────────────────

def haiku_synthesize(site: dict, region: dict, padi_text: str, forum_excerpts: list[str]) -> dict:
    api_key = os.environ.get("ANTHROPIC_API_KEY")
    if not api_key:
        return {}

    site_meta = {
        "name": site["name"],
        "region": region["name"],
        "country": region.get("country", ""),
        "type": site.get("type", "Reef"),
        "difficulty": site.get("difficulty", "Intermediate"),
        "depth": site.get("maxDepth"),
        "tags": site.get("tags", []),
    }

    prompt_parts = [
        f"Dive site metadata: {json.dumps(site_meta)}",
    ]
    if padi_text:
        prompt_parts.append(f"PADI source text: {padi_text[:800]}")
    if forum_excerpts:
        prompt_parts.append(f"Forum excerpts from divers:\n" + "\n".join(f"- {e}" for e in forum_excerpts[:6]))

    prompt_parts.append(
        "\nBased on the above, return a JSON object with exactly these keys:\n"
        '{"description": "<2-3 sentence factual, enticing description from recreational diver perspective>",\n'
        ' "user_quotes": ["<quote 1>", "<quote 2>", "<quote 3>"],\n'
        ' "best_season": "<e.g. April-October or null>"}\n'
        "user_quotes should be cleaned versions of real forum quotes (fix grammar only, preserve voice). "
        "If no quotes available, use [].\n"
        "Return valid JSON only, no other text."
    )

    body = json.dumps({
        "model": "claude-haiku-4-5",
        "max_tokens": 512,
        "messages": [{"role": "user", "content": "\n\n".join(prompt_parts)}]
    }).encode()

    req = urllib.request.Request(
        "https://api.anthropic.com/v1/messages",
        data=body,
        headers={
            "x-api-key": api_key,
            "anthropic-version": "2023-06-01",
            "content-type": "application/json",
        },
        method="POST"
    )

    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            result = json.loads(resp.read().decode())
        text = result["content"][0]["text"].strip()
        # Strip markdown code fences if present
        text = re.sub(r"^```(?:json)?\s*", "", text)
        text = re.sub(r"\s*```$", "", text)
        return json.loads(text)
    except Exception as e:
        print(f"    Haiku error: {e}")
        return {}


# ── Main ──────────────────────────────────────────────────────────────────────

def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--incremental", action="store_true",
                        help="Skip sites already in checkpoint")
    parser.add_argument("--limit", type=int, default=None,
                        help="Stop after N sites processed")
    parser.add_argument("--region", type=str, default=None,
                        help="Only process sites in this region id")
    parser.add_argument("--no-haiku", action="store_true",
                        help="Skip Claude Haiku synthesis (scraping only)")
    args = parser.parse_args()

    if not args.no_haiku and not os.environ.get("ANTHROPIC_API_KEY"):
        print("ERROR: ANTHROPIC_API_KEY not set. Use --no-haiku to skip synthesis.")
        sys.exit(1)

    STAGE_DIR.mkdir(parents=True, exist_ok=True)
    data = json.loads(INPUT_PATH.read_text())

    checkpoint: dict = {}
    if OUTPUT_PATH.exists():
        checkpoint = json.loads(OUTPUT_PATH.read_text())
    print(f"Checkpoint: {len(checkpoint)} sites already enriched")

    queue = []
    for group in data["region_groups"]:
        for region in group.get("regions", []):
            if args.region and region["id"] != args.region:
                continue
            for site in region.get("sites", []):
                sid = site_id(region["id"], site["name"])
                if args.incremental and sid in checkpoint:
                    continue
                if site.get("description") and site.get("user_quotes"):
                    continue  # already has full enrichment in source
                queue.append((sid, site, region))

    print(f"Sites to enrich: {len(queue)}")

    processed = 0
    for sid, site, region in queue:
        if args.limit and processed >= args.limit:
            break

        print(f"[{processed+1}/{len(queue)}] {sid}", end=" ... ", flush=True)

        padi_text = scrape_padi(site["name"], region["name"])
        time.sleep(RATE_LIMIT_S)

        forum_excerpts = scrape_scubaboard(site["name"], region["name"])

        if args.no_haiku:
            enrichment = {
                "description": "",
                "user_quotes": forum_excerpts[:3],
                "best_season": site.get("best_season") or region.get("best_season"),
                "sources": ["padi" if padi_text else None, "scubaboard" if forum_excerpts else None],
                "processed_at": datetime.now(timezone.utc).isoformat(),
            }
        else:
            time.sleep(RATE_LIMIT_S)
            enrichment = haiku_synthesize(site, region, padi_text, forum_excerpts)
            enrichment["sources"] = ["padi" if padi_text else None,
                                     "scubaboard" if forum_excerpts else None,
                                     "haiku"]
            enrichment["processed_at"] = datetime.now(timezone.utc).isoformat()

        checkpoint[sid] = enrichment
        desc_preview = (enrichment.get("description") or "")[:60]
        print(f"✓ ({len(forum_excerpts)} quotes) {desc_preview!r}")
        processed += 1

        if processed % CHECKPOINT_EVERY == 0:
            OUTPUT_PATH.write_text(json.dumps(checkpoint, indent=2, ensure_ascii=False) + "\n")
            print(f"  [checkpoint saved: {len(checkpoint)} entries]")

    OUTPUT_PATH.write_text(json.dumps(checkpoint, indent=2, ensure_ascii=False) + "\n")
    print(f"\nDone. Enriched {processed} sites. Checkpoint: {len(checkpoint)} total.")


if __name__ == "__main__":
    main()
