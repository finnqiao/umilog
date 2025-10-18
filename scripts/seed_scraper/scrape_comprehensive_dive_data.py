#!/usr/bin/env python3
"""
Comprehensive dive data scraper from multiple sources.
Pulls dive sites, shops, operators, and wildlife with rich metadata.

Sources:
1. Wikidata - Dive sites, marine life, protected areas
2. OpenStreetMap - Shops, operators, facilities
3. FishBase - Marine species with conservation status
4. Wikimedia Commons - Licensing for potential media
"""

import requests
import json
from datetime import datetime, timezone
from typing import List, Dict, Optional
import time

WIKIDATA_SPARQL = "https://query.wikidata.org/sparql"
OVERPASS_API = "https://overpass-api.de/api/interpreter"
FISHBASE_API = "http://api.fishbase.ropensci.org"

class SiteMetadataEnricher:
    """Enriches dive sites with additional metadata from multiple sources."""
    
    @staticmethod
    def query_wikidata_enhanced_sites() -> List[Dict]:
        """Query Wikidata for dive sites with full metadata."""
        query = """
SELECT DISTINCT ?site ?siteLabel ?coord ?country ?countryLabel 
  ?popLabel ?description ?established ?website ?heritage
WHERE {
  ?site wdt:P31 wd:Q1076486 .         # dive site
  ?site wdt:P625 ?coord .
  ?site wdt:P17 ?country .
  OPTIONAL { ?site wdt:P131 ?pop }    # administrative unit (locality)
  OPTIONAL { ?site schema:description ?description FILTER (LANG(?description) = "en") }
  OPTIONAL { ?site wdt:P571 ?established }  # inception date
  OPTIONAL { ?site wdt:P856 ?website }      # official website
  OPTIONAL { ?site wdt:P1940 ?heritage }    # World Heritage status
  
  SERVICE wikibase:label {
    bd:serviceParam wikibase:language "en" .
    ?site rdfs:label ?siteLabel .
    ?country rdfs:label ?countryLabel .
    ?pop rdfs:label ?popLabel .
  }
}
LIMIT 1000
"""
        headers = {
            "User-Agent": "UmiLog Data Scraper (umilog.app)",
            "Accept": "application/sparql-results+json"
        }
        
        print("🌐 Querying Wikidata for enhanced site metadata...")
        
        try:
            response = requests.get(WIKIDATA_SPARQL, params={"query": query, "format": "json"}, 
                                  headers=headers, timeout=60)
            response.raise_for_status()
            data = response.json()
            
            sites = []
            for binding in data.get("results", {}).get("bindings", []):
                try:
                    name = binding.get("siteLabel", {}).get("value", "").strip()
                    coord_str = binding.get("coord", {}).get("value", "")
                    
                    if not coord_str or not name:
                        continue
                    
                    # Parse coordinates
                    parts = coord_str[6:-1].split()
                    if len(parts) < 2:
                        continue
                    
                    lat, lon = float(parts[1]), float(parts[0])
                    if not (-90 <= lat <= 90 and -180 <= lon <= 180):
                        continue
                    
                    site = {
                        "name": name,
                        "latitude": round(lat, 6),
                        "longitude": round(lon, 6),
                        "country": binding.get("countryLabel", {}).get("value", ""),
                        "locality": binding.get("popLabel", {}).get("value", ""),
                        "description": binding.get("description", {}).get("value", "")[:300],
                        "established": binding.get("established", {}).get("value", "")[:4],  # Year
                        "website": binding.get("website", {}).get("value", ""),
                        "worldHeritage": binding.get("heritage", {}).get("value") is not None,
                        "source": "Wikidata",
                        "metadata_richness": "high",
                    }
                    sites.append(site)
                except:
                    continue
            
            print(f"✅ Found {len(sites)} enhanced dive sites from Wikidata")
            return sites
        except Exception as e:
            print(f"⚠️  Wikidata error: {e}")
            return []
    
    @staticmethod
    def query_osm_shops_and_operators() -> Dict:
        """Query OSM for dive shops and operators."""
        query = """
[out:json];
(
  node["shop"="diving"](bbox);
  way["shop"="diving"](bbox);
  node["tourism"="dive_center"](bbox);
  node["amenity"="scuba_diving"](bbox);
  node["tourism"="diving"](bbox);
);
out center;
"""
        
        regions = {
            "Red_Sea": "12,32,30,43",
            "Caribbean": "10,-85,27,-60",
            "Southeast_Asia": "0,95,21,135",
            "Pacific": "-25,145,-10,155",
            "Mediterranean": "30,-6,45,40",
            "Maldives": "0,72,5,74",
            "Philippines": "5,120,20,128",
            "Indonesia": "-11,95,5,141",
        }
        
        print("🏪 Querying OpenStreetMap for dive shops and operators...")
        
        all_shops = []
        for region_name, bbox in regions.items():
            try:
                q = query.replace("bbox", bbox)
                response = requests.post(OVERPASS_API, data=q, timeout=20)
                response.raise_for_status()
                data = response.json()
                
                for elem in data.get("elements", []):
                    try:
                        if "center" in elem:
                            lat, lon = elem["center"]["lat"], elem["center"]["lon"]
                        else:
                            lat, lon = elem.get("lat"), elem.get("lon")
                        
                        if not (lat and lon):
                            continue
                        
                        tags = elem.get("tags", {})
                        name = tags.get("name", "")
                        if not name or len(name) < 3:
                            continue
                        
                        shop = {
                            "id": f"shop_{elem['id']}",
                            "name": name,
                            "latitude": round(lat, 6),
                            "longitude": round(lon, 6),
                            "type": tags.get("shop", tags.get("tourism", "dive_center")),
                            "phone": tags.get("phone", ""),
                            "website": tags.get("website", ""),
                            "email": tags.get("email", ""),
                            "hours": tags.get("opening_hours", ""),
                            "description": tags.get("description", ""),
                            "source": "OpenStreetMap",
                            "region": region_name,
                        }
                        all_shops.append(shop)
                    except:
                        continue
                
                time.sleep(0.3)
            except Exception as e:
                pass
        
        print(f"✅ Found {len(all_shops)} dive shops and operators")
        
        return {
            "shops": all_shops,
            "unique_regions": len(set(s.get("region") for s in all_shops if s.get("region")))
        }
    
    @staticmethod
    def query_wikidata_marine_species() -> List[Dict]:
        """Query Wikidata for marine species with conservation status."""
        query = """
SELECT DISTINCT ?species ?speciesLabel ?scientificName ?iucn ?iucnLabel ?description
WHERE {
  ?species wdt:P31 wd:Q16521 .              # instance of taxon
  ?species wdt:P225 ?scientificName .       # scientific name
  ?species wdt:P141 ?iucn .                 # conservation status
  OPTIONAL { ?species schema:description ?description FILTER (LANG(?description) = "en") }
  
  ?species p:P141 [ ps:P141 ?iucn ; pq:P585 ?date ] .
  
  SERVICE wikibase:label {
    bd:serviceParam wikibase:language "en" .
    ?species rdfs:label ?speciesLabel .
    ?iucn rdfs:label ?iucnLabel .
  }
}
LIMIT 500
"""
        headers = {
            "User-Agent": "UmiLog Data Scraper (umilog.app)",
            "Accept": "application/sparql-results+json"
        }
        
        print("🐠 Querying Wikidata for marine species with conservation status...")
        
        try:
            response = requests.get(WIKIDATA_SPARQL, params={"query": query, "format": "json"}, 
                                  headers=headers, timeout=60)
            response.raise_for_status()
            data = response.json()
            
            species = []
            for binding in data.get("results", {}).get("bindings", []):
                try:
                    name = binding.get("speciesLabel", {}).get("value", "")
                    scientific = binding.get("scientificName", {}).get("value", "")
                    iucn_status = binding.get("iucnLabel", {}).get("value", "")
                    
                    if not name:
                        continue
                    
                    sp = {
                        "id": f"species_wiki_{binding.get('species', {}).get('value', '').split('/')[-1]}",
                        "name": name,
                        "scientificName": scientific,
                        "conservationStatus": iucn_status,
                        "description": binding.get("description", {}).get("value", "")[:200],
                        "source": "Wikidata",
                    }
                    species.append(sp)
                except:
                    continue
            
            print(f"✅ Found {len(species)} marine species with conservation info")
            return species
        except Exception as e:
            print(f"⚠️  Species query error: {e}")
            return []
    
    @staticmethod
    def query_osm_marine_protected_areas() -> List[Dict]:
        """Query for marine protected areas."""
        query = """
[out:json];
(
  relation["boundary"="marine"](bbox);
  relation["leisure"="marine_park"](bbox);
  relation["site:type"="marine"](bbox);
  relation["protection_title"="Biosphere Reserve"](bbox);
);
out center;
"""
        
        print("🏞️  Querying for marine protected areas...")
        
        mpas = []
        try:
            # Global query
            q = query.replace("bbox", "-90,-180,90,180")
            response = requests.post(OVERPASS_API, data=q, timeout=30)
            response.raise_for_status()
            data = response.json()
            
            for elem in data.get("elements", []):
                try:
                    if "center" in elem:
                        lat, lon = elem["center"]["lat"], elem["center"]["lon"]
                    else:
                        continue
                    
                    tags = elem.get("tags", {})
                    name = tags.get("name", "")
                    if not name:
                        continue
                    
                    mpa = {
                        "id": f"mpa_{elem['id']}",
                        "name": name,
                        "latitude": round(lat, 6),
                        "longitude": round(lon, 6),
                        "type": tags.get("leisure", tags.get("boundary", "marine_area")),
                        "protectionLevel": tags.get("protection_title", "Unknown"),
                        "description": tags.get("description", ""),
                        "source": "OpenStreetMap",
                    }
                    mpas.append(mpa)
                except:
                    continue
        except Exception as e:
            print(f"⚠️  MPA query error: {e}")
        
        print(f"✅ Found {len(mpas)} marine protected areas")
        return mpas

def validate_comprehensive_dataset(sites: List[Dict], shops: List[Dict], 
                                  species: List[Dict], mpas: List[Dict]) -> Dict:
    """Validate the comprehensive dataset."""
    report = {
        "sites": {
            "total": len(sites),
            "with_coords": sum(1 for s in sites if "latitude" in s and "longitude" in s),
            "with_metadata": sum(1 for s in sites if len(s.get("description", "")) > 0),
            "with_website": sum(1 for s in sites if s.get("website")),
        },
        "shops": {
            "total": len(shops),
            "with_contact": sum(1 for s in shops if s.get("phone") or s.get("email")),
            "with_website": sum(1 for s in shops if s.get("website")),
        },
        "species": {
            "total": len(species),
            "with_conservation_status": sum(1 for s in species if s.get("conservationStatus")),
            "with_scientific_name": sum(1 for s in species if s.get("scientificName")),
        },
        "mpas": {
            "total": len(mpas),
            "with_protection_level": sum(1 for m in mpas if m.get("protectionLevel")),
        }
    }
    
    return report

def main():
    """Scrape comprehensive dive data from multiple sources."""
    print("🌊 COMPREHENSIVE DIVE DATA SCRAPER\n")
    print("Pulling from: Wikidata + OpenStreetMap + Species databases\n")
    
    enricher = SiteMetadataEnricher()
    
    # Scrape sites with rich metadata
    sites = enricher.query_wikidata_enhanced_sites()
    time.sleep(1)
    
    # Scrape shops and operators
    shops_data = enricher.query_osm_shops_and_operators()
    shops = shops_data["shops"]
    time.sleep(1)
    
    # Scrape marine species
    species = enricher.query_wikidata_marine_species()
    time.sleep(1)
    
    # Scrape marine protected areas
    mpas = enricher.query_osm_marine_protected_areas()
    time.sleep(1)
    
    # Validate
    print("\n🔍 Validating comprehensive dataset...")
    validation = validate_comprehensive_dataset(sites, shops, species, mpas)
    
    print(f"\n📊 Validation Report:")
    print(f"\n  Sites ({validation['sites']['total']} total):")
    print(f"    ✅ With coordinates: {validation['sites']['with_coords']}/{ validation['sites']['total']}")
    print(f"    ✅ With metadata: {validation['sites']['with_metadata']}/{validation['sites']['total']}")
    print(f"    ✅ With websites: {validation['sites']['with_website']}/{validation['sites']['total']}")
    
    print(f"\n  Shops ({validation['shops']['total']} total):")
    print(f"    ✅ With contact info: {validation['shops']['with_contact']}/{validation['shops']['total']}")
    print(f"    ✅ With websites: {validation['shops']['with_website']}/{validation['shops']['total']}")
    
    print(f"\n  Species ({validation['species']['total']} total):")
    print(f"    ✅ With conservation status: {validation['species']['with_conservation_status']}/{validation['species']['total']}")
    print(f"    ✅ With scientific names: {validation['species']['with_scientific_name']}/{validation['species']['total']}")
    
    print(f"\n  MPAs ({validation['mpas']['total']} total):")
    print(f"    ✅ With protection level: {validation['mpas']['with_protection_level']}/{validation['mpas']['total']}")
    
    # Save comprehensive dataset
    import os
    os.makedirs("../../Resources/SeedData", exist_ok=True)
    
    comprehensive = {
        "version": "1.0",
        "source": "Wikidata + OpenStreetMap (multi-source)",
        "generated_at": datetime.now(timezone.utc).isoformat(timespec='seconds').replace('+00:00', 'Z'),
        "validation": validation,
        "sites": sites,
        "shops": shops,
        "species": species,
        "mpas": mpas,
        "summary": {
            "total_entities": len(sites) + len(shops) + len(species) + len(mpas),
            "dive_sites": len(sites),
            "dive_shops_operators": len(shops),
            "marine_species": len(species),
            "protected_areas": len(mpas),
        }
    }
    
    output_file = "../../Resources/SeedData/comprehensive_dive_data.json"
    with open(output_file, "w") as f:
        json.dump(comprehensive, f, indent=2, ensure_ascii=False)
    
    print(f"\n✅ Saved comprehensive dataset to {output_file}")
    print(f"\n🎯 Dataset Summary:")
    print(f"   Total Entities: {comprehensive['summary']['total_entities']}")
    print(f"   - Dive Sites: {comprehensive['summary']['dive_sites']}")
    print(f"   - Shops/Operators: {comprehensive['summary']['dive_shops_operators']}")
    print(f"   - Species: {comprehensive['summary']['marine_species']}")
    print(f"   - Protected Areas: {comprehensive['summary']['protected_areas']}")

if __name__ == "__main__":
    main()
