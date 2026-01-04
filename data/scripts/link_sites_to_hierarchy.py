#!/usr/bin/env python3
"""
Link dive sites to geographic hierarchy (country_id, region_id, area_id).

This script:
1. Loads merged sites
2. Uses coordinate-based detection to determine country and region
3. Falls back to parsing location/country fields if available
4. Updates sites with country_id, region_id
5. Outputs linked sites file

Usage:
    python3 link_sites_to_hierarchy.py <sites_json> <output_json>

Example:
    python3 link_sites_to_hierarchy.py \
        data/export/sites_merged.json \
        data/export/sites_linked.json
"""

import json
import sys
from pathlib import Path
from datetime import datetime, timezone
from collections import defaultdict


# Country bounding boxes for reverse geocoding
# Format: (min_lat, max_lat, min_lon, max_lon, country_code)
COUNTRY_BOXES = [
    # Red Sea
    (22, 32, 32, 36, "EG"),  # Egypt
    (14, 22, 36, 44, "SA"),  # Saudi Arabia
    (11, 14, 42, 44, "DJ"),  # Djibouti
    (27, 34, 34, 36, "IL"),  # Israel
    (29, 33, 34, 40, "JO"),  # Jordan
    (15, 23, 36, 44, "SD"),  # Sudan

    # Indian Ocean
    (-1, 8, 72, 74, "MV"),   # Maldives
    (-5, -3, 55, 56, "SC"),  # Seychelles
    (-21, -19, 55, 58, "MU"), # Mauritius
    (5, 10, 79, 82, "LK"),   # Sri Lanka

    # Southeast Asia
    (5, 21, 97, 106, "TH"),  # Thailand
    (0, 8, 99, 120, "MY"),   # Malaysia
    (-11, 6, 95, 141, "ID"), # Indonesia
    (4, 21, 117, 127, "PH"), # Philippines
    (8, 24, 102, 110, "VN"), # Vietnam
    (11, 23, 97, 107, "MM"), # Myanmar

    # Japan
    (24, 46, 122, 146, "JP"),

    # Australia
    (-44, -10, 113, 154, "AU"),

    # New Zealand
    (-48, -34, 166, 179, "NZ"),

    # Pacific Islands
    (-22, -12, 176, 180, "FJ"), # Fiji
    (-18, -8, 177, -177, "FJ"), # Fiji (crosses date line)
    (5, 10, 132, 135, "PW"),    # Palau
    (-6, 0, 146, 156, "PG"),    # Papua New Guinea

    # Caribbean
    (21, 27, -80, -72, "BS"),   # Bahamas
    (17, 20, -73, -68, "DO"),   # Dominican Republic
    (17, 20, -78, -74, "JM"),   # Jamaica
    (19, 24, -85, -74, "CU"),   # Cuba
    (17, 20, -67, -65, "PR"),   # Puerto Rico
    (19, 20, -82, -79, "KY"),   # Cayman Islands
    (18, 19, -65, -64, "VG"),   # British Virgin Islands
    (12, 14, -62, -60, "BB"),   # Barbados
    (11, 13, -70, -68, "CW"),   # Curacao
    (12, 13, -69, -68, "BQ"),   # Bonaire
    (12, 13, -70, -69, "AW"),   # Aruba

    # Central America
    (7, 10, -83, -77, "PA"),    # Panama
    (8, 12, -86, -82, "CR"),    # Costa Rica
    (15, 17, -89, -87, "BZ"),   # Belize
    (13, 17, -90, -83, "HN"),   # Honduras
    (14, 33, -118, -86, "MX"),  # Mexico

    # Mediterranean
    (35, 44, -10, 5, "ES"),     # Spain
    (36, 47, 6, 19, "IT"),      # Italy
    (34, 42, 19, 30, "GR"),     # Greece
    (42, 46, 13, 20, "HR"),     # Croatia
    (35, 36, 14, 15, "MT"),     # Malta
    (34, 36, 32, 35, "CY"),     # Cyprus
    (36, 42, 26, 45, "TR"),     # Turkey
    (36, 44, -10, 0, "PT"),     # Portugal
    (41, 51, -6, 10, "FR"),     # France

    # Atlantic/UK
    (49, 61, -11, 2, "GB"),     # United Kingdom
    (51, 56, -11, -5, "IE"),    # Ireland
    (57, 72, 4, 32, "NO"),      # Norway
    (63, 67, -25, -13, "IS"),   # Iceland

    # South America
    (-34, 6, -74, -34, "BR"),   # Brazil
    (-5, 13, -82, -66, "CO"),   # Colombia
    (1, 12, -73, -60, "VE"),    # Venezuela
    (-5, 2, -81, -75, "EC"),    # Ecuador

    # Africa
    (-35, -22, 16, 33, "ZA"),   # South Africa
    (-12, -1, 39, 41, "TZ"),    # Tanzania
    (-5, 5, 39, 42, "KE"),      # Kenya
    (-27, -10, 32, 41, "MZ"),   # Mozambique
]

# Region definitions from geographic_hierarchy.py
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
        "countries": ["FJ", "PF", "NC", "VU", "WS", "PW", "FM", "MH", "GU", "NZ", "PG"],
    },
    "caribbean": {
        "name": "Caribbean",
        "countries": ["BS", "CU", "JM", "DO", "PR", "KY", "TC", "VG", "VI", "BB", "LC", "AG", "CW", "BQ", "AW", "BZ", "HN", "MX"],
    },
    "central-america": {
        "name": "Central America",
        "countries": ["CR", "PA"],
    },
    "mediterranean": {
        "name": "Mediterranean",
        "countries": ["ES", "IT", "GR", "HR", "MT", "CY", "TR", "FR", "ME", "SI", "PT"],
    },
    "atlantic": {
        "name": "Atlantic",
        "countries": ["GB", "IE", "NO", "IS"],
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

# Build reverse lookup
COUNTRY_TO_REGION = {}
for region_id, region_data in REGION_DEFS.items():
    for country_code in region_data["countries"]:
        if country_code not in COUNTRY_TO_REGION:
            COUNTRY_TO_REGION[country_code] = region_id

# Country name to code
COUNTRY_NAME_TO_CODE = {
    "egypt": "EG",
    "saudi arabia": "SA",
    "djibouti": "DJ",
    "israel": "IL",
    "jordan": "JO",
    "sudan": "SD",
    "maldives": "MV",
    "seychelles": "SC",
    "mauritius": "MU",
    "sri lanka": "LK",
    "thailand": "TH",
    "malaysia": "MY",
    "indonesia": "ID",
    "philippines": "PH",
    "vietnam": "VN",
    "myanmar": "MM",
    "japan": "JP",
    "australia": "AU",
    "new zealand": "NZ",
    "fiji": "FJ",
    "palau": "PW",
    "papua new guinea": "PG",
    "bahamas": "BS",
    "dominican republic": "DO",
    "jamaica": "JM",
    "cuba": "CU",
    "puerto rico": "PR",
    "cayman islands": "KY",
    "british virgin islands": "VG",
    "barbados": "BB",
    "curacao": "CW",
    "bonaire": "BQ",
    "aruba": "AW",
    "panama": "PA",
    "costa rica": "CR",
    "belize": "BZ",
    "honduras": "HN",
    "mexico": "MX",
    "spain": "ES",
    "italy": "IT",
    "greece": "GR",
    "croatia": "HR",
    "malta": "MT",
    "cyprus": "CY",
    "turkey": "TR",
    "portugal": "PT",
    "france": "FR",
    "united kingdom": "GB",
    "ireland": "IE",
    "norway": "NO",
    "iceland": "IS",
    "brazil": "BR",
    "colombia": "CO",
    "venezuela": "VE",
    "ecuador": "EC",
    "south africa": "ZA",
    "tanzania": "TZ",
    "kenya": "KE",
    "mozambique": "MZ",
    "usa": "US",
    "united states": "US",
    "uk": "GB",
}


def detect_country_from_coords(lat: float, lon: float) -> str | None:
    """Detect country from coordinates using bounding boxes."""
    if lat is None or lon is None:
        return None

    for min_lat, max_lat, min_lon, max_lon, country_code in COUNTRY_BOXES:
        if min_lat <= lat <= max_lat and min_lon <= lon <= max_lon:
            return country_code

    return None


def detect_region_from_coords(lat: float, lon: float) -> str:
    """Determine diving region from coordinates (fallback)."""
    if lat is None or lon is None:
        return "global"

    if 12 <= lat <= 30 and 32 <= lon <= 44:
        return "red-sea"
    if -10 <= lat <= 10 and 95 <= lon <= 145:
        return "southeast-asia"
    if lat <= 20 and 95 <= lon <= 120:
        return "southeast-asia"
    if 24 <= lat <= 46 and 122 <= lon <= 146:
        return "japan"
    if -30 <= lat <= 0 and 110 <= lon <= 160:
        return "australia"
    if 10 <= lat <= 28 and -90 <= lon <= -60:
        return "caribbean"
    if 7 <= lat <= 25 and -120 <= lon <= -80:
        return "central-america"
    if 30 <= lat <= 46 and -6 <= lon <= 36:
        return "mediterranean"
    if -2 <= lat <= 10 and 71 <= lon <= 82:
        return "indian-ocean"
    if -30 <= lat <= 10 and 130 <= lon <= 180:
        return "pacific-islands"
    if 45 <= lat <= 72 and -25 <= lon <= 35:
        return "atlantic"
    if -35 <= lat <= 10 and -80 <= lon <= -30:
        return "south-america"
    if -35 <= lat <= 10 and 15 <= lon <= 55:
        return "africa"

    return "global"


def get_country_from_name(country_name: str) -> str | None:
    """Get country code from country name."""
    if not country_name:
        return None
    normalized = country_name.lower().strip()
    return COUNTRY_NAME_TO_CODE.get(normalized)


def link_site(site: dict) -> dict:
    """Link a single site to the geographic hierarchy."""
    lat = site.get("latitude")
    lon = site.get("longitude")

    # Try to get country from existing data
    country_code = None

    # 1. Check existing country field
    if site.get("country"):
        country_code = get_country_from_name(site["country"])

    # 2. Try coordinate-based detection
    if not country_code:
        country_code = detect_country_from_coords(lat, lon)

    # 3. Parse location field
    if not country_code and site.get("location"):
        parts = site["location"].split(",")
        if len(parts) >= 2:
            country_name = parts[-1].strip()
            country_code = get_country_from_name(country_name)

    # Get region from country or coordinates
    if country_code:
        region_id = COUNTRY_TO_REGION.get(country_code, "global")
    else:
        region_id = detect_region_from_coords(lat, lon)

    # Update site
    site["country_id"] = country_code
    site["region_id"] = region_id
    site["area_id"] = None  # Areas require more specific logic

    return site


def main():
    if len(sys.argv) != 3:
        print(__doc__)
        sys.exit(1)

    input_path = Path(sys.argv[1])
    output_path = Path(sys.argv[2])

    # Load sites
    print(f"Loading sites: {input_path}")
    with open(input_path) as f:
        data = json.load(f)

    sites = data.get("sites", data) if isinstance(data, dict) else data
    print(f"  {len(sites)} sites loaded")

    # Link each site
    print("\nLinking sites to hierarchy...")
    for site in sites:
        link_site(site)

    # Stats
    with_country = sum(1 for s in sites if s.get("country_id"))
    with_region = sum(1 for s in sites if s.get("region_id") and s["region_id"] != "global")

    print(f"  {with_country}/{len(sites)} sites with country_id ({100*with_country/len(sites):.1f}%)")
    print(f"  {with_region}/{len(sites)} sites with region_id ({100*with_region/len(sites):.1f}%)")

    # Country distribution
    country_counts = defaultdict(int)
    for site in sites:
        country_counts[site.get("country_id", "unknown")] += 1

    print("\nTop countries:")
    for country, count in sorted(country_counts.items(), key=lambda x: -x[1])[:15]:
        print(f"  {country or 'None'}: {count}")

    # Region distribution
    region_counts = defaultdict(int)
    for site in sites:
        region_counts[site.get("region_id", "global")] += 1

    print("\nRegions:")
    for region, count in sorted(region_counts.items(), key=lambda x: -x[1]):
        print(f"  {region}: {count}")

    # Output
    output = {
        "sites": sites,
        "metadata": {
            "generated_at": datetime.now(timezone.utc).isoformat(),
            "source": str(input_path),
            "total_sites": len(sites),
            "sites_with_country": with_country,
            "sites_with_region": with_region,
        }
    }

    output_path.parent.mkdir(parents=True, exist_ok=True)
    with open(output_path, "w") as f:
        json.dump(output, f, indent=2)

    print(f"\nOutput written to: {output_path}")


if __name__ == "__main__":
    main()
