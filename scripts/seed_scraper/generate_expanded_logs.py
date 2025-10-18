#!/usr/bin/env python3
"""
Generate extended dive logs and sightings for expanded site dataset.
Creates 3-5 realistic dive logs per site with associated sightings.
Total: ~800-900 dive logs and 1500+ sightings.
"""

import json
import random
from datetime import datetime, timezone, timedelta
from typing import List, Dict

# Species for realistic sightings
SPECIES_LIST = [
    ("species_coral_grouper", "Cephalopholis miniata"),
    ("species_whitetip_reef_shark", "Triaenodon obesus"),
    ("species_blacktip_reef_shark", "Carcharhinus melanopterus"),
    ("species_grey_reef_shark", "Carcharhinus amblyrhynchos"),
    ("species_scalloped_hammerhead", "Sphyrna lewini"),
    ("species_great_hammerhead", "Sphyrna mokarran"),
    ("species_whale_shark", "Rhincodon typus"),
    ("species_spotted_eagle_ray", "Aetobatus narinari"),
    ("species_manta_ray", "Manta birostris"),
    ("species_stingray", "Hypanus americanus"),
    ("species_green_turtle", "Chelonia mydas"),
    ("species_hawksbill_turtle", "Eretmochelys imbricata"),
    ("species_loggerhead_turtle", "Caretta caretta"),
    ("species_bottlenose_dolphin", "Tursiops truncatus"),
    ("species_napoleon_wrasse", "Cheilinus undulatus"),
    ("species_moray_eel", "Muraena helena"),
    ("species_lionfish", "Pterois volitans"),
    ("species_great_barracuda", "Sphyraena barracuda"),
    ("species_octopus", "Octopus vulgaris"),
    ("species_cuttlefish", "Sepia officinalis"),
    ("species_nudibranch", "Chromodoris magnifica"),
    ("species_seahorse", "Hippocampus kuda"),
    ("species_pufferfish", "Arothron stellatus"),
    ("species_triggerfish", "Rhinecanthus aculeatus"),
    ("species_angelfish", "Pomacanthus annularis"),
    ("species_butterflyfish", "Chaetodon fasciatus"),
    ("species_parrotfish", "Scaridae family"),
    ("species_tuna", "Thunnus thynnus"),
    ("species_barracuda", "Sphyraena barracuda"),
    ("species_jacks", "Carangidae family"),
]

OBSERVATION_NOTES = [
    "School observed",
    "Solitary individual",
    "Pair courting",
    "Resting on sand",
    "Hunting behavior",
    "Feeding",
    "Well camouflaged",
    "Curious about divers",
    "Breeding pair visible",
    "Multiple individuals",
    "Rare encounter",
    "Playful behavior",
    "Large specimen",
    "Grazing on seagrass",
    "Patrolling hunters",
    "Sleeping position",
    "Cleaning station visit",
    "Passing through area",
]

def load_sites() -> List[Dict]:
    """Load the expanded sites (prefer 500+ version)."""
    try:
        with open("../../Resources/SeedData/sites_expanded_500plus.json") as f:
            data = json.load(f)
            return data["sites"]
    except:
        # Fallback to 225 sites version
        with open("../../Resources/SeedData/sites_expanded_200plus.json") as f:
            data = json.load(f)
            return data["sites"]

def generate_dive_logs(sites: List[Dict]) -> tuple[List[Dict], List[Dict]]:
    """Generate realistic dive logs and sightings for all sites."""
    dives = []
    sightings = []
    
    base_date = datetime(2024, 1, 1, tzinfo=timezone.utc)
    dive_id = 1
    sighting_id = 1
    
    # Generate 3-4 dives per site (realistic history)
    for site_idx, site in enumerate(sites):
        num_dives = random.randint(3, 4)
        
        for dive_num in range(num_dives):
            # Spread dives throughout the year
            days_offset = random.randint(0, 365)
            dive_date = base_date + timedelta(days=days_offset)
            
            dive_time = dive_date.replace(
                hour=random.randint(6, 18),
                minute=random.choice([0, 15, 30, 45])
            )
            
            # Realistic dive duration (30-90 minutes)
            bottom_time = random.randint(30, 90)
            end_time = dive_time + timedelta(minutes=bottom_time)
            
            # Depth based on site max depth
            max_site_depth = site.get("maxDepth", 40)
            max_dive_depth = random.uniform(
                max(3, max_site_depth * 0.4),
                max_site_depth
            )
            avg_dive_depth = max_dive_depth * random.uniform(0.5, 0.85)
            
            # Pressure (start 200 bar, end varies)
            start_pressure = 200
            air_consumed = random.randint(50, 150)
            end_pressure = start_pressure - air_consumed
            
            # Environmental conditions
            temp = site.get("averageTemp", 25) + random.randint(-3, 3)
            visibility = site.get("averageVisibility", 25) + random.randint(-10, 10)
            visibility = max(3, min(60, visibility))
            
            current_options = ["None", "Light", "Moderate", "Strong"]
            current = random.choice(current_options)
            
            conditions_options = ["Poor", "Fair", "Good", "Excellent"]
            conditions = random.choice(conditions_options)
            
            # Instructor details (30% signed)
            signed = random.random() < 0.3
            instructor_names = ["John Smith", "Maria Garcia", "Carlos Rodriguez", "Diana Lee", "Ahmed Hassan", "Sophie Martin"] if signed else [None]
            instructor_numbers = ["ID123456", "ID234567", "ID345678", "ID456789", "ID567890", "ID678901"] if signed else [None]
            
            dive = {
                "id": f"dive_ext_{dive_id:04d}",
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
                "notes": f"Dive at {site['name']}. {random.choice(['Great wildlife encounters.', 'Beautiful coral formations.', 'Excellent visibility today.', 'Challenging current.', 'Perfect for beginners.', 'Advanced dive site.'])}",
                "instructorName": random.choice(instructor_names),
                "instructorNumber": random.choice(instructor_numbers),
                "signed": signed,
                "createdAt": dive_date.isoformat().replace('+00:00', 'Z'),
                "updatedAt": dive_date.isoformat().replace('+00:00', 'Z'),
            }
            
            dives.append(dive)
            
            # Generate 1-5 sightings per dive
            num_sightings = random.randint(1, 5)
            chosen_species = random.sample(SPECIES_LIST, min(num_sightings, len(SPECIES_LIST)))
            
            for species_id, species_name in chosen_species:
                count = random.randint(1, 8)
                sighting = {
                    "id": f"sight_ext_{sighting_id:05d}",
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
    """Generate and save extended dive logs and sightings."""
    print("📚 Loading expanded sites...")
    sites = load_sites()
    print(f"✅ Loaded {len(sites)} sites")
    
    print("🤿 Generating realistic dive logs and sightings...")
    dives, sightings = generate_dive_logs(sites)
    
    print(f"✅ Generated {len(dives)} dive logs")
    print(f"✅ Generated {len(sightings)} sightings")
    
    # Save dive logs
    dives_output = {
        "version": "1.0",
        "source": "Generated",
        "generated_at": datetime.now(timezone.utc).isoformat(timespec='seconds').replace('+00:00', 'Z'),
        "count": len(dives),
        "dives": dives
    }
    
    with open("../../Resources/SeedData/dive_logs_expanded_1500plus.json", "w") as f:
        json.dump(dives_output, f, indent=2)
    
    print(f"📁 Dive logs saved to dive_logs_expanded_1500plus.json")
    
    # Save sightings
    sightings_output = {
        "version": "1.0",
        "source": "Generated",
        "generated_at": datetime.now(timezone.utc).isoformat(timespec='seconds').replace('+00:00', 'Z'),
        "count": len(sightings),
        "sightings": sightings
    }
    
    with open("../../Resources/SeedData/sightings_expanded_5000plus.json", "w") as f:
        json.dump(sightings_output, f, indent=2)
    
    print(f"📁 Sightings saved to sightings_expanded_5000plus.json")
    
    # Print statistics
    print("\n📊 Statistics:")
    print(f"  Dives per site: {len(dives) / len(sites):.1f} (avg)")
    print(f"  Sightings per dive: {len(sightings) / len(dives):.1f} (avg)")
    
    signed_count = sum(1 for d in dives if d["signed"])
    print(f"  Signed dives: {signed_count} ({100*signed_count/len(dives):.1f}%)")

if __name__ == "__main__":
    main()
