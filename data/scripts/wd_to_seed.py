#!/usr/bin/env python3
# Converts Wikidata SPARQL JSON to UmiLog seed JSON: Resources/SeedData/sites_wikidata.json
# Usage: python3 wd_to_seed.py raw/wd_dives.json Resources/SeedData/sites_wikidata.json

import sys, json, re
from datetime import datetime

if len(sys.argv) != 3:
    print("Usage: wd_to_seed.py <input_json> <output_json>")
    sys.exit(1)

inp, outp = sys.argv[1], sys.argv[2]

with open(inp, 'r', encoding='utf-8') as f:
    data = json.load(f)

bindings = data.get('results', {}).get('bindings', [])

# Country → Region bucket mapping (coarse)
COUNTRY_REGION = {
    'Egypt': 'Red Sea', 'Saudi Arabia': 'Red Sea', 'Sudan': 'Red Sea', 'Israel': 'Red Sea', 'Jordan': 'Red Sea',
    'Belize': 'Caribbean', 'Costa Rica': 'Caribbean', 'Mexico': 'Caribbean', 'Bahamas': 'Caribbean', 'Honduras': 'Caribbean',
    'Thailand': 'Southeast Asia', 'Malaysia': 'Southeast Asia', 'Indonesia': 'Southeast Asia', 'Philippines': 'Southeast Asia', 'Vietnam': 'Southeast Asia',
    'Greece': 'Mediterranean', 'Italy': 'Mediterranean', 'Spain': 'Mediterranean', 'Turkey': 'Mediterranean', 'France': 'Mediterranean',
    'Australia': 'Pacific', 'Japan': 'Pacific', 'United States of America': 'Pacific', 'Micronesia': 'Pacific', 'Palau': 'Pacific'
}

def parse_coord(coord):
    # coord is like: "Point(LON LAT)" or WKT literal; WD uses "Point(long lat)"
    m = re.match(r"Point\(([-0-9.]+) ([-0-9.]+)\)", coord)
    if not m: return None, None
    lon = float(m.group(1)); lat = float(m.group(2))
    return lat, lon

sites = []
seen = set()

for b in bindings:
    item = b.get('item', {}).get('value', '')            # e.g. https://www.wikidata.org/entity/Qxxx
    qid = item.rsplit('/',1)[-1]
    name = b.get('itemLabel', {}).get('value', '').strip()
    desc = b.get('description', {}).get('value', '').strip()
    coord = b.get('coord', {}).get('value', '')
    country = b.get('countryLabel', {}).get('value', '').strip() if 'countryLabel' in b else ''
    admin = b.get('adminLabel', {}).get('value', '').strip() if 'adminLabel' in b else ''

    # New fields from enhanced query
    depth_val = b.get('depth', {}).get('value', '') if 'depth' in b else ''
    image_url = b.get('image', {}).get('value', '') if 'image' in b else ''
    instance_of = b.get('instanceOfLabel', {}).get('value', '') if 'instanceOfLabel' in b else ''
    located_in = b.get('locatedInLabel', {}).get('value', '') if 'locatedInLabel' in b else ''
    inception = b.get('inceptionDate', {}).get('value', '') if 'inceptionDate' in b else ''
    website = b.get('website', {}).get('value', '') if 'website' in b else ''
    commons = b.get('commonsCategory', {}).get('value', '') if 'commonsCategory' in b else ''

    lat, lon = parse_coord(coord)
    if lat is None or lon is None:
        continue

    # Deduplicate by (name, lat, lon)
    key = (name, round(lat,5), round(lon,5))
    if key in seen: continue
    seen.add(key)

    # Region bucket
    region = COUNTRY_REGION.get(country, 'Global')

    # Area label: prefer admin area; fallback to empty
    area = admin or ''

    # Location string consumed by the app: "Area, Country" or just Country if area missing
    if area and country:
        location = f"{area}, {country}"
    else:
        location = country or area or 'Unknown'

    # Parse depth (elevation is negative for underwater)
    max_depth = None
    if depth_val:
        try:
            d = float(depth_val)
            max_depth = abs(d)  # Convert negative elevation to positive depth
        except ValueError:
            pass

    # Determine site type from instanceOf
    site_type = "reef"  # default
    instance_lower = instance_of.lower()
    if "wreck" in instance_lower or "shipwreck" in instance_lower:
        site_type = "wreck"
    elif "cave" in instance_lower or "cenote" in instance_lower:
        site_type = "cave"
    elif "wall" in instance_lower:
        site_type = "wall"

    # Parse wreck date from inception
    wreck_date = None
    if inception and site_type == "wreck":
        # Format: 1944-01-11T00:00:00Z or just year
        if 'T' in inception:
            wreck_date = inception.split('T')[0]
        else:
            wreck_date = inception[:10] if len(inception) >= 10 else inception

    # Build site object
    site = {
        "id": qid,
        "name": name or qid,
        "region": region,
        "area": area,
        "country": country,
        "latitude": lat,
        "longitude": lon,
        "difficulty": "Intermediate",
        "type": site_type,
        "description": desc,
        "averageDepth": (max_depth / 2) if max_depth else 15,
        "maxDepth": max_depth or 30,
        "averageTemp": 26,
        "averageVisibility": 20,
        "imageUrl": image_url if image_url else None,
        "website": website if website else None,
        "locatedIn": located_in if located_in else None,
        "wreckDate": wreck_date,
        "commonsCategory": commons if commons else None,
        "wikidataId": qid,
        "wishlist": False,
        "visitedCount": 0,
        "createdAt": datetime.utcnow().isoformat(timespec='seconds') + 'Z'
    }
    sites.append(site)

# Wrap in the seed file shape used by DatabaseSeeder
out = {"sites": sites}
with open(outp, 'w', encoding='utf-8') as f:
    json.dump(out, f, ensure_ascii=False, indent=2)

print(f"Wrote {len(sites)} sites → {outp}")
