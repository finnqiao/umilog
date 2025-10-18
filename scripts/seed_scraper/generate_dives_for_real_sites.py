#!/usr/bin/env python3
"""
Generate realistic dive logs for 1161+ real dive sites.
Creates 2-3 dives per site (2300-3500 total).
"""

import json
import random
from datetime import datetime, timezone, timedelta
from typing import List, Dict

SPECIES_LIST = [
    ("species_coral_grouper", "Coral Grouper"),
    ("species_whitetip_reef_shark", "Whitetip Reef Shark"),
    ("species_blacktip_reef_shark", "Blacktip Reef Shark"),
    ("species_grey_reef_shark", "Grey Reef Shark"),
    ("species_scalloped_hammerhead", "Scalloped Hammerhead"),
    ("species_whale_shark", "Whale Shark"),
    ("species_spotted_eagle_ray", "Spotted Eagle Ray"),
    ("species_manta_ray", "Manta Ray"),
    ("species_stingray", "Stingray"),
    ("species_green_turtle", "Green Turtle"),
    ("species_hawksbill_turtle", "Hawksbill Turtle"),
    ("species_bottlenose_dolphin", "Bottlenose Dolphin"),
    ("species_napoleon_wrasse", "Napoleon Wrasse"),
    ("species_moray_eel", "Moray Eel"),
    ("species_lionfish", "Lionfish"),
    ("species_great_barracuda", "Great Barracuda"),
    ("species_octopus", "Octopus"),
    ("species_cuttlefish", "Cuttlefish"),
    ("species_nudibranch", "Nudibranch"),
    ("species_seahorse", "Seahorse"),
]

OBSERVATION_NOTES = [
    "School observed", "Solitary individual", "Pair courting", "Resting on sand",
    "Hunting behavior", "Feeding", "Well camouflaged", "Curious about divers",
    "Breeding pair visible", "Multiple individuals", "Rare encounter", "Playful behavior",
    "Large specimen", "Grazing", "Patrolling hunters", "Cleaning station",
]

def load_real_sites() -> List[Dict]:
    """Load real sites."""
    try:
        with open("../../Resources/SeedData/sites_real_merged.json") as f:
            return json.load(f).get("sites", [])
    except:
        print("❌ Could not load real sites")
        return []

def generate_dives_for_sites(sites: List[Dict]) -> tuple[List[Dict], List[Dict]]:
    """Generate realistic dives for all real sites."""
    dives = []
    sightings = []
    
    base_date = datetime(2024, 1, 1, tzinfo=timezone.utc)
    dive_id = 1
    sighting_id = 1
    
    print(f"🤿 Generating dives for {len(sites)} real sites...")
    
    for site_idx, site in enumerate(sites):
        if site_idx % 200 == 0:
            print(f"  ... {site_idx} processed")
        
        # 2-3 dives per site
        num_dives = random.randint(2, 3)
        
        for _ in range(num_dives):
            # Random date in 2024
            days_offset = random.randint(0, 365)
            dive_date = base_date + timedelta(days=days_offset)
            dive_time = dive_date.replace(hour=random.randint(6, 18), minute=random.choice([0, 15, 30, 45]))
            
            # Duration
            bottom_time = random.randint(30, 90)
            end_time = dive_time + timedelta(minutes=bottom_time)
            
            # Depth (bounded by site max)
            site_max = site.get("maxDepth", 40)
            max_dive_depth = random.uniform(max(3, site_max * 0.4), site_max)
            avg_dive_depth = max_dive_depth * random.uniform(0.5, 0.85)
            
            # Pressure
            start_pressure = 200
            air_consumed = random.randint(50, 150)
            end_pressure = start_pressure - air_consumed
            
            # Temperature and visibility from site
            temp = site.get("averageTemp", 25) + random.randint(-3, 3)
            visibility = site.get("averageVisibility", 25) + random.randint(-10, 10)
            visibility = max(3, min(60, visibility))
            
            # Conditions
            current = random.choice(["None", "Light", "Moderate", "Strong"])
            conditions = random.choice(["Poor", "Fair", "Good", "Excellent"])
            
            # Instructor (30% signed)
            signed = random.random() < 0.3
            if signed:
                instructor_name = random.choice(["John Smith", "Maria Garcia", "Ahmed Hassan", "Diana Lee"])
                instructor_number = f"ID{random.randint(100000, 999999)}"
            else:
                instructor_name = None
                instructor_number = None
            
            dive = {
                "id": f"dive_real_{dive_id:06d}",
                "siteId": site["id"],
                "date": dive_date.isoformat().split('T')[0],
                "startTime": dive_time.isoformat().replace('+00:00', 'Z'),
                "endTime": end_time.isoformat().replace('+00:00', 'Z'),
                "maxDepth": round(max_dive_depth, 1),
                "averageDepth": round(avg_dive_depth, 1),
                "bottomTime": bottom_time,
                "startPressure": start_pressure,
                "endPressure": end_pressure,
                "temperature": temp,
                "visibility": round(visibility, 1),
                "current": current,
                "conditions": conditions,
                "notes": f"Dive at {site['name']}. {random.choice(['Great wildlife!', 'Beautiful corals.', 'Excellent visibility.', 'Challenging current.', 'Perfect conditions.'])}",
                "instructorName": instructor_name,
                "instructorNumber": instructor_number,
                "signed": signed,
                "createdAt": dive_date.isoformat().replace('+00:00', 'Z'),
                "updatedAt": dive_date.isoformat().replace('+00:00', 'Z'),
            }
            
            dives.append(dive)
            
            # 1-4 sightings per dive
            num_sightings = random.randint(1, 4)
            chosen_species = random.sample(SPECIES_LIST, min(num_sightings, len(SPECIES_LIST)))
            
            for species_id, species_name in chosen_species:
                count = random.randint(1, 8)
                sighting = {
                    "id": f"sight_real_{sighting_id:07d}",
                    "diveId": dive["id"],
                    "speciesId": species_id,
                    "count": count,
                    "notes": random.choice(OBSERVATION_NOTES),
                    "createdAt": dive_time.isoformat().replace('+00:00', 'Z'),
                }
                sightings.append(sighting)
                sighting_id += 1
            
            dive_id += 1
    
    return dives, sightings

def main():
    """Generate dives for real sites."""
    print("🌊 Generating dive logs for REAL dive sites only...\n")
    
    sites = load_real_sites()
    if not sites:
        print("❌ No sites loaded")
        return
    
    print(f"✅ Loaded {len(sites)} real sites\n")
    
    dives, sightings = generate_dives_for_sites(sites)
    
    print(f"\n✅ Generated {len(dives)} dives")
    print(f"✅ Generated {len(sightings)} sightings")
    
    # Save dives
    dives_output = {
        "version": "1.0",
        "source": "Generated for real sites",
        "generated_at": datetime.now(timezone.utc).isoformat(timespec='seconds').replace('+00:00', 'Z'),
        "count": len(dives),
        "dives": dives
    }
    
    with open("../../Resources/SeedData/dive_logs_real_sites.json", "w") as f:
        json.dump(dives_output, f, indent=2)
    
    print(f"📁 Saved dives to dive_logs_real_sites.json")
    
    # Save sightings
    sightings_output = {
        "version": "1.0",
        "source": "Generated for real dives",
        "generated_at": datetime.now(timezone.utc).isoformat(timespec='seconds').replace('+00:00', 'Z'),
        "count": len(sightings),
        "sightings": sightings
    }
    
    with open("../../Resources/SeedData/sightings_real_sites.json", "w") as f:
        json.dump(sightings_output, f, indent=2)
    
    print(f"📁 Saved sightings to sightings_real_sites.json")
    
    # Stats
    print(f"\n📊 Statistics:")
    print(f"  Dives per site: {len(dives) / len(sites):.1f}")
    print(f"  Sightings per dive: {len(sightings) / len(dives):.1f}")
    signed = sum(1 for d in dives if d["signed"])
    print(f"  Signed dives: {signed} ({100*signed/len(dives):.1f}%)")

if __name__ == "__main__":
    main()
