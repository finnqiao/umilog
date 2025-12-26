#!/usr/bin/env python3
"""
Build geographic hierarchy (countries, regions, areas) from existing site data.
Uses ISO 3166-1 country codes and diving region conventions.

Usage: python3 geographic_hierarchy.py <sites_json> <output_dir>
Example: python3 geographic_hierarchy.py export/sites_merged.json export/
Outputs: countries.json, regions.json, areas.json
"""

import sys
import json
import re
from collections import defaultdict
from datetime import datetime

# ISO 3166-1 alpha-2 codes and continent mapping
COUNTRIES = {
    # Africa
    "EG": {"name": "Egypt", "continent": "Africa"},
    "SD": {"name": "Sudan", "continent": "Africa"},
    "DJ": {"name": "Djibouti", "continent": "Africa"},
    "SO": {"name": "Somalia", "continent": "Africa"},
    "TZ": {"name": "Tanzania", "continent": "Africa"},
    "KE": {"name": "Kenya", "continent": "Africa"},
    "MZ": {"name": "Mozambique", "continent": "Africa"},
    "ZA": {"name": "South Africa", "continent": "Africa"},
    "MU": {"name": "Mauritius", "continent": "Africa"},
    "SC": {"name": "Seychelles", "continent": "Africa"},
    "MG": {"name": "Madagascar", "continent": "Africa"},
    # Asia
    "TH": {"name": "Thailand", "continent": "Asia"},
    "MY": {"name": "Malaysia", "continent": "Asia"},
    "ID": {"name": "Indonesia", "continent": "Asia"},
    "PH": {"name": "Philippines", "continent": "Asia"},
    "VN": {"name": "Vietnam", "continent": "Asia"},
    "JP": {"name": "Japan", "continent": "Asia"},
    "MV": {"name": "Maldives", "continent": "Asia"},
    "LK": {"name": "Sri Lanka", "continent": "Asia"},
    "IN": {"name": "India", "continent": "Asia"},
    "SA": {"name": "Saudi Arabia", "continent": "Asia"},
    "AE": {"name": "United Arab Emirates", "continent": "Asia"},
    "OM": {"name": "Oman", "continent": "Asia"},
    "JO": {"name": "Jordan", "continent": "Asia"},
    "IL": {"name": "Israel", "continent": "Asia"},
    "MM": {"name": "Myanmar", "continent": "Asia"},
    "KH": {"name": "Cambodia", "continent": "Asia"},
    # Oceania
    "AU": {"name": "Australia", "continent": "Oceania"},
    "NZ": {"name": "New Zealand", "continent": "Oceania"},
    "PG": {"name": "Papua New Guinea", "continent": "Oceania"},
    "FJ": {"name": "Fiji", "continent": "Oceania"},
    "PF": {"name": "French Polynesia", "continent": "Oceania"},
    "NC": {"name": "New Caledonia", "continent": "Oceania"},
    "VU": {"name": "Vanuatu", "continent": "Oceania"},
    "WS": {"name": "Samoa", "continent": "Oceania"},
    "PW": {"name": "Palau", "continent": "Oceania"},
    "FM": {"name": "Micronesia", "continent": "Oceania"},
    "MH": {"name": "Marshall Islands", "continent": "Oceania"},
    "GU": {"name": "Guam", "continent": "Oceania"},
    # Europe
    "ES": {"name": "Spain", "continent": "Europe"},
    "IT": {"name": "Italy", "continent": "Europe"},
    "GR": {"name": "Greece", "continent": "Europe"},
    "HR": {"name": "Croatia", "continent": "Europe"},
    "MT": {"name": "Malta", "continent": "Europe"},
    "CY": {"name": "Cyprus", "continent": "Europe"},
    "TR": {"name": "Turkey", "continent": "Europe"},
    "PT": {"name": "Portugal", "continent": "Europe"},
    "FR": {"name": "France", "continent": "Europe"},
    "GB": {"name": "United Kingdom", "continent": "Europe"},
    "IE": {"name": "Ireland", "continent": "Europe"},
    "NO": {"name": "Norway", "continent": "Europe"},
    "IS": {"name": "Iceland", "continent": "Europe"},
    "ME": {"name": "Montenegro", "continent": "Europe"},
    "SI": {"name": "Slovenia", "continent": "Europe"},
    # North America
    "US": {"name": "United States", "continent": "North America"},
    "MX": {"name": "Mexico", "continent": "North America"},
    "CA": {"name": "Canada", "continent": "North America"},
    "BZ": {"name": "Belize", "continent": "North America"},
    "HN": {"name": "Honduras", "continent": "North America"},
    "CR": {"name": "Costa Rica", "continent": "North America"},
    "PA": {"name": "Panama", "continent": "North America"},
    # Caribbean
    "BS": {"name": "Bahamas", "continent": "North America"},
    "CU": {"name": "Cuba", "continent": "North America"},
    "JM": {"name": "Jamaica", "continent": "North America"},
    "DO": {"name": "Dominican Republic", "continent": "North America"},
    "PR": {"name": "Puerto Rico", "continent": "North America"},
    "KY": {"name": "Cayman Islands", "continent": "North America"},
    "TC": {"name": "Turks and Caicos", "continent": "North America"},
    "VG": {"name": "British Virgin Islands", "continent": "North America"},
    "VI": {"name": "US Virgin Islands", "continent": "North America"},
    "BB": {"name": "Barbados", "continent": "North America"},
    "LC": {"name": "Saint Lucia", "continent": "North America"},
    "AG": {"name": "Antigua and Barbuda", "continent": "North America"},
    "CW": {"name": "Curacao", "continent": "North America"},
    "BQ": {"name": "Bonaire", "continent": "North America"},
    "AW": {"name": "Aruba", "continent": "North America"},
    # South America
    "BR": {"name": "Brazil", "continent": "South America"},
    "CO": {"name": "Colombia", "continent": "South America"},
    "VE": {"name": "Venezuela", "continent": "South America"},
    "EC": {"name": "Ecuador", "continent": "South America"},
    "PE": {"name": "Peru", "continent": "South America"},
    "CL": {"name": "Chile", "continent": "South America"},
    "AR": {"name": "Argentina", "continent": "South America"},
}

# Country name to ISO code lookup
COUNTRY_NAME_TO_CODE = {v["name"].lower(): k for k, v in COUNTRIES.items()}
COUNTRY_NAME_TO_CODE.update({
    "united states of america": "US",
    "usa": "US",
    "uk": "GB",
    "uae": "AE",
})

# Diving region definitions
REGION_DEFS = {
    "red-sea": {
        "name": "Red Sea",
        "countries": ["EG", "SD", "SA", "JO", "IL", "DJ"],
    },
    "indian-ocean": {
        "name": "Indian Ocean",
        "countries": ["MV", "SC", "MU", "MG", "LK", "IN", "OM", "AE"],
    },
    "southeast-asia": {
        "name": "Southeast Asia",
        "countries": ["TH", "MY", "ID", "PH", "VN", "MM", "KH"],
    },
    "coral-triangle": {
        "name": "Coral Triangle",
        "countries": ["ID", "PH", "MY", "PG", "TL", "SB"],
    },
    "japan": {
        "name": "Japan",
        "countries": ["JP"],
    },
    "australia": {
        "name": "Australia",
        "countries": ["AU"],
    },
    "pacific-islands": {
        "name": "Pacific Islands",
        "countries": ["FJ", "PF", "NC", "VU", "WS", "PW", "FM", "MH", "GU", "NZ"],
    },
    "caribbean": {
        "name": "Caribbean",
        "countries": ["BS", "CU", "JM", "DO", "PR", "KY", "TC", "VG", "VI", "BB", "LC", "AG", "CW", "BQ", "AW", "BZ", "HN", "MX"],
    },
    "central-america": {
        "name": "Central America",
        "countries": ["CR", "PA", "BZ", "HN"],
    },
    "mediterranean": {
        "name": "Mediterranean",
        "countries": ["ES", "IT", "GR", "HR", "MT", "CY", "TR", "FR", "ME", "SI"],
    },
    "atlantic": {
        "name": "Atlantic",
        "countries": ["PT", "ES", "GB", "IE", "NO", "IS", "US", "CA"],
    },
    "south-america": {
        "name": "South America",
        "countries": ["BR", "CO", "VE", "EC", "PE", "CL", "AR"],
    },
    "africa": {
        "name": "Africa",
        "countries": ["TZ", "KE", "MZ", "ZA", "SO"],
    },
}

# Build country to region mapping
COUNTRY_TO_REGION = {}
for region_id, region_data in REGION_DEFS.items():
    for country_code in region_data["countries"]:
        if country_code not in COUNTRY_TO_REGION:
            COUNTRY_TO_REGION[country_code] = region_id


def slugify(text):
    """Convert text to URL-safe slug."""
    text = text.lower().strip()
    text = re.sub(r'[^\w\s-]', '', text)
    text = re.sub(r'[\s_]+', '-', text)
    text = re.sub(r'-+', '-', text)
    return text.strip('-')


def get_country_code(country_name):
    """Get ISO code from country name."""
    if not country_name:
        return None
    normalized = country_name.lower().strip()
    return COUNTRY_NAME_TO_CODE.get(normalized)


def parse_location(location_str):
    """Parse location string like 'Area, Country' into components."""
    if not location_str:
        return None, None
    parts = [p.strip() for p in location_str.split(',')]
    if len(parts) >= 2:
        return parts[0], parts[-1]  # area, country
    return None, parts[0]  # just country


def main():
    if len(sys.argv) < 3:
        print("Usage: geographic_hierarchy.py <sites_json> <output_dir>")
        sys.exit(1)

    sites_file = sys.argv[1]
    output_dir = sys.argv[2].rstrip('/')

    # Load sites
    with open(sites_file, 'r', encoding='utf-8') as f:
        data = json.load(f)

    sites = data.get('sites', data) if isinstance(data, dict) else data

    # Collect unique countries, regions, areas
    countries_found = set()
    areas_by_region = defaultdict(set)
    site_countries = defaultdict(list)  # country_code -> site coords

    for site in sites:
        # Try to get country from site data
        country_name = site.get('country', '')
        location = site.get('location', '')

        if not country_name and location:
            _, country_name = parse_location(location)

        country_code = get_country_code(country_name)
        if country_code and country_code in COUNTRIES:
            countries_found.add(country_code)
            site_countries[country_code].append({
                'lat': site.get('latitude'),
                'lon': site.get('longitude'),
            })

            # Get area from location
            area_name, _ = parse_location(location)
            if area_name:
                region_id = COUNTRY_TO_REGION.get(country_code, 'global')
                areas_by_region[(region_id, country_code)].add(area_name)

    # Build countries output
    countries_out = []
    for code in sorted(countries_found):
        country_data = COUNTRIES[code]
        countries_out.append({
            "id": code,
            "name": country_data["name"],
            "continent": country_data["continent"],
        })

    # Build regions output
    regions_out = []
    regions_found = set()
    for code in countries_found:
        region_id = COUNTRY_TO_REGION.get(code)
        if region_id and region_id not in regions_found:
            regions_found.add(region_id)
            region_data = REGION_DEFS.get(region_id, {"name": region_id.replace('-', ' ').title()})

            # Calculate centroid from site coords
            all_coords = []
            for c in region_data.get("countries", [code]):
                all_coords.extend(site_countries.get(c, []))

            lat, lon = None, None
            if all_coords:
                lats = [c['lat'] for c in all_coords if c['lat'] is not None]
                lons = [c['lon'] for c in all_coords if c['lon'] is not None]
                if lats and lons:
                    lat = sum(lats) / len(lats)
                    lon = sum(lons) / len(lons)

            regions_out.append({
                "id": region_id,
                "name": region_data["name"],
                "latitude": lat,
                "longitude": lon,
            })

    # Build areas output
    areas_out = []
    for (region_id, country_code), area_names in areas_by_region.items():
        for area_name in sorted(area_names):
            area_id = slugify(f"{country_code}-{area_name}")
            areas_out.append({
                "id": area_id,
                "name": area_name,
                "region_id": region_id,
                "country_id": country_code,
            })

    # Write outputs
    with open(f"{output_dir}/countries.json", 'w', encoding='utf-8') as f:
        json.dump({"countries": countries_out}, f, ensure_ascii=False, indent=2)

    with open(f"{output_dir}/regions.json", 'w', encoding='utf-8') as f:
        json.dump({"regions": regions_out}, f, ensure_ascii=False, indent=2)

    with open(f"{output_dir}/areas.json", 'w', encoding='utf-8') as f:
        json.dump({"areas": areas_out}, f, ensure_ascii=False, indent=2)

    print(f"Generated {len(countries_out)} countries, {len(regions_out)} regions, {len(areas_out)} areas")
    print(f"Output: {output_dir}/countries.json, regions.json, areas.json")


if __name__ == "__main__":
    main()
