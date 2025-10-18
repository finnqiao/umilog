#!/usr/bin/env python3
"""
Select and enhance 100-150 curated sites from scraped data.
Uses Wikidata harvest with regional quotas and quality scoring.
"""

import json
import random
from typing import List, Dict
from collections import defaultdict

# Regional distribution targets
REGIONAL_QUOTAS = {
    "Red Sea": {"countries": {"Egypt", "Sudan", "Jordan", "Israel", "Saudi Arabia"}, "target": 20},
    "Caribbean": {"countries": {"Belize", "Mexico", "Bahamas", "Jamaica", "Cayman Islands", "Turks and Caicos", "British Virgin Islands", "US Virgin Islands"}, "target": 25},
    "Southeast Asia": {"countries": {"Thailand", "Indonesia", "Malaysia", "Philippines", "Vietnam", "Myanmar"}, "target": 25},
    "Pacific": {"countries": {"Australia", "Fiji", "Palau", "Papua New Guinea", "Solomon Islands", "Micronesia", "Marshall Islands", "Nauru", "Kiribati"}, "target": 20},
    "Mediterranean": {"countries": {"Malta", "Greece", "Croatia", "Italy", "Spain", "France", "Cyprus", "Turkey"}, "target": 15},
    "Indian Ocean": {"countries": {"Maldives", "Mauritius", "Seychelles", "Sri Lanka", "India"}, "target": 10},
    "Other": {"countries": set(), "target": 10}
}

def load_scraped():
    """Load Wikidata sites."""
    try:
        with open("scraped/wikidata_sites.json") as f:
            data = json.load(f)
            return data.get("sites", [])
    except FileNotFoundError:
        return []

def assign_region(country: str) -> str:
    """Assign site to region based on country."""
    for region, config in REGIONAL_QUOTAS.items():
        if region != "Other" and country in config["countries"]:
            return region
    return "Other"

def score_site(site: Dict) -> float:
    """Score site for inclusion (favor complete metadata, realistic depth)."""
    score = 1.0
    
    # Bonus for having description
    if site.get("description"):
        score += 0.5
    
    # Bonus for realistic depth (5-100m)
    depth = site.get("maxDepth", 40)
    if 5 <= depth <= 100:
        score += 1.0
    elif 100 < depth <= 130:
        score += 0.5
    
    # Bonus for valid country
    if site.get("country") and site.get("country") != "Unknown":
        score += 0.5
    
    return score

def select_curated(sites: List[Dict], target: int = 150) -> List[Dict]:
    """Select best sites with regional distribution."""
    
    # Group by region
    regional_sites = defaultdict(list)
    for site in sites:
        region = assign_region(site.get("country", "Unknown"))
        score = score_site(site)
        regional_sites[region].append((score, site))
    
    # Sort each region by score (descending)
    for region in regional_sites:
        regional_sites[region].sort(key=lambda x: x[0], reverse=True)
    
    # Select sites respecting quotas
    selected = []
    total_quota = sum(config["target"] for config in REGIONAL_QUOTAS.values())
    
    for region, config in REGIONAL_QUOTAS.items():
        quota = config["target"]
        sites_list = [site for score, site in regional_sites[region]]
        selected_count = min(quota, len(sites_list))
        selected.extend(sites_list[:selected_count])
        
        print(f"  {region}: {selected_count}/{quota} sites")
    
    print(f"✅ Selected {len(selected)} sites total (target: {target})")
    return selected

def enhance_site(site: Dict, index: int) -> Dict:
    """Enhance site with tags, difficulty, and other metadata."""
    
    country = site.get("country", "Unknown")
    depth = site.get("maxDepth", 40)
    region = assign_region(country)
    
    # Assign difficulty based on depth
    if depth <= 18:
        difficulty = "beginner"
    elif depth <= 40:
        difficulty = "intermediate"
    else:
        difficulty = "advanced"
    
    # Assign entry modes (default boat for deep sites)
    entry_modes = ["shore"] if depth <= 10 else ["boat"]
    if depth <= 20:
        entry_modes.append("shore")
    
    # Auto-generated tags
    tags = []
    if "reef" in site.get("description", "").lower():
        tags.append("reef")
    if "wreck" in site.get("description", "").lower():
        tags.append("wreck")
    if "wall" in site.get("description", "").lower():
        tags.append("wall")
    if "cave" in site.get("description", "").lower():
        tags.append("cave")
    if depth > 40:
        tags.append("deep")
    if depth < 10:
        tags.append("shallow")
    
    # Default tags if none detected
    if not tags:
        tags = ["reef"] if depth <= 25 else ["deep"]
    
    # Normalize area/country
    area = site.get("country", "Unknown").split(", ")[0] if site.get("country") else "Unknown"
    
    return {
        "id": f"wiki_site_{index:03d}",
        "name": site.get("name", f"Dive Site {index}"),
        "region": region,
        "area": area,
        "country": site.get("country", "Unknown"),
        "latitude": site.get("latitude"),
        "longitude": site.get("longitude"),
        "type": "reef",  # Default, can be manual
        "description": site.get("description", ""),
        "minDepth": max(3, depth - 15),
        "maxDepth": depth,
        "difficulty": difficulty,
        "tags": tags,
        "facets": {
            "entry_modes": entry_modes,
            "notable_features": tags,
            "visibility_mean": 25,
            "temp_mean": 26,
            "seasonality_json": {"peakMonths": []},
            "has_current": False,
            "shop_count": 1
        },
        "media": [],
        "provenance": {
            "sources": [
                {
                    "name": "Wikidata",
                    "url": site.get("source_url", ""),
                    "license": "CC0"
                }
            ]
        }
    }

def main():
    """Main entry point."""
    print("📍 Loading Wikidata harvest...")
    sites = load_scraped()
    print(f"  Loaded {len(sites)} sites from Wikidata")
    
    print("\n🔍 Selecting best 150 sites with regional distribution...")
    selected = select_curated(sites, target=150)
    
    print("\n✨ Enhancing with metadata...")
    enhanced = [enhance_site(site, i) for i, site in enumerate(selected)]
    
    output = {
        "version": "1.0",
        "source": "Wikidata + Manual Curation",
        "license": "CC0",
        "count": len(enhanced),
        "sites": enhanced
    }
    
    output_file = "../../Resources/SeedData/curated_sites.json"
    
    import os
    os.makedirs(os.path.dirname(output_file), exist_ok=True)
    
    with open(output_file, "w") as f:
        json.dump(output, f, indent=2)
    
    print(f"✅ Curated sites saved to {output_file}")
    print(f"📊 Final: {len(enhanced)} sites ready for app integration")

if __name__ == "__main__":
    main()
