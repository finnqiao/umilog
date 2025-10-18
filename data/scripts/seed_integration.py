#!/usr/bin/env python3
"""
Unified seeder for comprehensive test data integration.

Integrates:
- Curated dive sites (Resources/SeedData/sites_seed.json)
- Extended dive logs (Resources/SeedData/dive_logs_extended.json)
- Extended sightings (Resources/SeedData/sightings_extended.json)

Usage:
  python3 seed_integration.py [--sites-only | --logs-only | --sightings-only] [--validate]

Environment:
  SEED_DATA_DIR: Path to seed data directory (default: Resources/SeedData)
  OUTPUT_DIR: Output directory for merged seed file (default: .)
"""

import json
import sys
import os
from datetime import datetime, timezone
from pathlib import Path
from typing import Dict, List, Any, Optional

# Configuration
SEED_DATA_DIR = os.getenv('SEED_DATA_DIR', 'Resources/SeedData')
OUTPUT_DIR = os.getenv('OUTPUT_DIR', '.')

# Expected seed files - REAL SITES ONLY (no synthetic data)
FILES = {
    'sites': f'{SEED_DATA_DIR}/sites_real_merged.json',  # 1161 REAL sites from Wikidata + OSM
    'dives': f'{SEED_DATA_DIR}/dive_logs_real_sites.json',  # 2876 realistic dives
    'sightings': f'{SEED_DATA_DIR}/sightings_real_sites.json',  # 7186 sightings
}

# Fallback versions if max not available
FILES_FALLBACK = {
    'sites': f'{SEED_DATA_DIR}/sites_expanded_200plus.json',  # 225 sites
    'dives': f'{SEED_DATA_DIR}/dive_logs_expanded_900plus.json',  # 888 dives
    'sightings': f'{SEED_DATA_DIR}/sightings_expanded_1500plus.json',  # 2746 sightings
}


def load_json(path: str) -> Optional[Dict[str, Any]]:
    """Safely load JSON file."""
    try:
        with open(path, 'r', encoding='utf-8') as f:
            return json.load(f)
    except FileNotFoundError:
        print(f"⚠️  File not found: {path}")
        return None
    except json.JSONDecodeError as e:
        print(f"❌ JSON parse error in {path}: {e}")
        return None


def validate_sites(sites: List[Dict]) -> tuple[int, int]:
    """Validate sites schema. Returns (valid, invalid)."""
    required = {'id', 'name', 'latitude', 'longitude', 'region'}
    valid, invalid = 0, 0
    
    for site in sites:
        missing = required - set(site.keys())
        if missing:
            print(f"⚠️  Site '{site.get('name', 'UNKNOWN')}' missing: {missing}")
            invalid += 1
        else:
            valid += 1
    
    return valid, invalid


def validate_dives(dives: List[Dict]) -> tuple[int, int]:
    """Validate dive logs schema. Returns (valid, invalid)."""
    required = {'id', 'siteId', 'startTime', 'maxDepth'}
    valid, invalid = 0, 0
    
    for dive in dives:
        missing = required - set(dive.keys())
        if missing:
            print(f"⚠️  Dive '{dive.get('id', 'UNKNOWN')}' missing: {missing}")
            invalid += 1
        else:
            valid += 1
    
    return valid, invalid


def validate_sightings(sightings: List[Dict]) -> tuple[int, int]:
    """Validate sightings schema. Returns (valid, invalid)."""
    required = {'id', 'diveId', 'speciesId'}
    valid, invalid = 0, 0
    
    for sight in sightings:
        missing = required - set(sight.keys())
        if missing:
            print(f"⚠️  Sighting '{sight.get('id', 'UNKNOWN')}' missing: {missing}")
            invalid += 1
        else:
            valid += 1
    
    return valid, invalid


def cross_reference_check(sites: List[Dict], dives: List[Dict], 
                         sightings: List[Dict]) -> Dict[str, Any]:
    """Verify referential integrity. Returns report."""
    site_ids = {s['id'] for s in sites}
    dive_ids = {d['id'] for d in dives}
    
    report = {
        'orphaned_dives': [],
        'orphaned_sightings': [],
        'dive_site_coverage': 0,
    }
    
    # Check dives reference valid sites
    for dive in dives:
        if dive.get('siteId') not in site_ids:
            report['orphaned_dives'].append(dive['id'])
        else:
            report['dive_site_coverage'] += 1
    
    # Check sightings reference valid dives
    for sight in sightings:
        if sight.get('diveId') not in dive_ids:
            report['orphaned_sightings'].append(sight['id'])
    
    return report


def merge_seed_data(sites_only: bool = False, logs_only: bool = False, 
                   sightings_only: bool = False, validate: bool = False) -> Dict[str, Any]:
    """Merge all seed data. Returns unified seed dict."""
    
    print("📚 Loading seed data...")
    
    sites_data = {}
    dives_data = {}
    sightings_data = {}
    
    if not logs_only and not sightings_only:
        sites_raw = load_json(FILES['sites'])
        if sites_raw:
            sites_data = sites_raw.get('sites', []) if isinstance(sites_raw, dict) else sites_raw
            print(f"✅ Loaded {len(sites_data)} sites")
    
    if not sites_only and not sightings_only:
        dives_raw = load_json(FILES['dives'])
        if dives_raw:
            dives_data = dives_raw.get('dives', []) if isinstance(dives_raw, dict) else dives_raw
            print(f"✅ Loaded {len(dives_data)} dive logs")
    
    if not sites_only and not logs_only:
        sightings_raw = load_json(FILES['sightings'])
        if sightings_raw:
            sightings_data = sightings_raw.get('sightings', []) if isinstance(sightings_raw, dict) else sightings_raw
            print(f"✅ Loaded {len(sightings_data)} sightings")
    
    # Validation
    if validate:
        print("\n🔍 Validating schemas...")
        if sites_data:
            v, i = validate_sites(sites_data)
            print(f"  Sites: {v} valid, {i} invalid")
        if dives_data:
            v, i = validate_dives(dives_data)
            print(f"  Dives: {v} valid, {i} invalid")
        if sightings_data:
            v, i = validate_sightings(sightings_data)
            print(f"  Sightings: {v} valid, {i} invalid")
        
        if sites_data and dives_data and sightings_data:
            print("\n🔗 Checking referential integrity...")
            refs = cross_reference_check(sites_data, dives_data, sightings_data)
            if refs['orphaned_dives']:
                print(f"  ⚠️  {len(refs['orphaned_dives'])} dives reference missing sites")
            if refs['orphaned_sightings']:
                print(f"  ⚠️  {len(refs['orphaned_sightings'])} sightings reference missing dives")
            print(f"  ✅ {refs['dive_site_coverage']} dives reference valid sites")
    
    # Build unified output
    output = {
        'version': '1.0',
        'generated_at': datetime.now(timezone.utc).isoformat(timespec='seconds').replace('+00:00', 'Z'),
        'stats': {
            'site_count': len(sites_data),
            'dive_count': len(dives_data),
            'sighting_count': len(sightings_data),
        }
    }
    
    if sites_data:
        output['sites'] = sites_data
    if dives_data:
        output['dives'] = dives_data
    if sightings_data:
        output['sightings'] = sightings_data
    
    return output


def save_merged(data: Dict[str, Any], output_file: str) -> bool:
    """Write merged seed data to file."""
    try:
        output_path = Path(OUTPUT_DIR) / output_file
        output_path.parent.mkdir(parents=True, exist_ok=True)
        
        with open(output_path, 'w', encoding='utf-8') as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
        
        print(f"\n✅ Wrote {len(data.get('sites', []))} sites, "
              f"{len(data.get('dives', []))} dives, "
              f"{len(data.get('sightings', []))} sightings → {output_path}")
        return True
    except Exception as e:
        print(f"❌ Failed to write {output_file}: {e}")
        return False


def main():
    """CLI entry point."""
    args = sys.argv[1:]
    
    sites_only = '--sites-only' in args
    logs_only = '--logs-only' in args
    sightings_only = '--sightings-only' in args
    validate = '--validate' in args
    
    # Validation
    if sum([sites_only, logs_only, sightings_only]) > 1:
        print("❌ Use at most one filter (--sites-only, --logs-only, --sightings-only)")
        sys.exit(1)
    
    print("🌊 UmiLog Seed Data Integration")
    print(f"📂 SEED_DATA_DIR: {SEED_DATA_DIR}")
    print(f"📂 OUTPUT_DIR: {OUTPUT_DIR}\n")
    
    # Merge
    merged = merge_seed_data(sites_only=sites_only, logs_only=logs_only, 
                            sightings_only=sightings_only, validate=validate)
    
    # Save
    output_file = 'seed_data_merged.json'
    if save_merged(merged, output_file):
        print("\n✨ Seed data integration complete!")
        sys.exit(0)
    else:
        sys.exit(1)


if __name__ == '__main__':
    main()
