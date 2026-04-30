#!/usr/bin/env python3
"""
Generate Resources/SeedData/canonical_site_list.json from compact site definitions.

Site tuples: (name, type, difficulty, [tags], [collections])
  - type:       Reef | Wall | Wreck | Cave | Drift | Shore | Other
  - difficulty: Beginner | Intermediate | Advanced
  - tags:       optional list of tag strings
  - collections: big-animals | macro-muck | wreck-capitals | beginner-friendly |
                 advanced-challenges | liveaboard | caves-cenotes | cold-water
If only a string is provided, region defaults apply.
"""

from __future__ import annotations
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUTPUT_PATH = ROOT / "Resources" / "SeedData" / "canonical_site_list.json"


def slugify(text: str) -> str:
    return re.sub(r"-+", "-", re.sub(r"[^a-z0-9]+", "-", text.lower())).strip("-")


def expand_sites(region: dict, raw_sites: list) -> list[dict]:
    d = region.get("defaults", {})
    out = []
    for s in raw_sites:
        if isinstance(s, str):
            name, stype, diff, tags, cols = s, None, None, [], []
        elif len(s) == 2:
            name, stype = s; diff, tags, cols = None, [], []
        elif len(s) == 3:
            name, stype, diff = s; tags, cols = [], []
        elif len(s) == 4:
            name, stype, diff, tags = s; cols = []
        else:
            name, stype, diff, tags, cols = s
        out.append({
            "name": name,
            "latitude": None,
            "longitude": None,
            "type": stype or d.get("type", "Reef"),
            "difficulty": diff or d.get("difficulty", "Intermediate"),
            "maxDepth": d.get("maxDepth"),
            "averageDepth": d.get("averageDepth"),
            "averageTemp": d.get("averageTemp"),
            "averageVisibility": d.get("averageVisibility"),
            "tags": tags,
            "curation_score": d.get("curation_score", 8.5),
            "popularity_score": d.get("popularity_score", 8.2),
            "required_cert": d.get("required_cert"),
            "access_level": d.get("access_level", "boat"),
            "collections": cols,
            "aliases": [],
            "description": "",
            "user_quotes": [],
        })
    return out


# ─────────────────────────────────────────────────────────────────────────────
# REGION GROUPS
# Each region: id, name, country_id, country, lat, lon, tagline, best_season,
#              bounds{min_lat,max_lat,min_lon,max_lon}, defaults{}, _sites[]
# ─────────────────────────────────────────────────────────────────────────────

REGION_GROUPS: list[dict] = [

    # =========================================================================
    # 1. CORAL TRIANGLE
    # =========================================================================
    {
        "id": "coral-triangle",
        "name": "Coral Triangle",
        "tagline": "The Amazon of the Seas",
        "description": "",
        "sort_order": 1,
        "regions": [
            {
                "id": "raja-ampat",
                "name": "Raja Ampat",
                "country_id": "ID", "country": "Indonesia",
                "latitude": -0.5, "longitude": 130.5,
                "bounds": {"min_lat": -2.5, "max_lat": 1.0, "min_lon": 129.5, "max_lon": 132.0},
                "tagline": "Earth's richest marine biodiversity",
                "best_season": "October–April",
                "defaults": {
                    "averageDepth": 14.0, "maxDepth": 28.0, "averageTemp": 28.0,
                    "averageVisibility": 18.0, "difficulty": "Intermediate",
                    "curation_score": 9.3, "popularity_score": 9.0, "access_level": "boat",
                },
                "_sites": [
                    ("Cape Kri", "Reef", "Intermediate", ["schooling fish", "biodiversity", "current"], ["big-animals"]),
                    ("Blue Magic", "Drift", "Advanced", ["manta rays", "current", "pelagic"], ["big-animals", "advanced-challenges"]),
                    ("Manta Sandy", "Reef", "Beginner", ["manta rays", "sandy bottom"], ["big-animals", "beginner-friendly"]),
                    ("Chicken Reef", "Reef", "Beginner", ["schooling fish", "beginners"], ["beginner-friendly"]),
                    ("Sardine Reef", "Reef", "Beginner", ["schooling fish", "shallow"], ["beginner-friendly"]),
                    ("Melissa's Garden", "Reef", "Beginner", ["coral garden", "macro"], ["beginner-friendly"]),
                    ("Mike's Point", "Wall", "Intermediate", ["wall", "current", "schooling fish"], []),
                    ("Mioskon", "Reef", "Intermediate", ["soft coral", "current"], []),
                    ("Friwen Wall", "Wall", "Intermediate", ["wall", "pygmy seahorse"], ["macro-muck"]),
                    ("The Passage", "Drift", "Intermediate", ["channel", "current", "mangrove"], ["advanced-challenges"]),
                    ("Citrus Ridge", "Reef", "Intermediate", ["hard coral", "fish diversity"], []),
                    ("Arborek Jetty", "Shore", "Beginner", ["jetty", "macro", "pygmy seahorse"], ["macro-muck", "beginner-friendly"]),
                    ("Sawandarek Jetty", "Shore", "Beginner", ["jetty", "macro"], ["macro-muck", "beginner-friendly"]),
                    ("Yenbuba Jetty", "Shore", "Beginner", ["jetty", "macro", "night diving"], ["macro-muck"]),
                    ("Otdima Reef", "Reef", "Intermediate", ["soft coral", "fish"], []),
                    ("Magic Mountain", "Reef", "Intermediate", ["manta rays", "cleaning station"], ["big-animals"]),
                    ("Boo Windows", "Wall", "Intermediate", ["archway", "wall", "current"], []),
                    ("Nudi Rock", "Reef", "Beginner", ["nudibranchs", "macro"], ["macro-muck"]),
                    ("Whale Rock", "Wall", "Intermediate", ["wall", "pelagic"], []),
                    ("Farondi Caves", "Cave", "Advanced", ["cave", "cavern"], ["caves-cenotes"]),
                    ("Eagle Rock", "Reef", "Intermediate", ["eagle rays", "current"], ["big-animals"]),
                    ("Mayhem", "Drift", "Advanced", ["strong current", "pelagic"], ["advanced-challenges"]),
                    ("Fam Wall", "Wall", "Intermediate", ["wall", "soft coral"], []),
                    ("Four Kings", "Reef", "Advanced", ["current", "schooling fish", "pelagic"], ["advanced-challenges"]),
                    ("Cross Wreck", "Wreck", "Intermediate", ["wreck", "coral growth"], ["wreck-capitals"]),
                    ("Cape Mansuar", "Wall", "Intermediate", ["wall", "current"], []),
                    ("Batu Lima", "Reef", "Intermediate", ["coral", "fish"], []),
                ],
            },
            {
                "id": "komodo-national-park",
                "name": "Komodo National Park",
                "country_id": "ID", "country": "Indonesia",
                "latitude": -8.55, "longitude": 119.62,
                "bounds": {"min_lat": -8.78, "max_lat": -8.3, "min_lon": 119.3, "max_lon": 119.9},
                "tagline": "Dragons above, mantas below",
                "best_season": "April–November",
                "defaults": {
                    "averageDepth": 16.0, "maxDepth": 30.0, "averageTemp": 26.0,
                    "averageVisibility": 16.0, "difficulty": "Advanced",
                    "curation_score": 9.4, "popularity_score": 9.2, "access_level": "boat",
                },
                "_sites": [
                    ("Batu Bolong", "Reef", "Advanced", ["pinnacle", "current", "pelagic"], ["big-animals", "advanced-challenges"]),
                    ("Castle Rock", "Reef", "Advanced", ["current", "schooling fish", "sharks"], ["big-animals", "advanced-challenges"]),
                    ("Crystal Rock", "Reef", "Advanced", ["current", "manta rays"], ["big-animals", "advanced-challenges"]),
                    ("The Cauldron", "Drift", "Advanced", ["strong current", "funnel"], ["advanced-challenges"]),
                    ("Manta Alley", "Reef", "Intermediate", ["manta rays", "cleaning station"], ["big-animals"]),
                    ("Mawan", "Reef", "Intermediate", ["soft coral", "fish"], []),
                    ("Siaba Besar", "Reef", "Beginner", ["turtles", "reef fish"], ["beginner-friendly"]),
                    ("Siaba Kecil", "Reef", "Beginner", ["turtles", "coral"], ["beginner-friendly"]),
                    ("Tatawa Besar", "Reef", "Intermediate", ["hard coral", "current"], []),
                    ("Tatawa Kecil", "Reef", "Intermediate", ["coral", "reef fish"], []),
                    ("Batu Tiga", "Reef", "Advanced", ["current", "pelagic"], ["advanced-challenges"]),
                    ("Cannibal Rock", "Reef", "Intermediate", ["macro", "nudibranchs", "seahorse"], ["macro-muck"]),
                    ("Yellow Wall of Texas", "Wall", "Intermediate", ["yellow coral", "wall"], []),
                    ("Torpedo Alley", "Drift", "Advanced", ["current", "sharks"], ["big-animals", "advanced-challenges"]),
                    ("Pink Beach", "Reef", "Beginner", ["pink sand", "coral garden", "turtles"], ["beginner-friendly"]),
                    ("Karang Makassar", "Reef", "Intermediate", ["manta rays"], ["big-animals"]),
                    ("Police Corner", "Wall", "Intermediate", ["wall", "soft coral"], []),
                    ("Bonsai Rock", "Reef", "Intermediate", ["coral", "reef fish"], []),
                    ("Loh Namu", "Reef", "Beginner", ["mangrove", "macro"], ["beginner-friendly"]),
                ],
            },
            {
                "id": "bali-nusa-islands",
                "name": "Bali & Nusa Islands",
                "country_id": "ID", "country": "Indonesia",
                "latitude": -8.5, "longitude": 115.2,
                "bounds": {"min_lat": -8.9, "max_lat": -8.1, "min_lon": 114.5, "max_lon": 115.7},
                "tagline": "Wreck dives and manta magic",
                "best_season": "April–October",
                "defaults": {
                    "averageDepth": 15.0, "maxDepth": 28.0, "averageTemp": 27.0,
                    "averageVisibility": 18.0, "difficulty": "Intermediate",
                    "curation_score": 9.2, "popularity_score": 9.0, "access_level": "boat",
                },
                "_sites": [
                    ("USAT Liberty Wreck", "Wreck", "Beginner", ["famous wreck", "shore entry", "coral growth"], ["wreck-capitals", "beginner-friendly"]),
                    ("Drop Off Tulamben", "Wall", "Intermediate", ["wall", "current"], []),
                    ("Coral Garden Tulamben", "Reef", "Beginner", ["coral garden", "macro"], ["beginner-friendly"]),
                    ("Seraya Secrets", "Shore", "Beginner", ["muck", "macro", "nudibranch"], ["macro-muck", "beginner-friendly"]),
                    ("Boga Wreck", "Wreck", "Intermediate", ["wreck", "coral growth"], ["wreck-capitals"]),
                    ("Crystal Bay", "Reef", "Advanced", ["mola mola", "current", "pelagic"], ["big-animals", "advanced-challenges"]),
                    ("Manta Point Nusa Penida", "Reef", "Intermediate", ["manta rays", "cleaning station"], ["big-animals"]),
                    ("Toyapakeh", "Drift", "Advanced", ["current", "schooling fish"], ["advanced-challenges"]),
                    ("SD Point", "Reef", "Intermediate", ["coral", "fish"], []),
                    ("Blue Corner Nusa Lembongan", "Wall", "Intermediate", ["wall", "current"], []),
                    ("Mangrove Point", "Shore", "Beginner", ["macro", "mangrove"], ["beginner-friendly"]),
                    ("Ped", "Reef", "Intermediate", ["reef", "fish"], []),
                    ("Gamat Bay", "Reef", "Beginner", ["coral garden", "turtles"], ["beginner-friendly"]),
                    ("Ceningan Wall", "Wall", "Advanced", ["wall", "current"], ["advanced-challenges"]),
                    ("Secret Bay Gilimanuk", "Shore", "Beginner", ["muck", "rare critters", "macro"], ["macro-muck", "beginner-friendly"]),
                    ("Menjangan Wall", "Wall", "Beginner", ["wall", "coral", "turtles"], ["beginner-friendly"]),
                    ("Eel Garden", "Reef", "Beginner", ["garden eels", "sandy", "macro"], ["beginner-friendly"]),
                    ("Puri Jati", "Shore", "Beginner", ["muck", "macro", "seahorse"], ["macro-muck", "beginner-friendly"]),
                    ("Jemeluk Bay", "Reef", "Beginner", ["coral", "fish"], ["beginner-friendly"]),
                ],
            },
            {
                "id": "lembeh-strait",
                "name": "Lembeh Strait",
                "country_id": "ID", "country": "Indonesia",
                "latitude": 1.47, "longitude": 125.24,
                "bounds": {"min_lat": 1.3, "max_lat": 1.7, "min_lon": 125.1, "max_lon": 125.4},
                "tagline": "Macro and muck diving capital of the world",
                "best_season": "Year-round",
                "defaults": {
                    "averageDepth": 12.0, "maxDepth": 25.0, "averageTemp": 27.0,
                    "averageVisibility": 8.0, "difficulty": "Beginner",
                    "curation_score": 9.3, "popularity_score": 9.0, "access_level": "boat",
                },
                "_sites": [
                    ("Hairball", "Shore", "Beginner", ["muck", "rare critters", "frogfish"], ["macro-muck"]),
                    ("Nudi Falls", "Shore", "Beginner", ["nudibranchs", "macro"], ["macro-muck"]),
                    ("Police Pier", "Shore", "Beginner", ["jetty", "macro", "night diving"], ["macro-muck"]),
                    ("Aer Bajo", "Shore", "Beginner", ["muck", "macro"], ["macro-muck"]),
                    ("TK", "Shore", "Beginner", ["muck", "mimics", "rare critters"], ["macro-muck"]),
                    ("Jahir", "Shore", "Beginner", ["muck", "frogfish", "ghost pipefish"], ["macro-muck"]),
                    ("Critter Hunt", "Shore", "Beginner", ["muck", "seahorse", "macro"], ["macro-muck"]),
                    ("Angel's Window", "Cave", "Intermediate", ["cave", "cavern", "macro"], ["caves-cenotes"]),
                    ("California Dreaming", "Shore", "Beginner", ["muck", "macro"], ["macro-muck"]),
                    ("Makawide", "Shore", "Beginner", ["muck", "wunderpus"], ["macro-muck"]),
                    ("Serena Besar", "Shore", "Beginner", ["muck", "macro"], ["macro-muck"]),
                    ("Batu Sandar", "Shore", "Beginner", ["muck", "coral", "macro"], ["macro-muck"]),
                    ("Retak Larry", "Shore", "Beginner", ["muck", "rare critters"], ["macro-muck"]),
                    ("Magic Rock", "Shore", "Beginner", ["muck", "seahorse", "frogfish"], ["macro-muck"]),
                    ("Batu Kapal", "Reef", "Intermediate", ["reef", "macro"], ["macro-muck"]),
                    ("Mawali Wreck", "Wreck", "Intermediate", ["wreck", "macro", "coral growth"], ["wreck-capitals", "macro-muck"]),
                    ("Bianca", "Shore", "Beginner", ["muck", "macro"], ["macro-muck"]),
                    ("Kapal Indah", "Shore", "Beginner", ["muck", "macro", "nudibranch"], ["macro-muck"]),
                ],
            },
            {
                "id": "bunaken-sulawesi",
                "name": "Bunaken & Bangka, Sulawesi",
                "country_id": "ID", "country": "Indonesia",
                "latitude": 1.6, "longitude": 124.8,
                "bounds": {"min_lat": 1.3, "max_lat": 2.0, "min_lon": 124.5, "max_lon": 125.2},
                "tagline": "World-class walls and reef biodiversity",
                "best_season": "May–October",
                "defaults": {
                    "averageDepth": 18.0, "maxDepth": 40.0, "averageTemp": 28.0,
                    "averageVisibility": 20.0, "difficulty": "Intermediate",
                    "curation_score": 9.1, "popularity_score": 8.8, "access_level": "boat",
                },
                "_sites": [
                    ("Lekuan I", "Wall", "Intermediate", ["wall", "current", "fish"], []),
                    ("Lekuan II", "Wall", "Intermediate", ["wall", "biodiversity"], []),
                    ("Lekuan III", "Wall", "Intermediate", ["wall", "macro"], []),
                    ("Fukui Point", "Wall", "Intermediate", ["wall", "turtles"], []),
                    ("Sachiko's Point", "Wall", "Intermediate", ["wall", "soft coral"], []),
                    ("Mike's Point Bunaken", "Reef", "Intermediate", ["reef", "current", "fish"], []),
                    ("Mandolin", "Wall", "Intermediate", ["wall", "schooling fish"], []),
                    ("Celah Celah", "Cave", "Intermediate", ["cavern", "wall"], ["caves-cenotes"]),
                    ("Muka Kampung", "Wall", "Beginner", ["wall", "turtles"], ["beginner-friendly"]),
                    ("Alung Banua", "Wall", "Intermediate", ["wall", "fish diversity"], []),
                    ("Tanjung Kopi", "Reef", "Intermediate", ["reef", "macro"], []),
                    ("Siladen Wall", "Wall", "Intermediate", ["wall", "coral"], []),
                    ("Bangka Pinnacle", "Reef", "Advanced", ["pinnacle", "current", "macro"], ["advanced-challenges"]),
                ],
            },
            {
                "id": "alor-strait",
                "name": "Alor Strait",
                "country_id": "ID", "country": "Indonesia",
                "latitude": -8.27, "longitude": 124.5,
                "bounds": {"min_lat": -8.6, "max_lat": -7.9, "min_lon": 124.0, "max_lon": 125.0},
                "tagline": "Remote walls and volcanic reefs",
                "best_season": "April–November",
                "defaults": {
                    "averageDepth": 18.0, "maxDepth": 35.0, "averageTemp": 26.0,
                    "averageVisibility": 20.0, "difficulty": "Advanced",
                    "curation_score": 9.0, "popularity_score": 8.6, "access_level": "boat",
                },
                "_sites": [
                    ("The Cathedral", "Cave", "Advanced", ["cavern", "coral", "fish"], ["caves-cenotes"]),
                    ("The Arch", "Cave", "Advanced", ["arch", "current"], ["caves-cenotes"]),
                    ("Anemone City", "Reef", "Intermediate", ["anemonefish", "macro"], ["macro-muck"]),
                    ("Kal's Dream", "Reef", "Intermediate", ["coral", "biodiversity"], []),
                    ("Babylon", "Wall", "Intermediate", ["wall", "soft coral"], []),
                    ("Clown Valley", "Reef", "Beginner", ["clownfish", "macro"], ["beginner-friendly"]),
                    ("Sharks Galore", "Reef", "Advanced", ["sharks", "current"], ["big-animals", "advanced-challenges"]),
                    ("The Edge", "Wall", "Advanced", ["wall", "deep", "pelagic"], ["advanced-challenges"]),
                    ("Mucky Mosque", "Shore", "Beginner", ["muck", "macro"], ["macro-muck"]),
                    ("Pertamina Jetty", "Shore", "Beginner", ["jetty", "macro", "night diving"], ["macro-muck"]),
                    ("The Bullet", "Drift", "Advanced", ["strong current", "pelagic"], ["advanced-challenges"]),
                    ("Razorback", "Reef", "Advanced", ["current", "schooling fish"], ["advanced-challenges"]),
                    ("Great Wall of Pantar", "Wall", "Intermediate", ["wall", "coral"], []),
                ],
            },
            {
                "id": "banda-sea",
                "name": "Banda Sea",
                "country_id": "ID", "country": "Indonesia",
                "latitude": -5.5, "longitude": 128.0,
                "bounds": {"min_lat": -8.0, "max_lat": -3.0, "min_lon": 126.0, "max_lon": 132.0},
                "tagline": "Remote liveaboard circuit of spice islands",
                "best_season": "October–April",
                "defaults": {
                    "averageDepth": 18.0, "maxDepth": 40.0, "averageTemp": 28.0,
                    "averageVisibility": 25.0, "difficulty": "Intermediate",
                    "curation_score": 9.0, "popularity_score": 8.5, "access_level": "boat",
                    "required_cert": "Advanced",
                },
                "_sites": [
                    ("Manuk Island", "Reef", "Intermediate", ["sea snakes", "pelagic", "remote"], ["big-animals", "liveaboard"]),
                    ("Hatta Island", "Wall", "Intermediate", ["wall", "soft coral"], ["liveaboard"]),
                    ("Ai Island", "Reef", "Intermediate", ["reef", "fish"], ["liveaboard"]),
                    ("Run Island", "Reef", "Intermediate", ["historical", "reef"], ["liveaboard"]),
                    ("Batu Kapal Banda", "Reef", "Advanced", ["current", "pelagic"], ["advanced-challenges", "liveaboard"]),
                    ("Lava Flow", "Reef", "Intermediate", ["volcanic", "unique terrain"], ["liveaboard"]),
                    ("Batu Belanda", "Wall", "Intermediate", ["wall", "soft coral"], ["liveaboard"]),
                    ("Nil Desperandum", "Reef", "Advanced", ["current", "schooling fish"], ["advanced-challenges", "liveaboard"]),
                    ("Suanggi Island", "Reef", "Intermediate", ["remote", "reef", "fish"], ["liveaboard"]),
                    ("Mandarin City", "Shore", "Beginner", ["mandarin fish", "macro", "night diving"], ["macro-muck"]),
                ],
            },
            {
                "id": "ambon",
                "name": "Ambon",
                "country_id": "ID", "country": "Indonesia",
                "latitude": -3.7, "longitude": 128.2,
                "bounds": {"min_lat": -4.0, "max_lat": -3.4, "min_lon": 128.0, "max_lon": 128.6},
                "tagline": "Bobtail squid and rare critters",
                "best_season": "October–April",
                "defaults": {
                    "averageDepth": 12.0, "maxDepth": 25.0, "averageTemp": 27.0,
                    "averageVisibility": 8.0, "difficulty": "Beginner",
                    "curation_score": 8.9, "popularity_score": 8.4, "access_level": "boat",
                },
                "_sites": [
                    ("Twilight Zone", "Shore", "Intermediate", ["muck", "bobtail squid", "macro"], ["macro-muck"]),
                    ("Laha 1", "Shore", "Beginner", ["muck", "macro", "nudibranch"], ["macro-muck"]),
                    ("Laha 2", "Shore", "Beginner", ["muck", "macro"], ["macro-muck"]),
                    ("Laha 3", "Shore", "Beginner", ["muck", "rare critters"], ["macro-muck"]),
                    ("Rhino City", "Shore", "Beginner", ["rhinopias", "muck", "macro"], ["macro-muck"]),
                    ("Duke of Sparta Wreck", "Wreck", "Intermediate", ["wreck", "WWII", "coral growth"], ["wreck-capitals"]),
                    ("Pintu Kota", "Cave", "Advanced", ["cavern", "cathedral"], ["caves-cenotes"]),
                    ("Hukurila Cave", "Cave", "Advanced", ["cave", "swim-through"], ["caves-cenotes"]),
                    ("Seri", "Shore", "Beginner", ["muck", "macro"], ["macro-muck"]),
                ],
            },
            {
                "id": "gili-islands-lombok",
                "name": "Gili Islands & Lombok",
                "country_id": "ID", "country": "Indonesia",
                "latitude": -8.35, "longitude": 116.05,
                "bounds": {"min_lat": -8.6, "max_lat": -8.1, "min_lon": 115.7, "max_lon": 116.5},
                "tagline": "Turtles, wrecks and volcano views",
                "best_season": "May–October",
                "defaults": {
                    "averageDepth": 15.0, "maxDepth": 28.0, "averageTemp": 28.0,
                    "averageVisibility": 18.0, "difficulty": "Intermediate",
                    "curation_score": 8.8, "popularity_score": 8.8, "access_level": "boat",
                },
                "_sites": [
                    ("Shark Point Gili", "Reef", "Intermediate", ["reef sharks", "turtles"], ["big-animals"]),
                    ("Turtle Heaven", "Reef", "Beginner", ["turtles", "coral", "reef fish"], ["beginner-friendly", "big-animals"]),
                    ("Meno Wall", "Wall", "Intermediate", ["wall", "turtles"], []),
                    ("Halik", "Reef", "Intermediate", ["coral", "fish diversity"], []),
                    ("Deep Turbo", "Reef", "Advanced", ["current", "pelagic"], ["advanced-challenges"]),
                    ("Simon's Reef", "Reef", "Beginner", ["coral", "fish"], ["beginner-friendly"]),
                    ("Hans Reef", "Reef", "Beginner", ["coral garden", "turtles"], ["beginner-friendly"]),
                    ("Bounty Wreck", "Wreck", "Intermediate", ["wreck", "coral growth"], ["wreck-capitals"]),
                    ("Bio Rocks", "Reef", "Beginner", ["biorock", "turtles", "coral restoration"], ["beginner-friendly"]),
                    ("Sunset Reef", "Reef", "Beginner", ["coral", "fish", "turtles"], ["beginner-friendly"]),
                    ("Belongas Bay", "Reef", "Advanced", ["hammerhead sharks", "current"], ["big-animals", "advanced-challenges"]),
                    ("The Magnet", "Reef", "Advanced", ["sharks", "current"], ["big-animals", "advanced-challenges"]),
                    ("Gili Sarang", "Reef", "Intermediate", ["remote", "coral"], []),
                ],
            },
        ],
    },

    # =========================================================================
    # 2. PHILIPPINES
    # =========================================================================
    {
        "id": "philippines",
        "name": "Philippines",
        "tagline": "8,000 islands, infinite dive sites",
        "description": "",
        "sort_order": 2,
        "regions": [
            {
                "id": "tubbataha-reefs",
                "name": "Tubbataha Reefs",
                "country_id": "PH", "country": "Philippines",
                "latitude": 8.9, "longitude": 119.9,
                "bounds": {"min_lat": 8.5, "max_lat": 9.5, "min_lon": 119.5, "max_lon": 120.3},
                "tagline": "UNESCO world heritage, sharks and pristine walls",
                "best_season": "March–June",
                "defaults": {
                    "averageDepth": 20.0, "maxDepth": 40.0, "averageTemp": 28.0,
                    "averageVisibility": 30.0, "difficulty": "Advanced",
                    "curation_score": 9.5, "popularity_score": 9.0, "access_level": "boat",
                    "required_cert": "Advanced",
                },
                "_sites": [
                    ("Jessie Beazley Reef", "Reef", "Advanced", ["sharks", "pelagic", "pristine"], ["big-animals", "liveaboard"]),
                    ("Amos Rock", "Reef", "Advanced", ["current", "pelagic"], ["liveaboard"]),
                    ("Shark Airport", "Reef", "Advanced", ["whitetip sharks", "grey reef sharks"], ["big-animals", "liveaboard"]),
                    ("Washing Machine", "Drift", "Advanced", ["strong current", "thrilling"], ["advanced-challenges", "liveaboard"]),
                    ("Malayan Wreck", "Wreck", "Intermediate", ["wreck", "coral growth"], ["wreck-capitals", "liveaboard"]),
                    ("Black Rock", "Reef", "Advanced", ["current", "schooling fish"], ["liveaboard"]),
                    ("Delsan Wreck", "Wreck", "Intermediate", ["wreck"], ["wreck-capitals", "liveaboard"]),
                    ("Seafan Alley", "Reef", "Intermediate", ["seafans", "coral"], ["liveaboard"]),
                    ("South Atoll Wall", "Wall", "Advanced", ["wall", "pelagic"], ["liveaboard"]),
                ],
            },
            {
                "id": "anilao-batangas",
                "name": "Anilao & Batangas",
                "country_id": "PH", "country": "Philippines",
                "latitude": 13.7, "longitude": 120.87,
                "bounds": {"min_lat": 13.4, "max_lat": 14.0, "min_lon": 120.5, "max_lon": 121.2},
                "tagline": "Nudibranch capital and blackwater diving",
                "best_season": "October–May",
                "defaults": {
                    "averageDepth": 12.0, "maxDepth": 25.0, "averageTemp": 27.0,
                    "averageVisibility": 12.0, "difficulty": "Intermediate",
                    "curation_score": 9.0, "popularity_score": 8.8, "access_level": "boat",
                },
                "_sites": [
                    ("Secret Bay Anilao", "Shore", "Beginner", ["muck", "nudibranch", "ghost pipefish"], ["macro-muck", "beginner-friendly"]),
                    ("Cathedral Rock", "Reef", "Intermediate", ["coral", "fish", "macro"], []),
                    ("Twin Rocks", "Reef", "Intermediate", ["schooling fish", "current"], []),
                    ("Beatrice Rock", "Reef", "Intermediate", ["coral", "fish diversity"], []),
                    ("Sombrero Island", "Reef", "Intermediate", ["pelagic", "schooling fish"], []),
                    ("Kirby's Rock", "Reef", "Intermediate", ["macro", "critters"], ["macro-muck"]),
                    ("Mainit Point", "Reef", "Advanced", ["current", "hot springs", "unique"], ["advanced-challenges"]),
                    ("Sepoc Wall", "Wall", "Intermediate", ["wall", "soft coral"], []),
                    ("Koala", "Shore", "Beginner", ["muck", "macro", "frogfish"], ["macro-muck"]),
                    ("Ligpo Island", "Reef", "Intermediate", ["reef", "fish"], []),
                    ("Arthur's Rock", "Reef", "Intermediate", ["reef", "macro"], []),
                    ("Bethlehem", "Reef", "Intermediate", ["nudibranchs", "macro"], ["macro-muck"]),
                    ("Red Rock", "Reef", "Intermediate", ["red coral", "macro"], []),
                    ("Manit Muck", "Shore", "Beginner", ["muck", "macro"], ["macro-muck"]),
                    ("Bonito Island", "Reef", "Intermediate", ["tuna", "schooling fish"], ["big-animals"]),
                ],
            },
            {
                "id": "malapascua",
                "name": "Malapascua",
                "country_id": "PH", "country": "Philippines",
                "latitude": 11.33, "longitude": 124.12,
                "bounds": {"min_lat": 11.1, "max_lat": 11.6, "min_lon": 123.9, "max_lon": 124.4},
                "tagline": "The only place to reliably dive thresher sharks",
                "best_season": "October–May",
                "defaults": {
                    "averageDepth": 22.0, "maxDepth": 35.0, "averageTemp": 28.0,
                    "averageVisibility": 20.0, "difficulty": "Intermediate",
                    "curation_score": 9.3, "popularity_score": 9.2, "access_level": "boat",
                },
                "_sites": [
                    ("Monad Shoal", "Reef", "Intermediate", ["thresher sharks", "cleaning station", "early morning"], ["big-animals"]),
                    ("Kimud Shoal", "Reef", "Intermediate", ["thresher sharks", "manta rays"], ["big-animals"]),
                    ("Gato Island", "Cave", "Intermediate", ["cave", "white-tip sharks", "macro"], ["caves-cenotes", "big-animals"]),
                    ("Lapus Lapus", "Reef", "Intermediate", ["reef", "fish diversity"], []),
                    ("Deep Rock", "Reef", "Advanced", ["deep", "thresher sharks"], ["big-animals", "advanced-challenges"]),
                    ("Chocolate Island", "Reef", "Beginner", ["coral", "reef fish"], ["beginner-friendly"]),
                    ("Lighthouse", "Reef", "Beginner", ["coral", "fish"], ["beginner-friendly"]),
                    ("North Wall", "Wall", "Intermediate", ["wall", "coral"], []),
                    ("Bugtong Bato", "Reef", "Intermediate", ["reef", "macro"], []),
                    ("Bantigue", "Reef", "Beginner", ["reef", "turtles"], ["beginner-friendly"]),
                ],
            },
            {
                "id": "cebu-moalboal-mactan",
                "name": "Cebu, Moalboal & Mactan",
                "country_id": "PH", "country": "Philippines",
                "latitude": 9.95, "longitude": 123.4,
                "bounds": {"min_lat": 9.5, "max_lat": 10.5, "min_lon": 123.0, "max_lon": 124.0},
                "tagline": "The sardine run and tropical reefs",
                "best_season": "Year-round",
                "defaults": {
                    "averageDepth": 15.0, "maxDepth": 30.0, "averageTemp": 28.0,
                    "averageVisibility": 18.0, "difficulty": "Beginner",
                    "curation_score": 8.9, "popularity_score": 9.0, "access_level": "boat",
                },
                "_sites": [
                    ("Panagsama Reef", "Reef", "Beginner", ["shore diving", "reef fish"], ["beginner-friendly"]),
                    ("Pescador Island", "Wall", "Intermediate", ["wall", "schooling fish", "turtles"], []),
                    ("Sardine Run Moalboal", "Reef", "Beginner", ["sardine ball", "unique spectacle"], ["big-animals", "beginner-friendly"]),
                    ("Kasai Wall", "Wall", "Intermediate", ["wall", "soft coral"], []),
                    ("White Beach Moalboal", "Reef", "Beginner", ["coral garden", "turtles"], ["beginner-friendly"]),
                    ("Airplane Wreck Mactan", "Wreck", "Beginner", ["wreck", "shallow"], ["wreck-capitals", "beginner-friendly"]),
                    ("Marigondon Cave", "Cave", "Advanced", ["cave", "cavern"], ["caves-cenotes", "advanced-challenges"]),
                    ("Hilutungan Island", "Reef", "Beginner", ["marine sanctuary", "turtles", "fish"], ["beginner-friendly"]),
                    ("Nalusuan Island", "Reef", "Beginner", ["coral garden", "reef fish"], ["beginner-friendly"]),
                    ("Tambuli", "Shore", "Beginner", ["shore entry", "coral", "macro"], ["beginner-friendly"]),
                    ("Agus Wall", "Wall", "Intermediate", ["wall", "fish"], []),
                ],
            },
            {
                "id": "bohol-panglao-balicasag",
                "name": "Bohol, Panglao & Balicasag",
                "country_id": "PH", "country": "Philippines",
                "latitude": 9.5, "longitude": 123.77,
                "bounds": {"min_lat": 9.2, "max_lat": 9.8, "min_lon": 123.5, "max_lon": 124.1},
                "tagline": "Wall dives, turtles and schools of jacks",
                "best_season": "October–May",
                "defaults": {
                    "averageDepth": 18.0, "maxDepth": 35.0, "averageTemp": 28.0,
                    "averageVisibility": 20.0, "difficulty": "Intermediate",
                    "curation_score": 9.1, "popularity_score": 8.9, "access_level": "boat",
                },
                "_sites": [
                    ("Balicasag Black Forest", "Wall", "Intermediate", ["black coral", "wall"], []),
                    ("Balicasag Cathedral", "Wall", "Intermediate", ["wall", "schooling fish", "turtles"], []),
                    ("Balicasag Diver's Heaven", "Wall", "Intermediate", ["wall", "pelagic"], []),
                    ("Balicasag Rudy's Rock", "Reef", "Intermediate", ["reef", "current"], []),
                    ("Doljo Point", "Reef", "Beginner", ["coral garden", "reef fish"], ["beginner-friendly"]),
                    ("Arco Point", "Reef", "Intermediate", ["arch", "coral", "fish"], []),
                    ("Napaling", "Reef", "Intermediate", ["coral", "fish"], []),
                    ("Kalipayan", "Reef", "Beginner", ["coral", "reef fish"], ["beginner-friendly"]),
                    ("Pamilacan Island", "Reef", "Intermediate", ["dolphins", "whale sharks seasonal", "reef"], ["big-animals"]),
                    ("Cabilao Lighthouse", "Reef", "Intermediate", ["hammerheads occasional", "current"], ["big-animals"]),
                    ("Gorgonian Wall", "Wall", "Intermediate", ["seafans", "wall", "soft coral"], []),
                    ("Snake Island Bohol", "Reef", "Beginner", ["reef", "fish"], ["beginner-friendly"]),
                ],
            },
            {
                "id": "puerto-galera",
                "name": "Puerto Galera",
                "country_id": "PH", "country": "Philippines",
                "latitude": 13.51, "longitude": 120.95,
                "bounds": {"min_lat": 13.3, "max_lat": 13.7, "min_lon": 120.7, "max_lon": 121.2},
                "tagline": "Easy access and world-class variety",
                "best_season": "October–June",
                "defaults": {
                    "averageDepth": 15.0, "maxDepth": 30.0, "averageTemp": 28.0,
                    "averageVisibility": 15.0, "difficulty": "Intermediate",
                    "curation_score": 8.9, "popularity_score": 8.8, "access_level": "boat",
                },
                "_sites": [
                    ("Canyons", "Drift", "Advanced", ["canyon", "strong current", "pelagic"], ["advanced-challenges"]),
                    ("Hole in the Wall", "Cave", "Intermediate", ["tunnel", "swim-through", "fish"], ["caves-cenotes"]),
                    ("Verde Island Drop Off", "Wall", "Advanced", ["wall", "current", "biodiversity"], ["advanced-challenges"]),
                    ("Sabang Wrecks", "Wreck", "Beginner", ["wrecks", "coral growth"], ["wreck-capitals", "beginner-friendly"]),
                    ("Alma Jane Wreck", "Wreck", "Intermediate", ["wreck", "lionfish"], ["wreck-capitals"]),
                    ("Monkey Beach", "Reef", "Beginner", ["coral", "fish"], ["beginner-friendly"]),
                    ("West Escarceo", "Drift", "Advanced", ["current", "sharks"], ["big-animals", "advanced-challenges"]),
                    ("Kilima Steps", "Reef", "Intermediate", ["steps", "coral", "macro"], []),
                    ("Shark Cave", "Cave", "Intermediate", ["sharks", "cavern"], ["big-animals", "caves-cenotes"]),
                    ("Sinandigan Wall", "Wall", "Intermediate", ["wall", "coral"], []),
                    ("Giant Clams", "Reef", "Beginner", ["giant clams", "reef fish"], ["beginner-friendly"]),
                    ("Coral Cove", "Reef", "Beginner", ["coral garden", "fish"], ["beginner-friendly"]),
                ],
            },
            {
                "id": "coron-busuanga",
                "name": "Coron & Busuanga",
                "country_id": "PH", "country": "Philippines",
                "latitude": 12.0, "longitude": 120.2,
                "bounds": {"min_lat": 11.7, "max_lat": 12.4, "min_lon": 119.7, "max_lon": 120.6},
                "tagline": "WWII Japanese fleet wreck graveyard",
                "best_season": "October–May",
                "defaults": {
                    "averageDepth": 22.0, "maxDepth": 40.0, "averageTemp": 28.0,
                    "averageVisibility": 15.0, "difficulty": "Intermediate",
                    "curation_score": 9.3, "popularity_score": 9.1, "access_level": "boat",
                },
                "_sites": [
                    ("Akitsushima", "Wreck", "Intermediate", ["WWII", "seaplane tender", "coral growth"], ["wreck-capitals"]),
                    ("Irako", "Wreck", "Advanced", ["WWII", "supply ship", "deep"], ["wreck-capitals", "advanced-challenges"]),
                    ("Olympia Maru", "Wreck", "Intermediate", ["WWII", "cargo ship"], ["wreck-capitals"]),
                    ("Kogyo Maru", "Wreck", "Intermediate", ["WWII", "cargo ship"], ["wreck-capitals"]),
                    ("Okikawa Maru", "Wreck", "Intermediate", ["WWII", "tanker", "shallow"], ["wreck-capitals"]),
                    ("Morazan Maru", "Wreck", "Beginner", ["WWII", "shallow", "coral growth"], ["wreck-capitals", "beginner-friendly"]),
                    ("Lusong Gunboat", "Wreck", "Beginner", ["WWII", "very shallow", "snorkelling"], ["wreck-capitals", "beginner-friendly"]),
                    ("East Tangat Wreck", "Wreck", "Intermediate", ["WWII", "wreck"], ["wreck-capitals"]),
                    ("Skeleton Wreck", "Wreck", "Intermediate", ["WWII", "wreck"], ["wreck-capitals"]),
                    ("Barracuda Lake", "Other", "Intermediate", ["thermocline", "unique", "freshwater-salt mix"], []),
                    ("Cathedral Cave Coron", "Cave", "Advanced", ["cave", "cavern"], ["caves-cenotes"]),
                    ("Siete Pecados", "Reef", "Beginner", ["reef", "fish", "coral"], ["beginner-friendly"]),
                ],
            },
            {
                "id": "dauin-apo-island",
                "name": "Dauin & Apo Island",
                "country_id": "PH", "country": "Philippines",
                "latitude": 9.1, "longitude": 123.28,
                "bounds": {"min_lat": 8.9, "max_lat": 9.4, "min_lon": 123.0, "max_lon": 123.6},
                "tagline": "Marine sanctuary turtles and muck critters",
                "best_season": "October–June",
                "defaults": {
                    "averageDepth": 14.0, "maxDepth": 28.0, "averageTemp": 28.0,
                    "averageVisibility": 15.0, "difficulty": "Intermediate",
                    "curation_score": 9.0, "popularity_score": 8.8, "access_level": "boat",
                },
                "_sites": [
                    ("Apo Island Chapel", "Reef", "Intermediate", ["turtles", "reef fish", "marine sanctuary"], ["big-animals"]),
                    ("Apo Island Coconut Point", "Reef", "Advanced", ["current", "sharks", "turtles"], ["big-animals", "advanced-challenges"]),
                    ("Apo Island Rock Point East", "Wall", "Intermediate", ["wall", "turtles"], []),
                    ("Apo Island Marine Sanctuary", "Reef", "Beginner", ["turtles", "reef fish"], ["beginner-friendly", "big-animals"]),
                    ("Dauin North", "Shore", "Beginner", ["muck", "macro", "nudibranch"], ["macro-muck", "beginner-friendly"]),
                    ("Dauin South", "Shore", "Beginner", ["muck", "macro"], ["macro-muck", "beginner-friendly"]),
                    ("Cars", "Shore", "Beginner", ["muck", "artificial reef", "macro"], ["macro-muck", "beginner-friendly"]),
                    ("Ginama-an", "Shore", "Beginner", ["muck", "macro"], ["macro-muck"]),
                    ("San Miguel", "Shore", "Beginner", ["muck", "hairy frogfish"], ["macro-muck"]),
                    ("Masaplod Norte", "Shore", "Intermediate", ["muck", "rare species"], ["macro-muck"]),
                    ("Sahara", "Shore", "Beginner", ["sandy", "macro", "critters"], ["macro-muck"]),
                    ("Mainit Dauin", "Shore", "Intermediate", ["hot spring", "unique", "muck"], ["macro-muck"]),
                    ("Atlantis House Reef", "Reef", "Beginner", ["house reef", "turtles", "macro"], ["beginner-friendly"]),
                ],
            },
        ],
    },

    # =========================================================================
    # 3. MALAYSIA, BRUNEI & BORNEO
    # =========================================================================
    {
        "id": "malaysia-borneo",
        "name": "Malaysia, Brunei & Borneo",
        "tagline": "Sipadan — one of the world's finest",
        "description": "",
        "sort_order": 3,
        "regions": [
            {
                "id": "sipadan-mabul-kapalai",
                "name": "Sipadan, Mabul & Kapalai",
                "country_id": "MY", "country": "Malaysia",
                "latitude": 4.115, "longitude": 118.629,
                "bounds": {"min_lat": 3.8, "max_lat": 4.4, "min_lon": 118.3, "max_lon": 119.0},
                "tagline": "Barracuda Point is consistently ranked the world's best dive site",
                "best_season": "April–December",
                "defaults": {
                    "averageDepth": 18.0, "maxDepth": 35.0, "averageTemp": 28.0,
                    "averageVisibility": 25.0, "difficulty": "Intermediate",
                    "curation_score": 9.6, "popularity_score": 9.5, "access_level": "boat",
                },
                "_sites": [
                    ("Barracuda Point", "Drift", "Intermediate", ["barracuda tornado", "current", "turtles"], ["big-animals"]),
                    ("South Point", "Drift", "Advanced", ["hammerheads", "current", "pelagic"], ["big-animals", "advanced-challenges"]),
                    ("Turtle Cavern", "Cave", "Advanced", ["cave", "turtles", "halocline"], ["caves-cenotes", "big-animals"]),
                    ("Turtle Patch", "Reef", "Beginner", ["turtles", "reef fish"], ["beginner-friendly", "big-animals"]),
                    ("Hanging Gardens", "Wall", "Intermediate", ["wall", "soft coral"], []),
                    ("White Tip Avenue", "Reef", "Intermediate", ["whitetip sharks", "turtles"], ["big-animals"]),
                    ("Coral Garden Sipadan", "Reef", "Beginner", ["coral garden", "turtles"], ["beginner-friendly"]),
                    ("Drop Off Sipadan", "Wall", "Intermediate", ["wall", "schooling fish"], []),
                    ("Mid Reef", "Reef", "Beginner", ["reef fish", "coral"], ["beginner-friendly"]),
                    ("Staghorn Crest", "Reef", "Beginner", ["staghorn coral", "reef fish"], ["beginner-friendly"]),
                    ("Lobster Wall", "Wall", "Intermediate", ["wall", "lobster", "macro"], []),
                    ("West Ridge", "Reef", "Intermediate", ["reef", "sharks", "turtles"], ["big-animals"]),
                    ("Mandarin Valley Mabul", "Shore", "Beginner", ["mandarin fish", "macro", "night diving"], ["macro-muck"]),
                    ("Eel Garden Mabul", "Shore", "Beginner", ["garden eels", "macro"], ["beginner-friendly"]),
                    ("Ray Point Mabul", "Shore", "Beginner", ["stingrays", "macro"], ["beginner-friendly"]),
                    ("Artificial Reef Mabul", "Reef", "Beginner", ["artificial reef", "macro", "seahorse"], ["beginner-friendly", "macro-muck"]),
                ],
            },
            {
                "id": "tioman-east-coast-malaysia",
                "name": "Tioman & East Coast Malaysia",
                "country_id": "MY", "country": "Malaysia",
                "latitude": 2.83, "longitude": 104.15,
                "bounds": {"min_lat": 2.5, "max_lat": 4.5, "min_lon": 103.5, "max_lon": 104.8},
                "tagline": "Warm clear water and abundant reef fish",
                "best_season": "March–October",
                "defaults": {
                    "averageDepth": 15.0, "maxDepth": 28.0, "averageTemp": 28.0,
                    "averageVisibility": 18.0, "difficulty": "Intermediate",
                    "curation_score": 8.6, "popularity_score": 8.4, "access_level": "boat",
                },
                "_sites": [
                    ("Tiger Reef", "Reef", "Intermediate", ["reef", "fish diversity"], []),
                    ("Chebeh Island", "Reef", "Intermediate", ["reef", "schooling fish"], []),
                    ("Labas Island", "Reef", "Beginner", ["coral", "fish"], ["beginner-friendly"]),
                    ("Soyak Island", "Reef", "Beginner", ["coral garden", "reef fish"], ["beginner-friendly"]),
                    ("Renggis Island", "Reef", "Beginner", ["coral", "turtles"], ["beginner-friendly"]),
                    ("Fan Canyon", "Wall", "Intermediate", ["seafans", "wall"], []),
                    ("Malang Rock", "Reef", "Intermediate", ["reef", "fish"], []),
                    ("Pirate Reef", "Reef", "Intermediate", ["reef", "barracuda"], []),
                    ("Pulau Aur", "Reef", "Intermediate", ["remote", "reef", "hammerheads seasonal"], ["big-animals"]),
                    ("Pulau Dayang", "Reef", "Intermediate", ["reef", "fish diversity"], []),
                    ("Pulau Tenggol", "Reef", "Intermediate", ["remote", "whale sharks seasonal"], ["big-animals"]),
                ],
            },
            {
                "id": "brunei-reefs-wrecks",
                "name": "Brunei — Wrecks & Reefs",
                "country_id": "BN", "country": "Brunei",
                "latitude": 5.0, "longitude": 115.1,
                "bounds": {"min_lat": 4.5, "max_lat": 5.5, "min_lon": 114.5, "max_lon": 115.7},
                "tagline": "Distinctive WWII wrecks in rich Borneo waters",
                "best_season": "March–September",
                "defaults": {
                    "averageDepth": 18.0, "maxDepth": 30.0, "averageTemp": 28.0,
                    "averageVisibility": 15.0, "difficulty": "Intermediate",
                    "curation_score": 8.4, "popularity_score": 8.0, "access_level": "boat",
                },
                "_sites": [
                    ("Australian Wreck", "Wreck", "Intermediate", ["WWII", "wreck", "coral growth"], ["wreck-capitals"]),
                    ("American Wreck", "Wreck", "Intermediate", ["WWII", "wreck"], ["wreck-capitals"]),
                    ("Blue Water Wreck", "Wreck", "Intermediate", ["wreck", "fish"], ["wreck-capitals"]),
                    ("Cement Wreck", "Wreck", "Beginner", ["wreck", "shallow"], ["wreck-capitals", "beginner-friendly"]),
                    ("Bolkiah Wreck", "Wreck", "Intermediate", ["wreck"], ["wreck-capitals"]),
                    ("Pelong Rocks", "Reef", "Intermediate", ["reef", "fish diversity"], []),
                    ("Two Fathom Rock", "Reef", "Intermediate", ["reef", "barracuda"], []),
                    ("Abana Reef", "Reef", "Beginner", ["reef", "coral"], ["beginner-friendly"]),
                ],
            },
        ],
    },

    # =========================================================================
    # 4. THAILAND, MYANMAR, CAMBODIA & VIETNAM
    # =========================================================================
    {
        "id": "southeast-asia-mainland",
        "name": "Thailand, Myanmar, Cambodia & Vietnam",
        "tagline": "Richelieu Rock to the Gulf islands",
        "description": "",
        "sort_order": 4,
        "regions": [
            {
                "id": "similan-surin-islands",
                "name": "Similan & Surin Islands",
                "country_id": "TH", "country": "Thailand",
                "latitude": 8.65, "longitude": 97.64,
                "bounds": {"min_lat": 8.0, "max_lat": 9.7, "min_lon": 97.3, "max_lon": 98.4},
                "tagline": "Richelieu Rock — Thailand's finest dive site",
                "best_season": "November–April",
                "defaults": {
                    "averageDepth": 18.0, "maxDepth": 30.0, "averageTemp": 28.0,
                    "averageVisibility": 20.0, "difficulty": "Intermediate",
                    "curation_score": 9.2, "popularity_score": 9.2, "access_level": "boat",
                },
                "_sites": [
                    ("Richelieu Rock", "Reef", "Intermediate", ["whale sharks", "seahorse", "schooling fish"], ["big-animals"]),
                    ("Elephant Head Rock", "Reef", "Advanced", ["current", "pelagic", "schooling fish"], ["advanced-challenges"]),
                    ("East of Eden", "Reef", "Intermediate", ["soft coral", "fish diversity"], []),
                    ("West of Eden", "Reef", "Intermediate", ["seafans", "soft coral"], []),
                    ("Christmas Point", "Reef", "Intermediate", ["schooling fish", "reef"], []),
                    ("Boulder City", "Reef", "Intermediate", ["boulders", "reef fish"], []),
                    ("Anita's Reef", "Reef", "Beginner", ["coral", "fish"], ["beginner-friendly"]),
                    ("North Point Similan", "Wall", "Advanced", ["wall", "pelagic", "current"], ["advanced-challenges"]),
                    ("Koh Bon Ridge", "Reef", "Intermediate", ["manta rays", "current"], ["big-animals"]),
                    ("Koh Bon Pinnacle", "Reef", "Advanced", ["manta rays", "current"], ["big-animals", "advanced-challenges"]),
                    ("Koh Tachai Pinnacle", "Reef", "Advanced", ["sharks", "current", "pelagic"], ["big-animals", "advanced-challenges"]),
                    ("Koh Tachai Reef", "Reef", "Intermediate", ["reef", "fish"], []),
                    ("Surin Bay", "Reef", "Beginner", ["coral", "fish", "manta cleaning"], ["beginner-friendly"]),
                    ("Torinla Pinnacle", "Reef", "Advanced", ["current", "schooling fish"], ["advanced-challenges"]),
                ],
            },
            {
                "id": "thailand-gulf",
                "name": "Gulf of Thailand",
                "country_id": "TH", "country": "Thailand",
                "latitude": 10.0, "longitude": 100.0,
                "bounds": {"min_lat": 9.0, "max_lat": 11.5, "min_lon": 99.5, "max_lon": 100.8},
                "tagline": "Sail Rock and whale shark encounters",
                "best_season": "Year-round (best June–September)",
                "defaults": {
                    "averageDepth": 18.0, "maxDepth": 30.0, "averageTemp": 28.0,
                    "averageVisibility": 15.0, "difficulty": "Intermediate",
                    "curation_score": 8.8, "popularity_score": 9.0, "access_level": "boat",
                },
                "_sites": [
                    ("Sail Rock", "Reef", "Intermediate", ["whale sharks", "chimney", "schooling fish"], ["big-animals"]),
                    ("Chumphon Pinnacle", "Reef", "Intermediate", ["whale sharks", "schooling fish", "barracuda"], ["big-animals"]),
                    ("Southwest Pinnacle", "Reef", "Intermediate", ["schooling fish", "soft coral"], []),
                    ("White Rock", "Reef", "Beginner", ["coral", "reef fish"], ["beginner-friendly"]),
                    ("Green Rock", "Cave", "Intermediate", ["cavern", "fish"], ["caves-cenotes"]),
                    ("Twins", "Reef", "Beginner", ["coral", "fish"], ["beginner-friendly"]),
                    ("Japanese Gardens Koh Tao", "Reef", "Beginner", ["coral garden", "reef fish"], ["beginner-friendly"]),
                    ("Shark Island Koh Tao", "Reef", "Intermediate", ["bull sharks occasional", "reef"], ["big-animals"]),
                    ("HTMS Sattakut", "Wreck", "Intermediate", ["wreck", "artificial reef"], ["wreck-capitals"]),
                    ("HTMS Suphairin", "Wreck", "Intermediate", ["wreck"], ["wreck-capitals"]),
                    ("Hin Wong Pinnacle", "Reef", "Advanced", ["current", "schooling fish"], ["advanced-challenges"]),
                    ("Mango Bay", "Reef", "Beginner", ["coral", "fish"], ["beginner-friendly"]),
                    ("Aow Leuk", "Reef", "Beginner", ["coral", "fish"], ["beginner-friendly"]),
                ],
            },
            {
                "id": "phuket-phi-phi-krabi",
                "name": "Phuket, Phi Phi & Krabi",
                "country_id": "TH", "country": "Thailand",
                "latitude": 7.78, "longitude": 98.78,
                "bounds": {"min_lat": 7.2, "max_lat": 8.5, "min_lon": 98.3, "max_lon": 99.3},
                "tagline": "King Cruiser wreck and anemone reefs",
                "best_season": "November–April",
                "defaults": {
                    "averageDepth": 15.0, "maxDepth": 28.0, "averageTemp": 28.0,
                    "averageVisibility": 15.0, "difficulty": "Intermediate",
                    "curation_score": 8.8, "popularity_score": 8.9, "access_level": "boat",
                },
                "_sites": [
                    ("King Cruiser Wreck", "Wreck", "Intermediate", ["wreck", "large ship", "fish"], ["wreck-capitals"]),
                    ("Shark Point Phuket", "Reef", "Intermediate", ["leopard sharks", "anemones"], ["big-animals"]),
                    ("Anemone Reef", "Reef", "Intermediate", ["anemones", "reef fish"], []),
                    ("Koh Doc Mai", "Wall", "Intermediate", ["wall", "seahorse", "macro"], ["macro-muck"]),
                    ("Bida Nok", "Wall", "Intermediate", ["wall", "reef fish", "turtles"], []),
                    ("Bida Nai", "Wall", "Intermediate", ["wall", "black tip sharks"], ["big-animals"]),
                    ("Hin Bida", "Reef", "Intermediate", ["reef", "fish"], []),
                    ("Hin Daeng", "Wall", "Advanced", ["wall", "manta rays", "pelagic"], ["big-animals", "advanced-challenges"]),
                    ("Hin Muang", "Wall", "Advanced", ["deepest in Thailand", "manta rays", "pelagic"], ["big-animals", "advanced-challenges"]),
                    ("Racha Noi Bay", "Reef", "Intermediate", ["manta rays", "whale sharks occasional"], ["big-animals"]),
                    ("Koh Haa Lagoon", "Reef", "Beginner", ["calm", "reef fish", "coral"], ["beginner-friendly"]),
                    ("Koh Haa Cathedral", "Cave", "Intermediate", ["cavern", "atmospheric"], ["caves-cenotes"]),
                ],
            },
            {
                "id": "myanmar-mergui",
                "name": "Myanmar — Mergui Archipelago",
                "country_id": "MM", "country": "Myanmar",
                "latitude": 10.5, "longitude": 98.0,
                "bounds": {"min_lat": 9.5, "max_lat": 13.5, "min_lon": 97.5, "max_lon": 99.0},
                "tagline": "Remote liveaboard wilderness",
                "best_season": "November–April",
                "defaults": {
                    "averageDepth": 18.0, "maxDepth": 30.0, "averageTemp": 27.0,
                    "averageVisibility": 20.0, "difficulty": "Advanced",
                    "curation_score": 9.1, "popularity_score": 8.6, "access_level": "boat",
                    "required_cert": "Advanced",
                },
                "_sites": [
                    ("Black Rock Myanmar", "Reef", "Advanced", ["whale sharks", "manta rays", "sharks"], ["big-animals", "liveaboard"]),
                    ("Western Rocky", "Reef", "Advanced", ["current", "sharks", "pelagic"], ["big-animals", "liveaboard"]),
                    ("North Twin", "Wall", "Advanced", ["wall", "current", "manta rays"], ["big-animals", "liveaboard"]),
                    ("South Twin", "Wall", "Advanced", ["wall", "current"], ["liveaboard"]),
                    ("Tower Rock", "Reef", "Advanced", ["current", "schooling fish"], ["liveaboard"]),
                    ("Fan Forest Pinnacle", "Reef", "Intermediate", ["seafans", "soft coral"], ["liveaboard"]),
                    ("Burma Banks", "Reef", "Advanced", ["nurse sharks", "grey reef sharks"], ["big-animals", "liveaboard"]),
                    ("Silvertip Bank", "Reef", "Advanced", ["silvertip sharks", "pelagic"], ["big-animals", "liveaboard"]),
                    ("Rainbow Reef Myanmar", "Reef", "Intermediate", ["soft coral", "fish"], ["liveaboard"]),
                ],
            },
            {
                "id": "cambodia-koh-rong",
                "name": "Cambodia — Koh Rong",
                "country_id": "KH", "country": "Cambodia",
                "latitude": 10.7, "longitude": 103.3,
                "bounds": {"min_lat": 10.2, "max_lat": 11.2, "min_lon": 102.8, "max_lon": 103.8},
                "tagline": "Undiscovered reefs and laid-back island diving",
                "best_season": "November–May",
                "defaults": {
                    "averageDepth": 14.0, "maxDepth": 25.0, "averageTemp": 28.0,
                    "averageVisibility": 10.0, "difficulty": "Beginner",
                    "curation_score": 8.0, "popularity_score": 7.8, "access_level": "boat",
                },
                "_sites": [
                    ("Koh Tang", "Reef", "Intermediate", ["remote", "reef", "fish"], []),
                    ("Condor Reef", "Reef", "Intermediate", ["reef", "fish diversity"], []),
                    ("Koh Prins", "Reef", "Beginner", ["coral", "fish"], ["beginner-friendly"]),
                    ("Koh Rong Samloem", "Reef", "Beginner", ["coral", "reef fish"], ["beginner-friendly"]),
                    ("Back Door", "Reef", "Beginner", ["macro", "reef"], ["beginner-friendly"]),
                    ("Nudibranch Heaven Cambodia", "Shore", "Beginner", ["nudibranch", "macro"], ["macro-muck", "beginner-friendly"]),
                ],
            },
            {
                "id": "vietnam-nha-trang-phu-quoc",
                "name": "Vietnam — Nha Trang & Phu Quoc",
                "country_id": "VN", "country": "Vietnam",
                "latitude": 12.24, "longitude": 109.19,
                "bounds": {"min_lat": 9.5, "max_lat": 13.5, "min_lon": 103.5, "max_lon": 110.5},
                "tagline": "Tropical reefs and coral gardens",
                "best_season": "February–September",
                "defaults": {
                    "averageDepth": 14.0, "maxDepth": 25.0, "averageTemp": 27.0,
                    "averageVisibility": 12.0, "difficulty": "Beginner",
                    "curation_score": 8.0, "popularity_score": 7.8, "access_level": "boat",
                },
                "_sites": [
                    ("Madonna Rock", "Reef", "Intermediate", ["reef", "fish diversity"], []),
                    ("Moray Beach", "Reef", "Beginner", ["moray eels", "coral"], ["beginner-friendly"]),
                    ("Hon Mun", "Reef", "Beginner", ["marine protected area", "coral"], ["beginner-friendly"]),
                    ("Whale Island Vietnam", "Reef", "Beginner", ["whale sharks seasonal", "reef"], ["big-animals"]),
                    ("Cham Island Hon Tai", "Reef", "Beginner", ["coral", "fish"], ["beginner-friendly"]),
                    ("Phu Quoc Turtle Island", "Reef", "Beginner", ["turtles", "coral"], ["beginner-friendly", "big-animals"]),
                    ("Nudibranch Gardens Vietnam", "Shore", "Beginner", ["nudibranch", "macro"], ["macro-muck"]),
                ],
            },
        ],
    },

    # =========================================================================
    # 5. MICRONESIA
    # =========================================================================
    {
        "id": "micronesia",
        "name": "Micronesia",
        "tagline": "Blue Corner, Truk Lagoon and Yap mantas",
        "description": "",
        "sort_order": 5,
        "regions": [
            {
                "id": "palau",
                "name": "Palau",
                "country_id": "PW", "country": "Palau",
                "latitude": 7.51, "longitude": 134.58,
                "bounds": {"min_lat": 6.9, "max_lat": 8.2, "min_lon": 134.0, "max_lon": 135.2},
                "tagline": "Blue Corner — among the world's greatest dives",
                "best_season": "October–May",
                "defaults": {
                    "averageDepth": 20.0, "maxDepth": 35.0, "averageTemp": 28.0,
                    "averageVisibility": 25.0, "difficulty": "Intermediate",
                    "curation_score": 9.5, "popularity_score": 9.4, "access_level": "boat",
                },
                "_sites": [
                    ("Blue Corner", "Drift", "Advanced", ["strong current", "reef sharks", "turtles", "schooling fish"], ["big-animals", "advanced-challenges"]),
                    ("Blue Holes Palau", "Cave", "Intermediate", ["blue holes", "descending shafts", "soft coral"], ["caves-cenotes"]),
                    ("German Channel", "Drift", "Intermediate", ["manta rays", "cleaning station", "sharks"], ["big-animals"]),
                    ("Ulong Channel", "Drift", "Advanced", ["current", "sharks", "schooling fish"], ["big-animals", "advanced-challenges"]),
                    ("Siaes Corner", "Drift", "Advanced", ["current", "grey reef sharks", "schooling fish"], ["big-animals", "advanced-challenges"]),
                    ("Peleliu Wall", "Wall", "Advanced", ["wall", "pelagic", "current"], ["advanced-challenges"]),
                    ("Peleliu Express", "Drift", "Advanced", ["strong current", "pelagic", "thrilling"], ["advanced-challenges"]),
                    ("Peleliu Cut", "Drift", "Advanced", ["current", "grey reef sharks"], ["big-animals", "advanced-challenges"]),
                    ("New Drop Off", "Wall", "Intermediate", ["wall", "soft coral", "fish"], []),
                    ("Big Drop Off", "Wall", "Intermediate", ["wall", "vertical drop", "fish"], []),
                    ("Chandelier Cave", "Cave", "Intermediate", ["cave", "air chambers", "stalactites"], ["caves-cenotes"]),
                    ("Jake Seaplane", "Wreck", "Intermediate", ["WWII", "seaplane", "shallow"], ["wreck-capitals"]),
                    ("Helmet Wreck", "Wreck", "Intermediate", ["WWII", "wreck", "coral growth"], ["wreck-capitals"]),
                    ("Iro Maru", "Wreck", "Intermediate", ["WWII", "tanker", "coral growth"], ["wreck-capitals"]),
                    ("Jellyfish Lake", "Other", "Beginner", ["golden jellyfish", "unique", "snorkel"], ["beginner-friendly"]),
                    ("Ngemelis Wall", "Wall", "Intermediate", ["wall", "fish diversity"], []),
                    ("Short Drop Off", "Wall", "Beginner", ["wall", "coral", "turtles"], ["beginner-friendly"]),
                    ("Ngerchong Inside", "Reef", "Intermediate", ["reef", "fish"], []),
                    ("Wonder Channel", "Drift", "Intermediate", ["channel", "schooling fish"], []),
                ],
            },
            {
                "id": "chuuk-truk-lagoon",
                "name": "Chuuk / Truk Lagoon",
                "country_id": "FM", "country": "Micronesia",
                "latitude": 7.45, "longitude": 151.85,
                "bounds": {"min_lat": 7.0, "max_lat": 8.0, "min_lon": 151.3, "max_lon": 152.4},
                "tagline": "The wreck capital of the world",
                "best_season": "Year-round",
                "defaults": {
                    "averageDepth": 25.0, "maxDepth": 50.0, "averageTemp": 28.0,
                    "averageVisibility": 20.0, "difficulty": "Intermediate",
                    "curation_score": 9.4, "popularity_score": 9.0, "access_level": "boat",
                },
                "_sites": [
                    ("Fujikawa Maru", "Wreck", "Intermediate", ["WWII", "aircraft carrier support", "coral growth"], ["wreck-capitals"]),
                    ("Shinkoku Maru", "Wreck", "Intermediate", ["WWII", "oil tanker", "coral growth"], ["wreck-capitals"]),
                    ("San Francisco Maru", "Wreck", "Advanced", ["WWII", "deep", "tanks on deck"], ["wreck-capitals", "advanced-challenges"]),
                    ("Nippo Maru", "Wreck", "Intermediate", ["WWII", "tanks", "guns on deck"], ["wreck-capitals"]),
                    ("Heian Maru", "Wreck", "Intermediate", ["WWII", "passenger submarine tender"], ["wreck-capitals"]),
                    ("Hoki Maru", "Wreck", "Intermediate", ["WWII", "cargo ship", "trucks"], ["wreck-capitals"]),
                    ("Yamagiri Maru", "Wreck", "Intermediate", ["WWII", "artillery shells in hold"], ["wreck-capitals"]),
                    ("Kensho Maru", "Wreck", "Intermediate", ["WWII", "large hold"], ["wreck-capitals"]),
                    ("Rio de Janeiro Maru", "Wreck", "Intermediate", ["WWII", "passenger ship"], ["wreck-capitals"]),
                    ("Betty Bomber", "Wreck", "Intermediate", ["WWII", "aircraft", "shallow"], ["wreck-capitals"]),
                    ("Sankisan Maru", "Wreck", "Intermediate", ["WWII", "cargo", "ammunition"], ["wreck-capitals"]),
                    ("Gosei Maru", "Wreck", "Intermediate", ["WWII", "cargo ship"], ["wreck-capitals"]),
                    ("Momokawa Maru", "Wreck", "Advanced", ["WWII", "cargo ship", "deep"], ["wreck-capitals", "advanced-challenges"]),
                    ("Aikoku Maru", "Wreck", "Advanced", ["WWII", "deep", "large"], ["wreck-capitals", "advanced-challenges"]),
                    ("Hanakawa Maru", "Wreck", "Intermediate", ["WWII", "cargo ship"], ["wreck-capitals"]),
                ],
            },
            {
                "id": "yap",
                "name": "Yap",
                "country_id": "FM", "country": "Micronesia",
                "latitude": 9.56, "longitude": 138.13,
                "bounds": {"min_lat": 9.2, "max_lat": 9.9, "min_lon": 137.8, "max_lon": 138.5},
                "tagline": "Manta rays and traditional culture",
                "best_season": "December–April (mantas), June–August (whale sharks)",
                "defaults": {
                    "averageDepth": 16.0, "maxDepth": 28.0, "averageTemp": 27.0,
                    "averageVisibility": 20.0, "difficulty": "Intermediate",
                    "curation_score": 9.2, "popularity_score": 8.8, "access_level": "boat",
                },
                "_sites": [
                    ("Mi'il Channel", "Drift", "Intermediate", ["manta rays", "cleaning station"], ["big-animals"]),
                    ("Goofnuw Channel", "Drift", "Intermediate", ["manta rays", "current"], ["big-animals"]),
                    ("Vertigo", "Wall", "Advanced", ["wall", "deep", "pelagic"], ["advanced-challenges"]),
                    ("Yap Caverns", "Cave", "Intermediate", ["cave", "coral", "fish"], ["caves-cenotes"]),
                    ("Lionfish Wall", "Wall", "Intermediate", ["lionfish", "wall", "soft coral"], []),
                    ("Magic Kingdom", "Reef", "Intermediate", ["manta rays", "reef fish"], ["big-animals"]),
                    ("Slow and Easy", "Drift", "Beginner", ["manta rays", "current"], ["big-animals", "beginner-friendly"]),
                    ("Stammtisch", "Reef", "Intermediate", ["manta rays", "reef"], ["big-animals"]),
                    ("Manta Ridge", "Reef", "Intermediate", ["manta rays", "schooling fish"], ["big-animals"]),
                    ("Cabbage Patch Yap", "Reef", "Beginner", ["soft coral", "fish"], ["beginner-friendly"]),
                ],
            },
            {
                "id": "guam-northern-marianas",
                "name": "Guam & Northern Mariana Islands",
                "country_id": "GU", "country": "Guam",
                "latitude": 13.44, "longitude": 144.79,
                "bounds": {"min_lat": 13.0, "max_lat": 15.2, "min_lon": 144.5, "max_lon": 145.8},
                "tagline": "Pacific WWII wrecks and blue holes",
                "best_season": "Year-round",
                "defaults": {
                    "averageDepth": 18.0, "maxDepth": 35.0, "averageTemp": 28.0,
                    "averageVisibility": 20.0, "difficulty": "Intermediate",
                    "curation_score": 8.7, "popularity_score": 8.4, "access_level": "boat",
                },
                "_sites": [
                    ("Blue Hole Guam", "Cave", "Advanced", ["blue hole", "deep", "cavern"], ["caves-cenotes", "advanced-challenges"]),
                    ("Gab Gab II", "Reef", "Beginner", ["coral", "fish", "turtles"], ["beginner-friendly"]),
                    ("Tokai Maru", "Wreck", "Intermediate", ["WWII", "freighter", "coral growth"], ["wreck-capitals"]),
                    ("SMS Cormoran", "Wreck", "Intermediate", ["WWI", "German warship"], ["wreck-capitals"]),
                    ("American Tanker Guam", "Wreck", "Intermediate", ["WWII", "tanker"], ["wreck-capitals"]),
                    ("Piti Bomb Holes", "Other", "Beginner", ["bomb craters", "reef", "fish"], ["beginner-friendly"]),
                    ("Gun Beach", "Reef", "Beginner", ["coral", "fish", "WWII artifacts"], ["beginner-friendly"]),
                    ("Grotto Saipan", "Cave", "Advanced", ["cave", "blue water", "unique entry"], ["caves-cenotes", "advanced-challenges"]),
                    ("Lau Lau Beach", "Shore", "Beginner", ["shore entry", "coral", "fish"], ["beginner-friendly"]),
                    ("Eagle Ray City", "Reef", "Intermediate", ["eagle rays", "reef fish"], ["big-animals"]),
                ],
            },
            {
                "id": "marshall-islands",
                "name": "Marshall Islands",
                "country_id": "MH", "country": "Marshall Islands",
                "latitude": 7.11, "longitude": 171.18,
                "bounds": {"min_lat": 5.0, "max_lat": 14.0, "min_lon": 166.0, "max_lon": 172.0},
                "tagline": "Bikini Atoll — nuclear test site turned dive destination",
                "best_season": "October–May",
                "defaults": {
                    "averageDepth": 25.0, "maxDepth": 50.0, "averageTemp": 28.0,
                    "averageVisibility": 30.0, "difficulty": "Advanced",
                    "curation_score": 9.1, "popularity_score": 8.4, "access_level": "boat",
                    "required_cert": "Advanced",
                },
                "_sites": [
                    ("USS Saratoga Bikini", "Wreck", "Advanced", ["WWII", "aircraft carrier", "atomic test"], ["wreck-capitals", "liveaboard"]),
                    ("Nagato Bikini", "Wreck", "Advanced", ["WWII", "battleship", "atomic test"], ["wreck-capitals", "liveaboard"]),
                    ("Prinz Eugen", "Wreck", "Advanced", ["WWII", "German cruiser"], ["wreck-capitals", "liveaboard"]),
                    ("Majuro Bridge", "Reef", "Intermediate", ["reef", "fish diversity", "current"], []),
                    ("Eneko Island", "Reef", "Beginner", ["coral garden", "fish"], ["beginner-friendly"]),
                    ("Rongelap Atoll", "Reef", "Advanced", ["remote", "pristine", "sharks"], ["big-animals", "liveaboard"]),
                ],
            },
        ],
    },
]  # end of first 5 groups — continued in REGION_GROUPS_B


def main() -> None:
    from generate_canonical_list_b import REGION_GROUPS_B
    from generate_canonical_list_c import SUPPLEMENTAL_REGIONS
    from generate_canonical_list_d import EXTRA_SITES, EXTRA_REGIONS
    from generate_canonical_list_e import EXTRA_SITES_E, EXTRA_SITES_E2, EXTRA_SITES_E3, EXTRA_SITES_E4
    all_groups = REGION_GROUPS + REGION_GROUPS_B

    # Index groups and regions for supplemental merges
    group_index = {g["id"]: g for g in all_groups}
    for gid, extra_regions in SUPPLEMENTAL_REGIONS.items():
        if gid in group_index:
            group_index[gid].setdefault("regions", []).extend(extra_regions)
    for gid, extra_regions in EXTRA_REGIONS.items():
        if gid in group_index:
            group_index[gid].setdefault("regions", []).extend(extra_regions)

    # Build region index for extra sites
    region_index: dict[str, dict] = {}
    for g in all_groups:
        for r in g.get("regions", []):
            region_index[r["id"]] = r
    for rid, extra in EXTRA_SITES.items():
        if rid in region_index:
            region_index[rid].setdefault("_sites", []).extend(extra)
    for rid, extra in EXTRA_SITES_E.items():
        if rid in region_index:
            region_index[rid].setdefault("_sites", []).extend(extra)
    for rid, extra in EXTRA_SITES_E2.items():
        if rid in region_index:
            region_index[rid].setdefault("_sites", []).extend(extra)
    for rid, extra in EXTRA_SITES_E3.items():
        if rid in region_index:
            region_index[rid].setdefault("_sites", []).extend(extra)
    for rid, extra in EXTRA_SITES_E4.items():
        if rid in region_index:
            region_index[rid].setdefault("_sites", []).extend(extra)

    output_groups = []
    total_sites = 0
    for group in all_groups:
        g = {k: v for k, v in group.items() if k != "regions"}
        g["regions"] = []
        for region in group.get("regions", []):
            r = {k: v for k, v in region.items() if k != "_sites"}
            r["sites"] = expand_sites(region, region.get("_sites", []))
            total_sites += len(r["sites"])
            g["regions"].append(r)
        output_groups.append(g)

    output = {
        "version": "2026-05-01-canonical-v1",
        "region_groups": output_groups,
    }

    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_PATH.write_text(json.dumps(output, indent=2, ensure_ascii=False) + "\n")
    print(f"Wrote {OUTPUT_PATH.relative_to(ROOT)}")
    print(f"  {len(all_groups)} region groups")
    print(f"  {sum(len(g['regions']) for g in output_groups)} regions")
    print(f"  {total_sites} sites")


if __name__ == "__main__":
    main()
