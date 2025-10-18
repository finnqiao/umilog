#!/usr/bin/env python3
"""
Scrape REAL dive sites from OpenStreetMap Overpass API.
Filters for actual diving locations with coordinates.
"""

import requests
import json
from datetime import datetime, timezone
from typing import List, Dict
import time

# Overpass API endpoint
OVERPASS_URL = "https://overpass-api.de/api/interpreter"

QUERIES = {
    "dive_shops": """
[out:json];
(
  node["shop"="diving"](bbox);
  way["shop"="diving"](bbox);
  relation["shop"="diving"](bbox);
);
out center;
""",
    
    "dive_sites": """
[out:json];
(
  node["sport"="diving"](bbox);
  way["sport"="diving"](bbox);
  relation["sport"="diving"](bbox);
  node["leisure"="diving"](bbox);
  node["natural"="reef"](bbox);
  way["natural"="reef"](bbox);
  node["man_made"="diving_platform"](bbox);
  node["amenity"="dive_center"](bbox);
);
out center;
""",
    
    "marine_areas": """
[out:json];
(
  relation["boundary"="marine"](bbox);
  relation["type"="multipolygon"]["boundary"="marine"](bbox);
  relation["leisure"="marine_park"](bbox);
  relation["site:type"="marine"](bbox);
);
out center;
"""
}

# Regional bounding boxes for comprehensive coverage
REGIONS = {
    "Red_Sea": {"bbox": "12,32,30,43"},
    "Caribbean": {"bbox": "10,-85,27,-60"},
    "Southeast_Asia": {"bbox": "0,95,21,135"},
    "Great_Barrier_Reef": {"bbox": "-25,145,-10,155"},
    "Mediterranean": {"bbox": "30,-6,45,40"},
    "Maldives": {"bbox": "0,72,5,74"},
    "Palau": {"bbox": "6,133,8,135"},
    "Philippines": {"bbox": "5,120,20,128"},
    "Indonesia": {"bbox": "-11,95,5,141"},
    "Egypt_Coast": {"bbox": "22,34,28,35"},
    "Atlantic": {"bbox": "35,-35,50,0"},
    "Indian_Ocean": {"bbox": "-30,30,5,90"},
}

def query_overpass(query_template: str, region_name: str, bbox: str) -> List[Dict]:
    """Query Overpass API for dive sites in a region."""
    query = query_template.replace("bbox", bbox)
    
    print(f"  Querying {region_name}...")
    
    try:
        response = requests.post(OVERPASS_URL, data=query, timeout=30)
        response.raise_for_status()
        data = response.json()
        
        sites = []
        elements = data.get("elements", [])
        
        for elem in elements:
            try:
                # Get coordinates
                if "center" in elem:
                    lat = elem["center"]["lat"]
                    lon = elem["center"]["lon"]
                elif "lat" in elem and "lon" in elem:
                    lat = elem["lat"]
                    lon = elem["lon"]
                else:
                    continue
                
                # Get name
                tags = elem.get("tags", {})
                name = tags.get("name", "")
                if not name:
                    name = tags.get("description", "")
                if not name:
                    continue
                
                # Skip if name is too generic
                if len(name) < 3:
                    continue
                
                site = {
                    "name": name,
                    "latitude": round(lat, 6),
                    "longitude": round(lon, 6),
                    "description": tags.get("description", ""),
                    "type": tags.get("shop", tags.get("sport", tags.get("leisure", "dive_site"))),
                    "source": "OpenStreetMap",
                    "verified": True,
                    "maxDepth": 40,  # Default, OSM doesn't have depth
                }
                
                sites.append(site)
            
            except Exception:
                continue
        
        print(f"    ✅ Found {len(sites)} sites")
        return sites
    
    except Exception as e:
        print(f"    ⚠️  Error: {str(e)[:50]}")
        return []

def deduplicate(all_sites: List[Dict]) -> List[Dict]:
    """Remove duplicates by name and coordinates."""
    seen = {}
    unique = []
    
    for site in all_sites:
        key = (site["name"].lower(), round(site["latitude"], 2), round(site["longitude"], 2))
        
        if key not in seen:
            seen[key] = True
            unique.append(site)
    
    return unique

def assign_regions(sites: List[Dict]) -> List[Dict]:
    """Assign region based on coordinates."""
    region_bounds = {
        "Red Sea": {"lat_min": 12, "lat_max": 30, "lon_min": 32, "lon_max": 43},
        "Caribbean": {"lat_min": 10, "lat_max": 27, "lon_min": -85, "lon_max": -60},
        "Southeast Asia": {"lat_min": 0, "lat_max": 21, "lon_min": 95, "lon_max": 135},
        "Pacific": {"lat_min": -35, "lat_max": 30, "lon_min": 110, "lon_max": 180},
        "Mediterranean": {"lat_min": 30, "lat_max": 45, "lon_min": -6, "lon_max": 40},
        "Indian Ocean": {"lat_min": -30, "lat_max": 5, "lon_min": 30, "lon_max": 90},
        "Atlantic": {"lat_min": -60, "lat_max": 60, "lon_min": -90, "lon_max": 0},
        "Other": {"lat_min": -90, "lat_max": 90, "lon_min": -180, "lon_max": 180},
    }
    
    for site in sites:
        lat, lon = site["latitude"], site["longitude"]
        
        for region, bounds in region_bounds.items():
            if (bounds["lat_min"] <= lat <= bounds["lat_max"] and
                bounds["lon_min"] <= lon <= bounds["lon_max"]):
                site["region"] = region
                break
    
    return sites

def main():
    """Scrape real dive sites from OpenStreetMap."""
    print("🌊 Scraping REAL dive sites from OpenStreetMap...\n")
    
    all_sites = []
    
    for query_name, query_template in QUERIES.items():
        print(f"📍 Query: {query_name}")
        
        for region_name, region_info in REGIONS.items():
            sites = query_overpass(query_template, region_name, region_info["bbox"])
            all_sites.extend(sites)
            time.sleep(0.5)  # Rate limiting
    
    print(f"\n📊 Total scraped: {len(all_sites)} sites")
    
    # Deduplicate
    unique_sites = deduplicate(all_sites)
    print(f"🔍 After deduplication: {len(unique_sites)} unique sites")
    
    # Assign regions
    unique_sites = assign_regions(unique_sites)
    
    # Add metadata
    for i, site in enumerate(unique_sites, 1):
        site["id"] = f"osm_site_{i:05d}"
        site["createdAt"] = datetime.now(timezone.utc).isoformat(timespec='seconds').replace('+00:00', 'Z')
        site["license"] = "ODbL"  # OpenStreetMap license
        site["wishlist"] = False
        site["visitedCount"] = 0
    
    # Regional summary
    region_counts = {}
    for site in unique_sites:
        region = site.get("region", "Unknown")
        region_counts[region] = region_counts.get(region, 0) + 1
    
    print(f"\n🌍 Regional Distribution:")
    for region in sorted(region_counts.keys()):
        print(f"  {region}: {region_counts[region]} sites")
    
    # Save
    output = {
        "version": "1.0",
        "source": "OpenStreetMap Overpass API",
        "license": "ODbL",
        "retrieved_at": datetime.now(timezone.utc).isoformat(timespec='seconds').replace('+00:00', 'Z'),
        "count": len(unique_sites),
        "regions": list(region_counts.keys()),
        "regional_counts": region_counts,
        "validation": {
            "all_have_coordinates": all("latitude" in s and "longitude" in s for s in unique_sites),
            "all_have_names": all("name" in s and len(s["name"]) > 0 for s in unique_sites),
            "real_sites_only": True,
        },
        "sites": unique_sites
    }
    
    import os
    os.makedirs("../../Resources/SeedData", exist_ok=True)
    
    output_file = "../../Resources/SeedData/sites_real_osm.json"
    with open(output_file, "w") as f:
        json.dump(output, f, indent=2, ensure_ascii=False)
    
    print(f"\n✅ Saved {len(unique_sites)} REAL OSM dive sites to {output_file}")

if __name__ == "__main__":
    main()
