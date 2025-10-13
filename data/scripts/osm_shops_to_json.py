#!/usr/bin/env python3
# Consolidate Overpass JSON node lists into a flat shops.json
# Usage: python3 osm_shops_to_json.py data/raw/shops_*.json data/export/shops.json

import sys, json, glob

if len(sys.argv) < 3:
    print("Usage: osm_shops_to_json.py <input_glob1> [<input_glob2> ...] <output_json>")
    sys.exit(1)

*inputs, outp = sys.argv[1:]

files = []
for pattern in inputs:
    files.extend(glob.glob(pattern))

shops = []
seen = set()
for fp in files:
    try:
        with open(fp, 'r', encoding='utf-8') as f:
            data = json.load(f)
    except Exception:
        continue
    elements = data.get('elements', [])
    for e in elements:
        if e.get('type') != 'node':
            continue
        nid = e.get('id')
        lat = e.get('lat')
        lon = e.get('lon')
        tags = e.get('tags', {})
        name = tags.get('name')
        phone = tags.get('phone') or tags.get('contact:phone')
        website = tags.get('website') or tags.get('contact:website')
        if lat is None or lon is None:
            continue
        key = (nid, round(lat,6), round(lon,6))
        if key in seen:
            continue
        seen.add(key)
        shops.append({
            "id": f"OSM_{nid}",
            "name": name or f"OSM {nid}",
            "lat": lat,
            "lon": lon,
            "phone": phone,
            "website": website,
            "amenities": {
                "nitrox": tags.get('nitrox') == 'yes',
                "training": bool(tags.get('training'))
            },
            "agency": [a.strip() for a in (tags.get('operator:type') or '').split(';') if a.strip()]
        })

with open(outp, 'w', encoding='utf-8') as f:
    json.dump({"shops": shops}, f, ensure_ascii=False, indent=2)

print(f"Wrote {len(shops)} shops → {outp}")
