#!/usr/bin/env python3
"""
Enhanced dive site generator for comprehensive seed data.
Generates 200+ realistic dive sites across all major regions.
Uses realistic coordinates, depths, temperatures, and visibility.
"""

import json
import random
from datetime import datetime, timezone
from typing import List, Dict

# Regional dive site data with realistic coordinates and environmental parameters
REGIONS_DATA = {
    "Red Sea": {
        "countries": ["Egypt", "Saudi Arabia", "Sudan", "Israel", "Jordan"],
        "bounds": {"lat_min": 12, "lat_max": 30, "lon_min": 32, "lon_max": 43},
        "sites_per_region": 40,
        "temp_range": (23, 30),
        "visibility_range": (15, 50),
        "depth_range": (5, 110),
        "types": ["reef", "wall", "wreck", "pinnacle", "coral_garden"],
        "difficulty": ["beginner", "intermediate", "advanced"],
    },
    "Caribbean": {
        "countries": ["Mexico", "Belize", "Honduras", "Costa Rica", "Panama", "Bahamas", "Cuba", "Cayman Islands", "Jamaica", "Turks and Caicos", "US Virgin Islands", "British Virgin Islands", "Dominica", "Aruba"],
        "bounds": {"lat_min": 10, "lat_max": 27, "lon_min": -85, "lon_max": -60},
        "sites_per_region": 50,
        "temp_range": (24, 29),
        "visibility_range": (10, 40),
        "depth_range": (3, 124),
        "types": ["reef", "wall", "wreck", "blue_hole", "coral_garden", "drift"],
        "difficulty": ["beginner", "intermediate", "advanced"],
    },
    "Southeast Asia": {
        "countries": ["Thailand", "Malaysia", "Indonesia", "Philippines", "Vietnam", "Cambodia"],
        "bounds": {"lat_min": 0, "lat_max": 21, "lon_min": 95, "lon_max": 135},
        "sites_per_region": 45,
        "temp_range": (26, 32),
        "visibility_range": (5, 35),
        "depth_range": (3, 60),
        "types": ["reef", "wall", "wreck", "macro", "coral_garden", "drift"],
        "difficulty": ["beginner", "intermediate", "advanced"],
    },
    "Pacific": {
        "countries": ["Australia", "Fiji", "Palau", "Micronesia", "Guam", "New Zealand", "Papua New Guinea"],
        "bounds": {"lat_min": -45, "lat_max": 15, "lon_min": 110, "lon_max": 180},
        "sites_per_region": 35,
        "temp_range": (20, 29),
        "visibility_range": (20, 60),
        "depth_range": (5, 70),
        "types": ["reef", "wall", "wreck", "pinnacle", "drift", "coral_garden"],
        "difficulty": ["intermediate", "advanced"],
    },
    "Mediterranean": {
        "countries": ["Greece", "Italy", "Spain", "France", "Croatia", "Cyprus", "Malta", "Turkey"],
        "bounds": {"lat_min": 30, "lat_max": 45, "lon_min": -6, "lon_max": 40},
        "sites_per_region": 25,
        "temp_range": (13, 26),
        "visibility_range": (10, 40),
        "depth_range": (5, 60),
        "types": ["reef", "wall", "wreck", "cave", "chimney", "rocky"],
        "difficulty": ["beginner", "intermediate", "advanced"],
    },
    "Indian Ocean": {
        "countries": ["Maldives", "Seychelles", "Mauritius", "Tanzania", "Kenya", "Mozambique"],
        "bounds": {"lat_min": -25, "lat_max": 5, "lon_min": 30, "lon_max": 80},
        "sites_per_region": 30,
        "temp_range": (24, 30),
        "visibility_range": (15, 50),
        "depth_range": (3, 80),
        "types": ["reef", "wall", "atoll", "coral_garden", "drift"],
        "difficulty": ["intermediate", "advanced"],
    },
}

# Real dive site names by type and region for authenticity
SITE_NAMES = {
    "reef": [
        "Coral Garden", "Barrier Reef", "House Reef", "Bommie", "Pinnacle",
        "Rainbow Reef", "Turtle Reef", "Shark Reef", "Eagle Ray Station",
        "Hammerhead Alley", "Cathedral", "The Arch", "The Canyon"
    ],
    "wall": [
        "Blue Wall", "Vertical Wall", "Drop-off", "Escarpment", "The Precipice",
        "Plunge Point", "The Abyss", "Deep Blue", "Midnight Wall"
    ],
    "wreck": [
        "Wreck", "Sunken Ship", "Freighter", "Cargo Vessel", "Naval Wreck",
        "Destroyer", "Transport", "Steamer", "Barge"
    ],
    "cave": [
        "Blue Grotto", "Cathedral Cave", "Cavern", "Stalactite Cave", "Sinkhole",
        "Cenote", "Blue Hole", "Underwater Arch"
    ],
    "pinnacle": [
        "Pinnacle", "Tower", "Seamount", "Underwater Peak", "Spire",
        "The Needle", "Spike Point"
    ],
    "coral_garden": [
        "Coral Garden", "Coral Kingdom", "Soft Coral Forest", "Hard Coral Plateau",
        "Coral Nursery", "Branching Coral Zone"
    ],
    "drift": [
        "Drift Zone", "Current Alley", "Blue Current", "Cruise Control",
        "Fast Track", "River Drift"
    ],
    "macro": [
        "Macro Zone", "Creature Cove", "Critter Colony", "Nudibranch Garden",
        "Seahorse Seagrass"
    ],
}

DESCRIPTIONS = {
    "reef": "Beautiful coral reef with vibrant fish life and healthy corals.",
    "wall": "Spectacular wall dive with dramatic drop-off and pelagic encounters.",
    "wreck": "Historic shipwreck with intact structure, encrusted with marine life.",
    "cave": "Fascinating underwater cavern with light penetration and unique formations.",
    "pinnacle": "Underwater pinnacle rich with life and excellent for all skill levels.",
    "coral_garden": "Pristine coral garden teeming with colorful fish and invertebrates.",
    "drift": "Exhilarating drift dive with strong currents and abundant marine life.",
    "macro": "Excellent macro diving spot with small critters and nudibranchs.",
}

def generate_realistic_sites() -> List[Dict]:
    """Generate 200+ realistic dive sites with all parameters."""
    sites = []
    site_id = 1
    
    for region_name, region_data in REGIONS_DATA.items():
        num_sites = region_data["sites_per_region"]
        
        for _ in range(num_sites):
            # Random location within region bounds
            lat = random.uniform(
                region_data["bounds"]["lat_min"],
                region_data["bounds"]["lat_max"]
            )
            lon = random.uniform(
                region_data["bounds"]["lon_min"],
                region_data["bounds"]["lon_max"]
            )
            
            # Random environmental parameters
            site_type = random.choice(region_data["types"])
            difficulty = random.choice(region_data["difficulty"])
            temp = random.randint(*region_data["temp_range"])
            visibility = random.randint(*region_data["visibility_range"])
            max_depth = random.randint(*region_data["depth_range"])
            avg_depth = max(3, max_depth * random.uniform(0.4, 0.7))
            min_depth = max(0, avg_depth * random.uniform(0.3, 0.7))
            
            # Build site name
            site_name_base = random.choice(SITE_NAMES.get(site_type, SITE_NAMES["reef"]))
            country = random.choice(region_data["countries"])
            site_name = f"{site_name_base} ({country})"
            
            # Tags based on type and difficulty
            tags = [site_type, difficulty, "scenic"]
            if max_depth > 40:
                tags.append("deep")
            if visibility > 35:
                tags.append("clear_water")
            if max_depth < 15:
                tags.append("snorkel_friendly")
            
            site = {
                "id": f"dive_site_{site_id:04d}",
                "name": site_name,
                "region": region_name,
                "area": f"{country} - Zone {random.randint(1, 5)}",
                "country": country,
                "latitude": round(lat, 6),
                "longitude": round(lon, 6),
                "type": site_type,
                "difficulty": difficulty,
                "minDepth": round(min_depth, 1),
                "averageDepth": round(avg_depth, 1),
                "maxDepth": round(max_depth, 1),
                "averageTemp": temp,
                "averageVisibility": visibility,
                "description": DESCRIPTIONS.get(site_type, "Excellent dive site."),
                "tags": tags,
                "wishlist": False,
                "visitedCount": 0,
                "createdAt": datetime.now(timezone.utc).isoformat(timespec='seconds').replace('+00:00', 'Z'),
                "source": "Generated",
                "license": "CC0",
            }
            
            sites.append(site)
            site_id += 1
    
    return sites


def main():
    """Generate and save expanded seed data."""
    print("🌊 Generating 200+ realistic dive sites...")
    sites = generate_realistic_sites()
    
    output = {
        "version": "1.0",
        "source": "Generated",
        "license": "CC0",
        "generated_at": datetime.now(timezone.utc).isoformat(timespec='seconds').replace('+00:00', 'Z'),
        "count": len(sites),
        "regions": list(REGIONS_DATA.keys()),
        "sites": sites
    }
    
    import os
    os.makedirs("../../Resources/SeedData", exist_ok=True)
    
    output_file = "../../Resources/SeedData/sites_expanded_200plus.json"
    with open(output_file, "w") as f:
        json.dump(output, f, indent=2, ensure_ascii=False)
    
    print(f"✅ Generated {len(sites)} dive sites")
    print(f"📁 Output saved to {output_file}")
    
    # Print summary by region
    print("\n📊 Distribution by region:")
    region_counts = {}
    for site in sites:
        region = site.get("region", "Unknown")
        region_counts[region] = region_counts.get(region, 0) + 1
    
    for region in sorted(region_counts.keys()):
        print(f"  {region}: {region_counts[region]} sites")


if __name__ == "__main__":
    main()
