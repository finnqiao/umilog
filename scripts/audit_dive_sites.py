#!/usr/bin/env python3
"""Print a concise audit summary for the curated-core dive site corpus."""

from __future__ import annotations

import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REPORT_PATH = ROOT / 'Resources' / 'SeedData' / 'curation' / 'audit_report.json'
BUILD_SCRIPT = ROOT / 'scripts' / 'build_curated_core.py'


def ensure_report() -> dict:
    if not REPORT_PATH.exists():
        subprocess.run(['python3', str(BUILD_SCRIPT)], check=True, cwd=ROOT)
    return json.loads(REPORT_PATH.read_text())


def main() -> None:
    report = ensure_report()
    source = report['source_corpus']
    curated = report['curated_core']
    print('Source corpus')
    print(f"  total_sites: {source['total_sites']}")
    print(f"  global_region_rows: {source['global_region_rows']}")
    print(f"  wreck_like_rows: {source['wreck_like_rows']}")
    print(f"  uk_wreck_like_rows: {source['uk_wreck_like_rows']}")
    print('Curated core')
    print(f"  site_count: {curated['site_count']}")
    print(f"  rows_missing_geography: {len(curated['rows_missing_geography'])}")
    print(f"  rows_with_global_region: {len(curated['rows_with_global_region'])}")
    print(f"  generic_wreck_rows: {len(curated['generic_wreck_rows'])}")
    print(f"  duplicate_clusters_within_1km: {len(curated['duplicate_clusters_within_1km'])}")
    print('Benchmark coverage')
    for item in report['benchmark_coverage']:
        print(f"  {item['destination_slug']}: {item['curated_count']}/{item['benchmark_count']} ({item['coverage']:.0%})")


if __name__ == '__main__':
    main()
