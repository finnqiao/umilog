#!/usr/bin/env python3
"""
Dataset cleanup and optimization for UmiLog seed data.

Processes final_comprehensive_dataset.json to:
1. Filter out non-dive locations
2. Validate geographic data
3. Remove duplicates
4. Create optimized regional tiles
5. Generate manifest and metadata
"""

import json
import math
import hashlib
import gzip
from pathlib import Path
from collections import defaultdict
from typing import Dict, List, Tuple, Optional
from datetime import datetime

# Dive site indicators - keywords that suggest valid dive locations
VALID_DIVE_KEYWORDS = {
    'reef', 'wreck', 'dive', 'site', 'diving', 'scuba',
    'coral', 'atoll', 'island', 'beach', 'bay', 'shoal',
    'gota', 'habili', 'shaab', 'marsa', 'erg', 'habeli',
    'bommie', 'pinnacle', 'wall', 'trench', 'deep',
    'seamount', 'rock', 'point', 'cape', 'headland',
    'garden', 'cave', 'arch', 'canyon', 'ridge'
}

# Exclude keywords - things that are NOT dive sites
EXCLUDE_KEYWORDS = {
    'stadium', 'park', 'sports', 'arena', 'field',
    'baseball', 'football', 'soccer', 'cricket',
    'racetrack', 'training', 'complex', 'school',
    'building', 'office', 'shopping', 'center',
    'airport', 'station', 'factory', 'plant',
    'museum', 'temple', 'church', 'mall'
}


def is_valid_dive_site(site: Dict) -> Tuple[bool, str]:
    """Determine if a site entry represents a real dive location."""
    name = (site.get('name') or '').lower()
    desc = (site.get('description') or '').lower()
    site_type = (site.get('type') or '').lower()
    country = (site.get('country') or '').lower()
    
    # Check for exclude keywords
    combined = f"{name} {desc} {site_type}".lower()
    for exclude in EXCLUDE_KEYWORDS:
        if exclude in combined:
            return False, f"excluded keyword: {exclude}"
    
    # Must have coordinates
    lat = site.get('latitude')
    lon = site.get('longitude')
    if not lat or not lon:
        return False, "missing coordinates"
    
    # Check reasonable lat/lon bounds
    if not (-90 <= lat <= 90 and -180 <= lon <= 180):
        return False, "invalid coordinates"
    
    # Exclude purely inland locations (e.g., lakes, mountains)
    # Allow some flexibility for coastal areas and island nations
    if desc:
        if any(x in desc for x in ['landlocked', 'mountain', 'alpine', 'valley', 'plateau']):
            if 'diving' not in desc and 'scuba' not in desc:
                return False, "landlocked location"
    
    # Check for dive-related indicators
    has_dive_indicator = any(kw in name or kw in desc or kw in site_type 
                              for kw in VALID_DIVE_KEYWORDS)
    
    # If not explicitly dive-related, check location heuristics
    if not has_dive_indicator:
        # Accept if it's clearly a geographic feature near water
        water_features = {'reef', 'atoll', 'island', 'bay', 'coastal', 'marine', 'sea'}
        if any(x in desc for x in water_features):
            has_dive_indicator = True
    
    if has_dive_indicator:
        return True, "valid"
    
    # Conservative: require explicit dive indicator
    return False, "no dive indicator"


def calculate_distance(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Calculate distance between two points using Haversine formula (km)."""
    R = 6371
    
    dlat = math.radians(lat2 - lat1)
    dlon = math.radians(lon2 - lon1)
    a = math.sin(dlat/2)**2 + math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) * math.sin(dlon/2)**2
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1-a))
    
    return R * c


def remove_duplicates(sites: List[Dict]) -> List[Dict]:
    """Remove duplicate sites using name + location clustering."""
    if not sites:
        return []
    
    # Sort by ID to maintain consistency
    sites = sorted(sites, key=lambda s: s.get('id', ''))
    
    kept = []
    skipped = []
    
    for site in sites:
        is_duplicate = False
        site_name = (site.get('name') or '').strip()
        site_lat = site.get('latitude')
        site_lon = site.get('longitude')
        
        if not site_name or site_lat is None or site_lon is None:
            continue
        
        # Check against already kept sites
        for kept_site in kept:
            kept_name = (kept_site.get('name') or '').strip()
            kept_lat = kept_site.get('latitude')
            kept_lon = kept_site.get('longitude')
            
            # Exact name match AND very close location (< 1km)
            if kept_name.lower() == site_name.lower():
                dist = calculate_distance(site_lat, site_lon, kept_lat, kept_lon)
                if dist < 1.0:
                    is_duplicate = True
                    skipped.append({
                        'name': site_name,
                        'reason': f'duplicate of {kept_name}',
                        'distance_km': round(dist, 2)
                    })
                    break
        
        if not is_duplicate:
            kept.append(site)
    
    print(f"Deduplication: {len(sites)} → {len(kept)} sites (removed {len(skipped)})")
    return kept


def assign_region(lat: float, lon: float) -> str:
    """Assign geographic region based on coordinates."""
    # Simple but effective regional classification
    if -35 <= lat <= 40 and -20 <= lon <= 50:
        return "Mediterranean"
    elif -35 <= lat <= 35 and 20 <= lon <= 150:
        return "Red Sea & Indian Ocean"
    elif -12 <= lat <= 35 and -85 <= lon <= -30:
        return "Caribbean & Atlantic"
    elif 0 <= lat <= 50 and 100 <= lon <= 180:
        return "Southeast Asia & Pacific"
    elif -50 <= lat <= -10 and 110 <= lon <= 180:
        return "Australia & Pacific Islands"
    elif 40 <= lat <= 70 and -180 <= lon <= 180:
        return "North Atlantic & Arctic"
    else:
        return "Other Regions"


def clean_site(site: Dict) -> Dict:
    """Clean and standardize a single site entry."""
    cleaned = {}
    
    # Core fields
    for field in ['id', 'name', 'latitude', 'longitude', 'country', 'description', 'maxDepth']:
        if field in site:
            cleaned[field] = site[field]
    
    # Standardize depth
    if 'maxDepth' not in cleaned:
        cleaned['maxDepth'] = 40  # Default for unknown
    
    # Add computed fields
    if 'latitude' in cleaned and 'longitude' in cleaned:
        cleaned['region'] = assign_region(cleaned['latitude'], cleaned['longitude'])
    
    # Metadata
    cleaned['source'] = site.get('source', 'unknown')
    cleaned['license'] = site.get('license', 'CC0')
    cleaned['verified'] = site.get('verified', True)
    cleaned['createdAt'] = site.get('createdAt', datetime.utcnow().isoformat() + 'Z')
    
    return cleaned


def filter_dataset(input_file: Path) -> Tuple[List[Dict], List[Dict], List[Dict]]:
    """Load and filter the comprehensive dataset."""
    print(f"\n=== Loading dataset from {input_file.name} ===")
    
    with open(input_file) as f:
        data = json.load(f)
    
    total_sites = len(data.get('sites', []))
    print(f"Total sites in file: {total_sites}")
    
    # Filter sites
    print("\n=== Filtering sites ===")
    valid_sites = []
    rejected_sites = defaultdict(int)
    
    for site in data.get('sites', []):
        is_valid, reason = is_valid_dive_site(site)
        if is_valid:
            valid_sites.append(site)
        else:
            rejected_sites[reason] += 1
    
    print(f"Valid sites: {len(valid_sites)}")
    for reason, count in sorted(rejected_sites.items(), key=lambda x: -x[1]):
        print(f"  Rejected ({reason}): {count}")
    
    # Deduplicate
    print("\n=== Deduplicating ===")
    unique_sites = remove_duplicates(valid_sites)
    
    # Clean and standardize
    print("\n=== Cleaning site data ===")
    cleaned_sites = [clean_site(s) for s in unique_sites]
    print(f"Cleaned {len(cleaned_sites)} sites")
    
    # Filter and validate logs
    print("\n=== Processing dive logs ===")
    valid_site_ids = {s['id'] for s in cleaned_sites}
    logs = []
    
    for log in data.get('dives', []):
        if log.get('siteId') in valid_site_ids:
            logs.append(log)
    
    print(f"Valid logs (referencing cleaned sites): {len(logs)}")
    
    # Filter and validate sightings
    print("\n=== Processing wildlife sightings ===")
    valid_log_ids = {l['id'] for l in logs} if logs else set()
    sightings = []
    
    for sighting in data.get('sightings', []):
        if sighting.get('diveId') in valid_log_ids:
            sightings.append(sighting)
    
    print(f"Valid sightings (referencing cleaned logs): {len(sightings)}")
    
    return cleaned_sites, logs, sightings


def create_regional_tiles(sites: List[Dict], output_dir: Path) -> Dict:
    """Create regionally-bucketed tile files."""
    print(f"\n=== Creating regional tiles ===")
    
    output_dir.mkdir(parents=True, exist_ok=True)
    
    # Group sites by region
    by_region = defaultdict(list)
    for site in sites:
        region = site.get('region', 'Other Regions')
        by_region[region].append(site)
    
    manifest = {
        'version': '1.0',
        'generated_at': datetime.utcnow().isoformat() + 'Z',
        'tiles': [],
        'summary': {
            'total_sites': len(sites),
            'total_regions': len(by_region),
            'total_size_uncompressed_mb': 0,
            'total_size_compressed_mb': 0
        }
    }
    
    for region, region_sites in sorted(by_region.items()):
        tile_name = region.lower().replace(' & ', '-').replace(' ', '-') + '.json'
        tile_path = output_dir / tile_name
        
        tile_data = {
            'region': region,
            'sites': region_sites,
            'metadata': {
                'count': len(region_sites),
                'bounds': calculate_bounds(region_sites)
            }
        }
        
        # Write uncompressed
        with open(tile_path, 'w') as f:
            json.dump(tile_data, f, indent=2)
        
        uncompressed_size = tile_path.stat().st_size
        
        # Write compressed
        gz_path = tile_path.with_suffix('.json.gz')
        with open(tile_path, 'rb') as f_in:
            with gzip.open(gz_path, 'wb') as f_out:
                f_out.writelines(f_in)
        
        compressed_size = gz_path.stat().st_size
        
        manifest['tiles'].append({
            'name': tile_name,
            'region': region,
            'count': len(region_sites),
            'size_uncompressed_kb': round(uncompressed_size / 1024, 1),
            'size_compressed_kb': round(compressed_size / 1024, 1),
            'bounds': tile_data['metadata']['bounds']
        })
        
        manifest['summary']['total_size_uncompressed_mb'] += uncompressed_size
        manifest['summary']['total_size_compressed_mb'] += compressed_size
        
        print(f"  {region}: {len(region_sites)} sites " +
              f"({round(uncompressed_size/1024, 1)}KB → {round(compressed_size/1024, 1)}KB)")
    
    manifest['summary']['total_size_uncompressed_mb'] = round(
        manifest['summary']['total_size_uncompressed_mb'] / (1024 * 1024), 1
    )
    manifest['summary']['total_size_compressed_mb'] = round(
        manifest['summary']['total_size_compressed_mb'] / (1024 * 1024), 1
    )
    
    # Write manifest
    manifest_path = output_dir / 'manifest.json'
    with open(manifest_path, 'w') as f:
        json.dump(manifest, f, indent=2)
    
    print(f"\nManifest written to {manifest_path.name}")
    return manifest


def calculate_bounds(sites: List[Dict]) -> Dict:
    """Calculate geographic bounds for a set of sites."""
    if not sites:
        return None
    
    lats = [s['latitude'] for s in sites if s.get('latitude')]
    lons = [s['longitude'] for s in sites if s.get('longitude')]
    
    if not lats or not lons:
        return None
    
    return {
        'min_lat': min(lats),
        'max_lat': max(lats),
        'min_lon': min(lons),
        'max_lon': max(lons),
        'center_lat': sum(lats) / len(lats),
        'center_lon': sum(lons) / len(lons)
    }


def save_cleaned_dataset(sites: List[Dict], logs: List[Dict], sightings: List[Dict], output_dir: Path):
    """Save cleaned datasets as single files for reference."""
    print(f"\n=== Saving cleaned datasets ===")
    
    output_dir.mkdir(parents=True, exist_ok=True)
    
    # Sites
    sites_file = output_dir / 'cleaned_sites.json'
    with open(sites_file, 'w') as f:
        json.dump({
            'version': '1.0',
            'generated_at': datetime.utcnow().isoformat() + 'Z',
            'description': 'Cleaned and validated dive sites',
            'sites': sites,
            'summary': {
                'total': len(sites),
                'by_region': defaultdict(int, {
                    region: len([s for s in sites if s.get('region') == region])
                    for region in set(s.get('region') for s in sites)
                })
            }
        }, f, indent=2)
    print(f"  Wrote {sites_file.name}: {len(sites)} sites")
    
    # Logs
    logs_file = output_dir / 'cleaned_logs.json'
    with open(logs_file, 'w') as f:
        json.dump({
            'version': '1.0',
            'generated_at': datetime.utcnow().isoformat() + 'Z',
            'description': 'Validated dive logs',
            'logs': logs,
            'summary': {'total': len(logs)}
        }, f, indent=2)
    print(f"  Wrote {logs_file.name}: {len(logs)} logs")
    
    # Sightings
    sightings_file = output_dir / 'cleaned_sightings.json'
    with open(sightings_file, 'w') as f:
        json.dump({
            'version': '1.0',
            'generated_at': datetime.utcnow().isoformat() + 'Z',
            'description': 'Validated wildlife sightings',
            'sightings': sightings,
            'summary': {'total': len(sightings)}
        }, f, indent=2)
    print(f"  Wrote {sightings_file.name}: {len(sightings)} sightings")


def main():
    """Main entry point."""
    base_dir = Path(__file__).parent.parent
    data_dir = base_dir / 'Resources' / 'SeedData'
    input_file = data_dir / 'final_comprehensive_dataset.json'
    output_dir = data_dir / 'optimized'
    tiles_dir = output_dir / 'tiles'
    
    if not input_file.exists():
        print(f"Error: {input_file} not found")
        return 1
    
    # Filter and clean
    sites, logs, sightings = filter_dataset(input_file)
    
    # Save cleaned versions
    save_cleaned_dataset(sites, logs, sightings, output_dir)
    
    # Create regional tiles
    manifest = create_regional_tiles(sites, tiles_dir)
    
    print(f"\n=== Summary ===")
    print(f"Processed: {len(sites)} sites, {len(logs)} logs, {len(sightings)} sightings")
    print(f"Output directory: {output_dir}")
    print(f"Regional tiles: {len(manifest['tiles'])}")
    print(f"Total uncompressed: {manifest['summary']['total_size_uncompressed_mb']}MB")
    print(f"Total compressed: {manifest['summary']['total_size_compressed_mb']}MB")
    print(f"Compression ratio: {round(100 * (1 - manifest['summary']['total_size_compressed_mb'] / manifest['summary']['total_size_uncompressed_mb']), 1)}%")
    
    return 0


if __name__ == '__main__':
    exit(main())
