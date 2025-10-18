#!/usr/bin/env python3
"""
Wikidata SPARQL scraper for dive sites.
Queries Wikidata for all dive sites with coordinates and depth information.
Outputs: scraped/wikidata_sites.json
License: CC0 (Wikidata public domain)
"""

import json
import requests
from typing import List, Dict, Optional
import time
import sys
from datetime import datetime

# Wikidata SPARQL endpoint
SPARQL_ENDPOINT = "https://query.wikidata.org/sparql"

# SPARQL query to find dive sites
SPARQL_QUERY = """
SELECT ?site ?siteLabel ?coord ?depth ?description ?depthLabel ?countryLabel
WHERE {
  ?site wdt:P31 wd:Q1076486 .  # instance of: dive site
  ?site wdt:P625 ?coord .       # has coordinates
  ?site wdt:P17 ?country .      # has country
  OPTIONAL { ?site wdt:P2660 ?depth }  # optional: max diving depth
  OPTIONAL { ?site schema:description ?description FILTER (LANG(?description) = "en") }
  
  SERVICE wikibase:label {
    bd:serviceParam wikibase:language "en" .
    ?site rdfs:label ?siteLabel .
    ?depth rdfs:label ?depthLabel .
    ?country rdfs:label ?countryLabel .
  }
}
LIMIT 1000
"""

def fetch_wikidata_sites() -> List[Dict]:
    """Fetch dive sites from Wikidata SPARQL endpoint."""
    print("🌐 Querying Wikidata for dive sites...")
    
    headers = {
        "User-Agent": "UmiLog Data Scraper (https://github.com/finn-log/umilog) - Contact: team@umilog.app",
        "Accept": "application/sparql-results+json"
    }
    
    params = {
        "query": SPARQL_QUERY,
        "format": "json"
    }
    
    try:
        response = requests.get(SPARQL_ENDPOINT, params=params, headers=headers, timeout=30)
        response.raise_for_status()
        data = response.json()
        
        sites = []
        bindings = data.get("results", {}).get("bindings", [])
        
        for binding in bindings:
            site_uri = binding.get("site", {}).get("value", "")
            site_id = site_uri.split("/")[-1] if site_uri else ""
            
            # Parse coordinates (format: "Point(lon lat)")
            coord_str = binding.get("coord", {}).get("value", "")
            lat, lon = None, None
            if coord_str.startswith("Point("):
                parts = coord_str[6:-1].split()
                if len(parts) >= 2:
                    try:
                        lon = float(parts[0])
                        lat = float(parts[1])
                    except ValueError:
                        pass
            
            if not lat or not lon:
                continue  # Skip if no valid coordinates
            
            # Parse depth (in meters)
            depth = None
            depth_val = binding.get("depth", {}).get("value", "")
            if depth_val:
                try:
                    depth = float(depth_val)
                except ValueError:
                    pass
            
            site = {
                "id": f"wiki_{site_id}",
                "name": binding.get("siteLabel", {}).get("value", "Unknown Site"),
                "latitude": lat,
                "longitude": lon,
                "maxDepth": depth or 40,  # default 40m if not specified
                "description": binding.get("description", {}).get("value", ""),
                "country": binding.get("countryLabel", {}).get("value", "Unknown"),
                "source": "Wikidata",
                "source_url": site_uri,
                "license": "CC0",
                "retrieved_at": datetime.utcnow().isoformat()
            }
            sites.append(site)
        
        print(f"✅ Found {len(sites)} dive sites from Wikidata")
        return sites
    
    except requests.exceptions.RequestException as e:
        print(f"❌ Error querying Wikidata: {e}", file=sys.stderr)
        return []

def main():
    """Main entry point."""
    sites = fetch_wikidata_sites()
    
    output = {
        "version": "1.0",
        "source": "Wikidata",
        "license": "CC0",
        "retrieved_at": datetime.utcnow().isoformat(),
        "count": len(sites),
        "sites": sites
    }
    
    # Ensure directory exists
    import os
    os.makedirs("scraped", exist_ok=True)
    
    output_file = "scraped/wikidata_sites.json"
    with open(output_file, "w") as f:
        json.dump(output, f, indent=2)
    
    print(f"📁 Output saved to {output_file}")
    print(f"📊 Summary: {len(sites)} sites harvested from Wikidata")

if __name__ == "__main__":
    main()
